require_relative "shared"
require "sqlite3"
require "cgi"

namespace :package_repos do
  desc "Fetch commit stats from commits.ecosyste.ms for all dependency package repos (LIMIT=n to restrict)"
  task :commits do
    db = SQLite3::Database.new(DB_PATH)
    repos = db.execute(<<-SQL)
      SELECT DISTINCT repository_url
      FROM packages
      WHERE repository_url IS NOT NULL AND repository_url <> ''
        AND repository_url LIKE '%github.com/%'
    SQL
    db.close

    seen = Set.new
    to_fetch = repos.filter_map { |(url)|
      name = url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      next if seen.include?(name)
      seen << name
      name
    }

    to_fetch = to_fetch.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "#{to_fetch.size} unique package repos to fetch commit stats for"

    FileUtils.mkdir_p("data/busfactor")

    to_fetch.each_with_index do |repo_name, i|
      safe_name = repo_name.gsub("/", "__")
      path = "data/busfactor/#{safe_name}.json"

      if File.exist?(path)
        print "  [#{i + 1}/#{to_fetch.size}] #{repo_name}... cached\n"
        next
      end

      print "  [#{i + 1}/#{to_fetch.size}] #{repo_name}..."

      encoded = repo_name.split("/").map { |p| CGI.escape(p) }.join("%2F")
      data = api_get(COMMITS_API, "hosts/GitHub/repositories/#{encoded}")

      if data
        File.write(path, JSON.pretty_generate(data))
        puts " #{data['total_committers']} committers, dds=#{data['dds']&.round(3)}"
      else
        File.write(path, "{}")
        puts " not found"
      end
    end
  end

  desc "Fetch issue stats from issues.ecosyste.ms for all dependency package repos (LIMIT=n to restrict)"
  task :issues do
    db = SQLite3::Database.new(DB_PATH)
    repos = db.execute(<<-SQL)
      SELECT DISTINCT repository_url
      FROM packages
      WHERE repository_url IS NOT NULL AND repository_url <> ''
        AND repository_url LIKE '%github.com/%'
    SQL
    db.close

    seen = Set.new
    to_fetch = repos.filter_map { |(url)|
      name = url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      next if seen.include?(name)
      seen << name
      name
    }

    to_fetch = to_fetch.first(ENV["LIMIT"].to_i) if ENV["LIMIT"]

    puts "#{to_fetch.size} unique package repos to fetch issue stats for"

    FileUtils.mkdir_p("data/package_issues")

    to_fetch.each_with_index do |repo_name, i|
      safe_name = repo_name.gsub("/", "__")
      path = "data/package_issues/#{safe_name}.json"

      if File.exist?(path)
        print "  [#{i + 1}/#{to_fetch.size}] #{repo_name}... cached\n"
        next
      end

      print "  [#{i + 1}/#{to_fetch.size}] #{repo_name}..."

      encoded = repo_name.split("/").map { |p| CGI.escape(p) }.join("%2F")
      data = api_get(ISSUES_API, "hosts/GitHub/repositories/#{encoded}")

      if data
        File.write(path, JSON.pretty_generate(data))
        puts " #{data['issues_count']} issues, #{data['pull_requests_count']} PRs"
      else
        File.write(path, "{}")
        puts " not found"
      end
    end
  end
end
