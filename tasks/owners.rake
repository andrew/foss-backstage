require_relative "shared"
require "csv"
require "set"


namespace :owners do
  desc "Fetch owner info for external orgs from repos.ecosyste.ms (LIMIT=n to restrict)"
  task :fetch do
    output_dir = "data/owners"
    FileUtils.mkdir_p(output_dir)

    # Collect all known orgs from CSVs
    known_orgs = Set.new
    CSV.read("innersource_github_profiles.csv", headers: true).each do |row|
      known_orgs << row["GitHub Profile"].split("/").last.downcase
    end
    if File.exist?("org_aliases.csv")
      CSV.read("org_aliases.csv", headers: true).each do |row|
        known_orgs << row["GitHub Profile"].split("/").last.downcase
      end
    end

    # Find all external repo owners from activity data
    external_owners = Hash.new(0)
    Dir.glob("data/activity/*.json").each do |file|
      data = JSON.parse(File.read(file))
      login = data["login"].downcase

      repos = (data.dig("commits", "repositories") || []).map { |r| r["full_name"] } +
              (data.dig("issues", "issue_repos") || []).map { |r| r["repository"] } +
              (data.dig("issues", "pull_request_repos") || []).map { |r| r["repository"] }

      repos.uniq.each do |repo|
        owner = repo.split("/").first.downcase
        next if owner == login || known_orgs.include?(owner)
        external_owners[owner] += 1
      end
    end

    owners = external_owners.sort_by { |_, count| -count }.map(&:first)
    owners = owners.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "Fetching info for #{owners.size} external owners..."

    owners.each_with_index do |owner, i|
      output_file = File.join(output_dir, "#{owner}.json")

      if File.exist?(output_file)
        next
      end

      print "  [#{i + 1}/#{owners.size}] #{owner}..."

      data = api_get(REPOS_API, "hosts/GitHub/owners/#{owner}")

      if data
        data["contributor_count"] = external_owners[owner]
        File.write(output_file, JSON.generate(data))
        puts " #{data["kind"]} - #{data["name"]}"
      else
        File.write(output_file, JSON.generate({ login: owner, error: true, contributor_count: external_owners[owner] }))
        puts " not found"
      end
    end
  end

  desc "Summarize external owners"
  task :summary do
    dir = "data/owners"
    files = Dir.glob(File.join(dir, "*.json"))
    orgs = 0
    users = 0
    with_company = 0

    files.each do |file|
      data = JSON.parse(File.read(file))
      next if data["error"]
      case data["kind"]
      when "organization" then orgs += 1
      when "user" then users += 1
      end
      with_company += 1 if data["company"]&.strip&.length.to_i > 0
    end

    puts "#{files.size} owners fetched (#{orgs} orgs, #{users} users, #{with_company} with company)"
  end
end
