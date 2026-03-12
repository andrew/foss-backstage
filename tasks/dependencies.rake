require_relative "shared"

namespace :dependencies do
  desc "Fetch dependency manifests for org repos from repos.ecosyste.ms (LIMIT=n to restrict orgs)"
  task :fetch do
    input_dir = "data/repos"
    output_dir = "data/dependencies"
    FileUtils.mkdir_p(output_dir)

    files = Dir.glob(File.join(input_dir, "*.json")).sort
    files = files.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    files.each do |file|
      org = File.basename(file, ".json")
      repos = JSON.parse(File.read(file))
      active_repos = repos.reject { |r| r["fork"] || r["archived"] }

      puts "Fetching dependencies for #{org} (#{active_repos.size} active repos)..."

      active_repos.each do |repo|
        full_name = repo["full_name"]
        output_file = File.join(output_dir, "#{full_name}.json")

        if File.exist?(output_file)
          next
        end

        print "  #{full_name}..."

        data = api_get(REPOS_API, "hosts/GitHub/repositories/#{full_name}/manifests")

        FileUtils.mkdir_p(File.dirname(output_file))

        if data.is_a?(Array)
          File.write(output_file, JSON.generate(data))
          dep_count = data.sum { |m| (m["dependencies"] || []).size }
          puts " #{data.size} manifests, #{dep_count} dependencies"
        else
          File.write(output_file, JSON.generate([]))
          puts " no manifests"
        end
      end
    end
  end

  desc "Summarize dependency data"
  task :summary do
    dir = "data/dependencies"
    total_repos = 0
    repos_with_deps = 0
    total_deps = 0
    packages = Hash.new(0)

    Dir.glob(File.join(dir, "**/*.json")).each do |file|
      manifests = JSON.parse(File.read(file))
      total_repos += 1
      next if manifests.empty?
      repos_with_deps += 1

      manifests.each do |m|
        (m["dependencies"] || []).each do |dep|
          key = "#{dep["ecosystem"]}:#{dep["package_name"]}"
          packages[key] += 1
          total_deps += 1
        end
      end
    end

    puts "#{total_repos} repos checked, #{repos_with_deps} with dependencies, #{total_deps} total dependencies"
    puts "#{packages.size} unique packages"
    puts
    puts "Top 30 shared dependencies:"
    packages.sort_by { |_, v| -v }.first(30).each do |pkg, count|
      puts "  #{count} #{pkg}"
    end
  end
end
