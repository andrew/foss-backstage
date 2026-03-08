require "csv"
require "json"
require "octokit"
require "fileutils"

namespace :repos do
  desc "Fetch repos for all orgs from GitHub (LIMIT=n to restrict)"
  task :fetch do
    client = Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
    client.auto_paginate = true

    orgs = CSV.read("innersource_github_profiles.csv", headers: true)
    orgs = orgs.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]
    output_dir = "data/repos"
    FileUtils.mkdir_p(output_dir)

    orgs.each do |row|
      org_name = row["Organisation"]
      github_login = row["GitHub Profile"].split("/").last
      output_file = File.join(output_dir, "#{github_login}.json")

      if File.exist?(output_file)
        puts "Skipping #{org_name} (#{github_login}) - already fetched"
        next
      end

      puts "Fetching repos for #{org_name} (#{github_login})..."

      begin
        repos = client.org_repos(github_login, type: "public").map do |repo|
          {
            full_name: repo.full_name,
            fork: repo.fork,
            archived: repo.archived,
            status: repo.archived ? "archived" : (repo.disabled ? "disabled" : "active")
          }
        end

        File.write(output_file, JSON.pretty_generate(repos))
        puts "  #{repos.size} repos"
      rescue Octokit::TooManyRequests => e
        wait = client.rate_limit.resets_in + 1
        puts "  Rate limited, sleeping #{wait}s..."
        sleep wait
        retry
      rescue Octokit::NotFound
        puts "  Not found, skipping"
      rescue Octokit::Error => e
        puts "  Error: #{e.message}"
      end
    end
  end
end
