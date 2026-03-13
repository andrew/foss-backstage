require_relative "shared"
require "purl"
require "sqlite3"

PACKAGES_API = "https://packages.ecosyste.ms/api/v1/"

# ecosyste.ms ecosystem names -> purl types (where they differ)
PURL_TYPES = {
  "actions" => "githubactions",
  "rubygems" => "gem",
  "go" => "golang",
  "packagist" => "composer",
  "homebrew" => "brew",
  "swiftpm" => "swift",
}

namespace :packages do
  desc "Fetch package info for org repo dependencies from packages.ecosyste.ms (LIMIT=n to restrict)"
  task :fetch do
    output_dir = "data/packages"
    FileUtils.mkdir_p(output_dir)

    db = SQLite3::Database.new(DB_PATH)
    raw = db.execute("SELECT DISTINCT ecosystem, package_name FROM dependencies ORDER BY ecosystem, package_name")
    db.close

    # Strip versions using purl parsing to deduplicate (e.g. csstype@3.1.0 -> csstype)
    packages = raw.filter_map { |(eco, name)|
      next if name.nil? || name.strip.empty?
      clean = name.sub(/\(.*\)$/, "")  # remove parenthesized peer deps
      clean = clean.split("=>").first.strip  # remove go replace targets
      next if clean.empty?
      next if clean.include?("${")  # skip unresolved template variables

      purl_type = PURL_TYPES[eco] || eco

      # Split namespace and name
      if purl_type == "maven" && clean.include?(":")
        ns, pkg_name = clean.split(":", 2)
      elsif clean.include?("/")
        ns, _, pkg_name = clean.rpartition("/")
      else
        ns = nil
        pkg_name = clean
      end

      # Strip version suffix
      pkg_name, _ = pkg_name.split("@", 2) if pkg_name.include?("@")
      next if pkg_name.nil? || pkg_name.strip.empty?

      begin
        p = Purl::PackageURL.new(type: purl_type, namespace: ns, name: pkg_name)
      rescue Purl::ValidationError, Purl::InvalidNameError, Purl::MalformedUrlError
        next
      end
      clean = p.namespace ? "#{p.namespace}/#{p.name}" : p.name
      [eco, clean]
    }.uniq

    # Skip relative paths and dot-prefixed names
    packages = packages.reject { |(_, name)| name.start_with?(".") }

    packages = packages.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "Fetching info for #{packages.size} packages..."

    packages.each_with_index do |(ecosystem, name), i|
      safe_name = name.gsub("/", "__")
      output_file = File.join(output_dir, ecosystem, "#{safe_name}.json")

      if File.exist?(output_file)
        next
      end

      purl_type = PURL_TYPES[ecosystem] || ecosystem
      purl = "pkg:#{purl_type}/#{name}"

      print "  [#{i + 1}/#{packages.size}] #{purl}..."

      data = api_get(PACKAGES_API, "packages/lookup?purl=#{URI.encode_uri_component(purl)}")

      FileUtils.mkdir_p(File.dirname(output_file))

      if data.is_a?(Array) && data.any?
        File.write(output_file, JSON.generate(data))
        top = data.max_by { |p| p["downloads"].to_i }
        puts " #{top["downloads"]} downloads, #{top["dependent_packages_count"]} dependents, #{top["repository_url"]}"
      else
        File.write(output_file, JSON.generate([]))
        puts " not found"
      end
    end
  end

  desc "Fetch published packages for org repos from packages.ecosyste.ms (LIMIT=n to restrict orgs)"
  task :published do
    output_dir = "data/published_packages"
    FileUtils.mkdir_p(output_dir)

    db = SQLite3::Database.new(DB_PATH)
    repos = db.execute("SELECT full_name FROM repos WHERE fork = 0 AND archived = 0 ORDER BY full_name")
    db.close

    repos = repos.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "Checking published packages for #{repos.size} repos..."

    repos.each_with_index do |(full_name), i|
      safe_name = full_name.gsub("/", "__")
      output_file = File.join(output_dir, "#{safe_name}.json")

      next if File.exist?(output_file)

      print "  [#{i + 1}/#{repos.size}] #{full_name}..."

      url = "https://github.com/#{full_name}"
      data = api_get(PACKAGES_API, "packages/lookup?repository_url=#{URI.encode_uri_component(url)}")

      if data.is_a?(Array) && data.any?
        File.write(output_file, JSON.generate(data))
        puts " #{data.size} packages"
      else
        File.write(output_file, JSON.generate([]))
        puts " none"
      end
    end
  end

  desc "Summarize published packages"
  task :published_summary do
    dir = "data/published_packages"
    repos_with_packages = 0
    repos_without = 0
    total_packages = 0
    total_downloads = 0
    by_ecosystem = Hash.new(0)

    Dir.glob(File.join(dir, "*.json")).each do |file|
      packages = JSON.parse(File.read(file))
      if packages.empty?
        repos_without += 1
      else
        repos_with_packages += 1
        total_packages += packages.size
        packages.each do |p|
          by_ecosystem[p["ecosystem"]] += 1
          total_downloads += p["downloads"].to_i
        end
      end
    end

    total = repos_with_packages + repos_without
    puts "#{total} repos checked"
    puts "#{repos_with_packages} repos publish packages (#{(repos_with_packages.to_f / total * 100).round(1)}%)"
    puts "#{total_packages} total packages published"
    puts "#{total_downloads} total downloads"
    puts
    puts "By ecosystem:"
    by_ecosystem.sort_by { |_, c| -c }.each do |eco, count|
      puts "  #{eco}: #{count}"
    end
  end

  desc "Summarize package data"
  task :summary do
    dir = "data/packages"
    total = 0
    with_data = 0
    total_downloads = 0
    total_dependents = 0
    with_repo = 0

    Dir.glob(File.join(dir, "**/*.json")).each do |file|
      packages = JSON.parse(File.read(file))
      total += 1
      next if packages.empty?
      with_data += 1

      top = packages.max_by { |p| p["downloads"].to_i }
      total_downloads += top["downloads"].to_i
      total_dependents += top["dependent_packages_count"].to_i
      with_repo += 1 if top["repository_url"]&.include?("github.com")
    end

    puts "#{total} packages checked, #{with_data} found"
    puts "#{total_downloads} total downloads, #{total_dependents} total dependents"
    puts "#{with_repo} with GitHub repo URL"
  end
end
