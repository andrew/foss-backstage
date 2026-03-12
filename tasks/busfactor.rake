require_relative "shared"
require "sqlite3"
require "cgi"

namespace :busfactor do
  desc "Fetch commit stats from commits.ecosyste.ms for top shared dependencies"
  task :fetch do
    db = SQLite3::Database.new(DB_PATH)

    # Get shared dependency repos (5+ orgs) with known GitHub repos
    deps = db.execute(<<-SQL)
      SELECT p.repository_url, COUNT(DISTINCT r.org) as org_count,
             p.downloads, p.dependent_packages_count
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      WHERE p.repository_url IS NOT NULL AND p.repository_url <> ''
        AND p.repository_url LIKE '%github.com/%'
        AND d.package_name NOT LIKE '.%'
      GROUP BY p.repository_url
      HAVING org_count >= 5
      ORDER BY org_count DESC
    SQL
    db.close

    seen_repos = Set.new
    to_fetch = []

    deps.each do |repo_url, org_count, downloads, dependents|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      next if seen_repos.include?(repo_name)
      seen_repos << repo_name
      to_fetch << [repo_name, org_count, downloads, dependents]
    end

    puts "#{to_fetch.size} unique dependency repos to fetch commit stats for"

    FileUtils.mkdir_p("data/busfactor")

    to_fetch.each_with_index do |(repo_name, org_count, downloads, dependents), i|
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

  desc "Analyse bus factor of shared dependencies"
  task :summary do
    db = SQLite3::Database.new(DB_PATH)

    # Get shared dependency repos with org counts and package maintainer counts
    deps = db.execute(<<-SQL)
      SELECT p.repository_url, COUNT(DISTINCT r.org) as org_count,
             MAX(p.downloads) as downloads, MAX(p.dependent_packages_count) as dependents,
             MAX(p.maintainer_count) as pkg_maintainers
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      WHERE p.repository_url IS NOT NULL AND p.repository_url <> ''
        AND p.repository_url LIKE '%github.com/%'
        AND d.package_name NOT LIKE '.%'
      GROUP BY p.repository_url
      HAVING org_count >= 5
      ORDER BY org_count DESC
    SQL
    db.close

    seen_repos = Set.new
    results = []

    deps.each do |repo_url, org_count, downloads, dependents, pkg_maintainers|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      next if seen_repos.include?(repo_name)
      seen_repos << repo_name

      safe_name = repo_name.gsub("/", "__")
      path = "data/busfactor/#{safe_name}.json"

      commit_data = if File.exist?(path)
        data = JSON.parse(File.read(path))
        data.empty? ? nil : data
      end

      results << {
        repo: repo_name,
        org_count: org_count,
        downloads: downloads,
        dependents: dependents,
        pkg_maintainers: pkg_maintainers.to_i,
        total_committers: commit_data&.dig("total_committers").to_i,
        past_year_committers: commit_data&.dig("past_year_total_committers").to_i,
        total_commits: commit_data&.dig("total_commits").to_i,
        past_year_commits: commit_data&.dig("past_year_total_commits").to_i,
        dds: commit_data&.dig("dds")&.to_f,
        past_year_dds: commit_data&.dig("past_year_dds")&.to_f,
        has_commit_data: !commit_data.nil?,
      }
    end

    with_data = results.select { |r| r[:has_commit_data] && r[:total_commits] > 0 }

    puts "=== Bus factor analysis of shared dependencies ==="
    puts
    puts "#{results.size} shared dependency repos (5+ ISC orgs)"
    puts "#{with_data.size} have commit stats from commits.ecosyste.ms"
    puts

    # Package registry maintainers (publish-bit holders)
    puts "Single package maintainer (only 1 person can publish):"
    puts "%-50s %5s %12s %8s %5s" % ["Repo", "Orgs", "Downloads", "Depnts", "Pub."]
    puts "-" * 85
    single_pub = results.select { |r| r[:pkg_maintainers] == 1 }.sort_by { |r| -r[:org_count] }
    single_pub.first(30).each do |r|
      puts "%-50s %5d %12d %8d %5d" % [r[:repo], r[:org_count], r[:downloads], r[:dependents], r[:pkg_maintainers]]
    end

    puts
    puts "Single/dual committer repos (bus factor = 1-2):"
    puts "%-50s %5s %12s %8s %5s %5s" % ["Repo", "Orgs", "Downloads", "Depnts", "Cmtr", "Pub."]
    puts "-" * 90
    single = with_data.select { |r| r[:total_committers] <= 2 }.sort_by { |r| -r[:org_count] }
    single.first(30).each do |r|
      puts "%-50s %5d %12d %8d %5d %5d" % [r[:repo], r[:org_count], r[:downloads], r[:dependents], r[:total_committers], r[:pkg_maintainers]]
    end

    puts
    puts "No commits in past year (depended on by 10+ orgs):"
    puts "%-50s %5s %12s %8s %5s %5s %5s" % ["Repo", "Orgs", "Downloads", "Depnts", "Cmtr", "YrCm", "Pub."]
    puts "-" * 95
    dormant = with_data.select { |r| r[:past_year_commits] == 0 && r[:org_count] >= 10 }.sort_by { |r| -r[:org_count] }
    dormant.first(30).each do |r|
      puts "%-50s %5d %12d %8d %5d %5d %5d" % [r[:repo], r[:org_count], r[:downloads], r[:dependents], r[:total_committers], r[:past_year_commits], r[:pkg_maintainers]]
    end

    puts
    puts "Lowest DDS (most concentrated authorship, 10+ orgs):"
    puts "%-50s %5s %12s %5s %6s %6s %5s" % ["Repo", "Orgs", "Downloads", "Cmtr", "DDS", "YrDDS", "Pub."]
    puts "-" * 95
    low_dds = with_data.select { |r| r[:dds] && r[:dds] > 0 && r[:org_count] >= 10 }.sort_by { |r| r[:dds] }
    low_dds.first(30).each do |r|
      puts "%-50s %5d %12d %5d %6.3f %6.3f %5d" % [r[:repo], r[:org_count], r[:downloads], r[:total_committers], r[:dds], r[:past_year_dds] || 0, r[:pkg_maintainers]]
    end

    puts
    puts "Highest risk: low DDS + no past year activity + 10+ orgs:"
    puts "%-50s %5s %12s %5s %6s %5s" % ["Repo", "Orgs", "Downloads", "Cmtr", "DDS", "Pub."]
    puts "-" * 90
    high_risk = with_data.select { |r| r[:dds] && r[:dds] < 0.3 && r[:past_year_commits] == 0 && r[:org_count] >= 10 }
      .sort_by { |r| -r[:org_count] }
    high_risk.first(30).each do |r|
      puts "%-50s %5d %12d %5d %6.3f %5d" % [r[:repo], r[:org_count], r[:downloads], r[:total_committers], r[:dds], r[:pkg_maintainers]]
    end
  end
end
