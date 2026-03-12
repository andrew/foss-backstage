require_relative "shared"
require "sqlite3"

SPONSORS_API = "https://sponsors.ecosyste.ms/api/v1/"
OPENCOLLECTIVE_API = "https://opencollective.ecosyste.ms/api/v1/"

namespace :funding do
  desc "Fetch funding info for shared dependency repos (LIMIT=n to restrict)"
  task :fetch do
    output_dir = "data/funding"
    FileUtils.mkdir_p(output_dir)

    db = SQLite3::Database.new(DB_PATH)

    # Get unique repo URLs from packages used by 5+ orgs
    repos = db.execute(<<-SQL)
      SELECT DISTINCT p.repository_url
      FROM packages p
      JOIN dependencies d ON d.ecosystem = p.ecosystem AND d.package_name = p.package_name
      JOIN repos r ON r.full_name = d.repo
      WHERE p.repository_url IS NOT NULL AND p.repository_url <> ''
      GROUP BY p.repository_url
      HAVING COUNT(DISTINCT r.org) >= 5
      ORDER BY COUNT(DISTINCT r.org) DESC
    SQL
    db.close

    repos = repos.map(&:first)
    repos = repos.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "Checking funding for #{repos.size} dependency repos..."

    repos.each_with_index do |repo_url, i|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      safe_name = repo_name.gsub("/", "__")
      output_file = File.join(output_dir, "#{safe_name}.json")

      next if File.exist?(output_file)

      owner = repo_name.split("/").first
      print "  [#{i + 1}/#{repos.size}] #{repo_name}..."

      result = { "repo" => repo_name, "owner" => owner }

      # GitHub Sponsors for the repo owner
      sponsors_data = api_get(SPONSORS_API, "accounts/#{owner}")
      if sponsors_data
        result["sponsors"] = {
          "has_listing" => sponsors_data["has_sponsors_listing"],
          "active_sponsors" => sponsors_data["active_sponsors_count"],
          "active_sponsorships" => sponsors_data["active_sponsorships_count"],
        }
      end

      # OpenCollective lookup by repo URL
      oc_data = api_get(OPENCOLLECTIVE_API, "collectives/lookup?repository_url=#{URI.encode_uri_component(repo_url)}")
      if oc_data && oc_data["slug"]
        result["opencollective"] = {
          "slug" => oc_data["slug"],
          "name" => oc_data["name"],
          "balance" => oc_data["balance"],
          "total_donations" => oc_data["total_donations"],
          "total_expenses" => oc_data["total_expenses"],
          "current_balance" => oc_data["current_balance"],
        }
      end

      File.write(output_file, JSON.generate(result))

      parts = []
      parts << "sponsors:#{result.dig("sponsors", "active_sponsors")}" if result.dig("sponsors", "has_listing")
      parts << "OC:$#{result.dig("opencollective", "current_balance")&.round}" if result["opencollective"]
      puts parts.any? ? " #{parts.join(', ')}" : " no funding found"
    end
  end

  desc "Summarize funding data for shared dependencies"
  task :summary do
    dir = "data/funding"
    total = 0
    with_sponsors = 0
    with_oc = 0
    with_any = 0
    total_oc_balance = 0
    total_oc_donations = 0

    Dir.glob(File.join(dir, "*.json")).each do |file|
      data = JSON.parse(File.read(file))
      total += 1

      has_sponsors = data.dig("sponsors", "has_listing")
      has_oc = data["opencollective"]

      with_sponsors += 1 if has_sponsors
      with_oc += 1 if has_oc
      with_any += 1 if has_sponsors || has_oc

      if has_oc
        total_oc_balance += data.dig("opencollective", "current_balance").to_f
        total_oc_donations += data.dig("opencollective", "total_donations").to_f
      end
    end

    puts "#{total} dependency repos checked"
    puts "#{with_any} have some form of funding (#{(with_any.to_f / total * 100).round(1)}%)"
    puts "#{with_sponsors} have GitHub Sponsors listing"
    puts "#{with_oc} have OpenCollective"
    puts
    puts "OpenCollective totals:"
    puts "  $#{total_oc_donations.round} total donations received"
    puts "  $#{total_oc_balance.round} current balance"
  end
end
