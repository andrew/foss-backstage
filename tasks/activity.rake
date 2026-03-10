require_relative "shared"
require "set"

namespace :activity do
  desc "Count unique logins from contributor data"
  task :logins do
    logins = Set.new
    Dir.glob("data/contributors/*.json").each do |file|
      contributors = JSON.parse(File.read(file))
      contributors.each { |c| logins << c["login"] if c["login"] && c["maintainer_activity"].to_i > 0 }
    end
    puts "#{logins.size} unique maintainer logins"
  end

  desc "Fetch external activity for contributors (LIMIT=n to restrict)"
  task :fetch do
    output_dir = "data/activity"
    FileUtils.mkdir_p(output_dir)

    logins = Set.new
    Dir.glob("data/contributors/*.json").each do |file|
      contributors = JSON.parse(File.read(file))
      contributors.each { |c| logins << c["login"] if c["login"] && c["maintainer_activity"].to_i > 0 }
    end

    logins = logins.to_a.sort
    logins = logins.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "Fetching activity for #{logins.size} contributors..."

    logins.each_with_index do |login, i|
      output_file = File.join(output_dir, "#{login}.json")

      existing = File.exist?(output_file) ? JSON.parse(File.read(output_file)) : {}
      needs_commits = !existing.key?("commits")
      needs_issues = !existing.key?("issues")

      next unless needs_commits || needs_issues

      print "  [#{i + 1}/#{logins.size}] #{login}..."

      if needs_commits
        existing["commits"] = api_get(COMMITS_API, "hosts/#{ECOSYSTEMS_HOST}/committers/#{login}")
        print " commits"
      end

      if needs_issues
        existing["issues"] = api_get(ISSUES_API, "hosts/#{ECOSYSTEMS_HOST}/authors/#{login}")
        print " issues"
      end

      existing["login"] = login
      existing["fetched_at"] = Time.now.iso8601

      File.write(output_file, JSON.generate(existing))
      puts " done"
    end
  end

  desc "Summarize fetched activity data"
  task :summary do
    dir = "data/activity"

    # Build company -> orgs map from both CSVs
    require "csv"
    company_orgs = {}
    CSV.read("innersource_github_profiles.csv", headers: true).each do |row|
      company = row["Organisation"]
      org = row["GitHub Profile"].split("/").last.downcase
      company_orgs[company] ||= Set.new
      company_orgs[company] << org
    end
    if File.exist?("org_aliases.csv")
      CSV.read("org_aliases.csv", headers: true).each do |row|
        company = row["Organisation"]
        org = row["GitHub Profile"].split("/").last.downcase
        company_orgs[company] ||= Set.new
        company_orgs[company] << org
      end
    end

    # Build login -> all affiliated orgs map
    login_orgs = {}
    Dir.glob("data/contributors/*.json").each do |file|
      org = File.basename(file, ".json").downcase
      # Find which company this org belongs to
      company = company_orgs.find { |_, orgs| orgs.include?(org) }&.first
      all_orgs = company ? company_orgs[company] : Set[org]

      contributors = JSON.parse(File.read(file))
      contributors.each do |c|
        next unless c["login"] && c["maintainer_activity"].to_i > 0
        login = c["login"].downcase
        login_orgs[login] ||= Set.new
        login_orgs[login].merge(all_orgs)
      end
    end

    files = Dir.glob(File.join(dir, "*.json"))
    with_commits = 0
    with_issues = 0
    total_external_repos = Set.new
    total_external_commit_repos = 0
    total_external_issue_repos = 0
    total_external_pr_repos = 0
    total_external_maintaining = 0
    with_external_activity = 0

    files.each do |file|
      data = JSON.parse(File.read(file))
      login = data["login"].downcase
      orgs = login_orgs[login] || Set.new

      with_commits += 1 if data["commits"]
      with_issues += 1 if data["issues"]

      commit_repos = (data.dig("commits", "repositories") || []).map { |r| r["full_name"] }
      issue_repos = (data.dig("issues", "issue_repos") || []).map { |r| r["repository"] }
      pr_repos = (data.dig("issues", "pull_request_repos") || []).map { |r| r["repository"] }
      maintaining = (data.dig("issues", "maintaining") || []).map { |r| r["repository"] }

      external = ->(repo) {
        owner = repo.split("/").first.downcase
        owner != login && !orgs.include?(owner)
      }

      ext_commits = commit_repos.select(&external)
      ext_issues = issue_repos.select(&external)
      ext_prs = pr_repos.select(&external)
      ext_maintaining = maintaining.select(&external)

      total_external_commit_repos += ext_commits.size
      total_external_issue_repos += ext_issues.size
      total_external_pr_repos += ext_prs.size
      total_external_maintaining += ext_maintaining.size
      (ext_commits + ext_issues + ext_prs).each { |r| total_external_repos << r }

      with_external_activity += 1 if ext_commits.any? || ext_issues.any? || ext_prs.any?
    end

    puts "#{files.size} contributors fetched (#{with_commits} with commit data, #{with_issues} with issue data)"
    puts "#{with_external_activity} with activity on external repos"
    puts "#{total_external_repos.size} unique external repos"
    puts "#{total_external_commit_repos} external commit repos, #{total_external_issue_repos} external issue repos, #{total_external_pr_repos} external PR repos"
    puts "#{total_external_maintaining} external maintainer relationships"
  end
end
