require_relative "shared"
require "set"


namespace :external_repos do
  desc "Fetch repo info for external repos from repos.ecosyste.ms (LIMIT=n to restrict)"
  task :fetch do
    output_dir = "data/external_repos"
    FileUtils.mkdir_p(output_dir)

    repos = Set.new
    Dir.glob("data/activity/*.json").each do |file|
      data = JSON.parse(File.read(file))
      (data.dig("commits", "repositories") || []).each { |r| repos << r["full_name"] }
      (data.dig("issues", "issue_repos") || []).each { |r| repos << r["repository"] }
      (data.dig("issues", "pull_request_repos") || []).each { |r| repos << r["repository"] }
    end

    repos = repos.to_a.sort
    repos = repos.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "Fetching info for #{repos.size} repos..."

    repos.each_with_index do |full_name, i|
      output_file = File.join(output_dir, "#{full_name}.json")

      if File.exist?(output_file)
        next
      end

      print "  [#{i + 1}/#{repos.size}] #{full_name}..."

      data = api_get(REPOS_API, "hosts/GitHub/repositories/#{full_name}")

      FileUtils.mkdir_p(File.dirname(output_file))

      if data
        File.write(output_file, JSON.generate(data))
        puts " #{data["stargazers_count"]} stars"
      else
        File.write(output_file, JSON.generate({ full_name: full_name, error: true }))
        puts " not found"
      end
    end
  end

  desc "Summarize external repos"
  task :summary do
    dir = "data/external_repos"
    total = 0
    errors = 0
    total_stars = 0
    languages = Hash.new(0)

    Dir.glob(File.join(dir, "**/*.json")).each do |file|
      data = JSON.parse(File.read(file))
      total += 1
      if data["error"]
        errors += 1
        next
      end
      total_stars += data["stargazers_count"].to_i
      lang = data["language"]
      languages[lang] += 1 if lang
    end

    puts "#{total} repos fetched (#{errors} not found)"
    puts "#{total_stars} total stars"
    puts
    puts "Top 20 languages:"
    languages.sort_by { |_, v| -v }.first(20).each do |lang, count|
      puts "  #{lang}: #{count}"
    end
  end
end
