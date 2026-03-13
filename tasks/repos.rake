require_relative "shared"
require "csv"

namespace :repos do
  desc "Fetch repos for all orgs from repos.ecosyste.ms (LIMIT=n to restrict)"
  task :fetch do
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

      repos = []
      page = 1

      loop do
        data = api_get(REPOS_API, "hosts/GitHub/owners/#{github_login}/repositories?page=#{page}")
        break if data.nil? || !data.is_a?(Array) || data.empty?
        repos.concat(data.map { |r|
          {
            full_name: r["full_name"],
            fork: r["fork"],
            archived: r["archived"],
            status: r["archived"] ? "archived" : (r["status"] == "disabled" ? "disabled" : "active")
          }
        })
        break if data.length < 100
        page += 1
      end

      File.write(output_file, JSON.pretty_generate(repos))
      puts "  #{repos.size} repos"
    end
  end
end
