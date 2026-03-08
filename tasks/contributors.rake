require "json"
require "faraday"
require "faraday/retry"
require "fileutils"

ECOSYSTEMS_HOST = "GitHub"
COMMITS_API = "https://commits.ecosyste.ms/api/v1/"
ISSUES_API = "https://issues.ecosyste.ms/api/v1/"
USER_AGENT = "foss-backstage/1.0 (andrew@nesbitt.io)"

def ecosystems_client(base_url)
  Faraday.new(url: base_url) do |f|
    f.headers["User-Agent"] = USER_AGENT
    f.headers["Accept"] = "application/json"
    f.request :retry, max: 3, interval: 1, backoff_factor: 2,
      retry_statuses: [429, 500, 502, 503],
      retry_block: -> (env, *) {
        reset = env.response_headers["x-ratelimit-reset"]
        if reset
          wait = [reset.to_i - Time.now.to_i, 1].max
          puts " rate limited, sleeping #{wait}s..."
          sleep wait
        end
      }
  end
end

def api_get(base_url, path)
  client = ecosystems_client(base_url)
  response = client.get(path)
  return nil unless response.success?
  JSON.parse(response.body)
rescue Faraday::Error => e
  puts " error (#{base_url}#{path}): #{e.message}"
  nil
rescue JSON::ParserError => e
  puts " JSON error (#{base_url}#{path}): #{response.body[0..100]}"
  nil
end

def api_ping(base_url, full_name)
  client = ecosystems_client(base_url)
  response = client.get("hosts/#{ECOSYSTEMS_HOST}/repositories/#{full_name}/ping")
  response.status
rescue Faraday::Error => e
  puts " error: #{e.message}"
  nil
end

namespace :contributors do
  desc "Ping commits + issues ecosyste.ms to index repos (LIMIT=n to restrict orgs)"
  task :ping do
    input_dir = "data/repos"
    pinged_dir = "data/pinged"

    files = Dir.glob(File.join(input_dir, "*.json")).sort
    files = files.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    files.each do |file|
      org = File.basename(file, ".json")
      repos = JSON.parse(File.read(file))
      active_repos = repos.reject { |r| r["fork"] || r["archived"] }

      puts "Pinging #{org} (#{active_repos.size} active repos)..."

      active_repos.each do |repo|
        full_name = repo["full_name"]
        ping_file = File.join(pinged_dir, "#{full_name}.json")

        if File.exist?(ping_file)
          puts "  #{full_name}... skipped"
          next
        end

        print "  #{full_name}..."
        commits_status = api_ping(COMMITS_API, full_name)
        issues_status = api_ping(ISSUES_API, full_name)
        puts " commits:#{commits_status || 'error'} issues:#{issues_status || 'error'}"

        FileUtils.mkdir_p(File.dirname(ping_file))
        File.write(ping_file, JSON.generate({
          commits: commits_status,
          issues: issues_status,
          pinged_at: Time.now.iso8601
        }))
      end
    end
  end

  desc "Fetch contributors from commits + issues ecosyste.ms (LIMIT=n to restrict orgs)"
  task :fetch do
    input_dir = "data/repos"
    output_dir = "data/contributors"
    FileUtils.mkdir_p(output_dir)

    files = Dir.glob(File.join(input_dir, "*.json")).sort
    files = files.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    files.each do |file|
      org = File.basename(file, ".json")
      output_file = File.join(output_dir, "#{org}.json")

      if File.exist?(output_file)
        puts "Skipping #{org} - already fetched"
        next
      end

      repos = JSON.parse(File.read(file))
      active_repos = repos.reject { |r| r["fork"] || r["archived"] }

      puts "Fetching contributors for #{org} (#{active_repos.size} active repos)..."

      org_contributors = {}

      active_repos.each do |repo|
        full_name = repo["full_name"]
        print "  #{full_name}..."

        # Commits data
        commits_data = api_get(COMMITS_API, "hosts/#{ECOSYSTEMS_HOST}/repositories/#{full_name}")
        committers = commits_data ? (commits_data["committers"] || []) : []

        committers.each do |c|
          key = c["login"] || c["email"]
          next unless key

          org_contributors[key] ||= { login: c["login"], email: c["email"], name: c["name"], repos: [], commits: 0, maintainer_activity: 0 }
          org_contributors[key][:repos] << full_name unless org_contributors[key][:repos].include?(full_name)
          org_contributors[key][:commits] += c["count"]
        end

        # Issues data - maintainers only (MEMBER, OWNER, COLLABORATOR)
        issues_data = api_get(ISSUES_API, "hosts/#{ECOSYSTEMS_HOST}/repositories/#{full_name}")
        maintainers = issues_data ? (issues_data["maintainers"] || []) : []
        active_maintainers = issues_data ? (issues_data["active_maintainers"] || []) : []

        (maintainers + active_maintainers).uniq { |m| m["login"] }.each do |m|
          login = m["login"]
          next unless login

          org_contributors[login] ||= { login: login, email: nil, name: nil, repos: [], commits: 0, maintainer_activity: 0 }
          org_contributors[login][:repos] << full_name unless org_contributors[login][:repos].include?(full_name)
          org_contributors[login][:maintainer_activity] += m["count"]
        end

        puts " #{committers.size} committers, #{maintainers.size} maintainers"
      end

      File.write(output_file, JSON.pretty_generate(org_contributors.values))
      puts "  #{org_contributors.size} unique contributors"
    end
  end

  desc "Summarize collected contributor data"
  task :summary do
    dir = "data/contributors"

    Dir.glob(File.join(dir, "*.json")).sort.each do |file|
      org = File.basename(file, ".json")
      contributors = JSON.parse(File.read(file))
      total_commits = contributors.sum { |c| c["commits"] }
      total_maintainer = contributors.sum { |c| c["maintainer_activity"] }
      with_login = contributors.count { |c| c["login"] }
      puts "#{org}: #{contributors.size} contributors (#{with_login} with login), #{total_commits} commits, #{total_maintainer} maintainer activities"
    end
  end
end
