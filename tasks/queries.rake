require_relative "shared"
require "sqlite3"
require "csv"

def open_query_db
  if ENV["EXCLUDE"]
    # Build list of org logins to exclude, resolving company names to all their orgs
    company_orgs = {}
    CSV.read("innersource_github_profiles.csv", headers: true).each do |row|
      company = row["Organisation"]
      org = row["GitHub Profile"].split("/").last
      (company_orgs[company] ||= []) << org
    end
    if File.exist?("org_aliases.csv")
      CSV.read("org_aliases.csv", headers: true).each do |row|
        company = row["Organisation"]
        org = row["GitHub Profile"].split("/").last
        (company_orgs[company] ||= []) << org
      end
    end

    excluded = ENV["EXCLUDE"].split(",").flat_map { |c| company_orgs[c.strip] || [c.strip] }
    excluded_label = ENV["EXCLUDE"].downcase.gsub(/\s*,\s*/, "_").gsub(/\s+/, "-")
    filtered_path = "data/excluding_#{excluded_label}.db"

    # Build filtered copy if it doesn't exist or source is newer
    if !File.exist?(filtered_path) || File.mtime(DB_PATH) > File.mtime(filtered_path)
      puts "(Building filtered database excluding: #{excluded.join(', ')})"
      FileUtils.cp(DB_PATH, filtered_path)
      db = SQLite3::Database.new(filtered_path)
      excluded.each do |org|
        db.execute("DELETE FROM orgs WHERE login = ?", [org])
        db.execute("DELETE FROM repos WHERE org = ?", [org])
        db.execute("DELETE FROM maintainers WHERE org = ?", [org])
      end
      db.execute("DELETE FROM external_activity WHERE login NOT IN (SELECT DISTINCT login FROM maintainers)")
      db.execute("VACUUM")
      db.close
    end

    puts "(Using: #{filtered_path})"
    puts
    SQLite3::Database.new(filtered_path)
  else
    SQLite3::Database.new(DB_PATH)
  end
end

namespace :queries do
  desc "Q2: Do ISC members publish well-used open source? (EXCLUDE=Microsoft)"
  task :published do
    db = open_query_db

    puts "=== Q2: Published packages by ISC member orgs ==="
    puts

    total_repos = db.get_first_value("SELECT COUNT(*) FROM repos WHERE fork = 0 AND archived = 0")
    repos_with_packages = db.get_first_value(<<-SQL)
      SELECT COUNT(DISTINCT pp.repo) FROM published_packages pp
      JOIN repos r ON r.full_name = pp.repo
      WHERE r.fork = 0 AND r.archived = 0
    SQL
    total_packages = db.get_first_value(<<-SQL)
      SELECT COUNT(*) FROM published_packages pp
      JOIN repos r ON r.full_name = pp.repo
    SQL
    total_downloads = db.get_first_value(<<-SQL)
      SELECT SUM(pp.downloads) FROM published_packages pp
      JOIN repos r ON r.full_name = pp.repo
    SQL

    puts "#{total_repos} active non-fork repos"
    puts "#{repos_with_packages} publish packages (#{(repos_with_packages.to_f / total_repos * 100).round(1)}%)"
    puts "#{total_packages} total packages published"
    puts "#{total_downloads} total downloads"
    puts

    puts "Top 20 orgs by total package downloads:"
    db.execute(<<-SQL).each do |row|
      SELECT o.company, o.login, SUM(pp.downloads) as dl, COUNT(*) as pkg_count
      FROM published_packages pp
      JOIN repos r ON r.full_name = pp.repo
      JOIN orgs o ON o.login = r.org
      GROUP BY o.login
      ORDER BY dl DESC
      LIMIT 20
    SQL
      puts "  #{row[0]} (#{row[1]}): #{row[2]} downloads across #{row[3]} packages"
    end

    puts
    puts "Top 20 most-downloaded packages from ISC orgs:"
    db.execute(<<-SQL).each do |row|
      SELECT pp.ecosystem, pp.name, pp.downloads, pp.dependent_packages_count, r.org
      FROM published_packages pp
      JOIN repos r ON r.full_name = pp.repo
      ORDER BY pp.downloads DESC
      LIMIT 20
    SQL
      puts "  #{row[0]}/#{row[1]} (#{row[4]}): #{row[2]} downloads, #{row[3]} dependents"
    end

    db.close
  end

  desc "Q3: Do ISC members contribute to external open source? (EXCLUDE=Microsoft)"
  task :external_contributions do
    db = open_query_db

    puts "=== Q3: External OSS contributions ==="
    puts

    total_maintainers = db.get_first_value("SELECT COUNT(DISTINCT login) FROM maintainers")
    with_external = db.get_first_value("SELECT COUNT(DISTINCT login) FROM external_activity")
    total_activity = db.get_first_value("SELECT SUM(count) FROM external_activity")
    unique_repos = db.get_first_value("SELECT COUNT(DISTINCT repo) FROM external_activity")

    puts "#{total_maintainers} maintainers across all orgs"
    puts "#{with_external} have external activity (#{(with_external.to_f / total_maintainers * 100).round(1)}%)"
    puts "#{total_activity} total external contributions"
    puts "#{unique_repos} unique external repos contributed to"
    puts

    puts "Top 20 orgs by number of externally-active maintainers:"
    db.execute(<<-SQL).each do |row|
      SELECT o.company, m.org, COUNT(DISTINCT ea.login) as active, COUNT(DISTINCT m.login) as total
      FROM maintainers m
      JOIN orgs o ON o.login = m.org
      LEFT JOIN external_activity ea ON ea.login = m.login
      GROUP BY m.org
      ORDER BY active DESC
      LIMIT 20
    SQL
      pct = row[2].to_f / row[3] * 100
      puts "  #{row[0]} (#{row[1]}): #{row[2]}/#{row[3]} maintainers active externally (#{pct.round(1)}%)"
    end

    puts
    puts "Top 20 orgs by total external contribution count:"
    db.execute(<<-SQL).each do |row|
      SELECT o.company, m.org, SUM(ea.count) as total
      FROM external_activity ea
      JOIN maintainers m ON m.login = ea.login
      JOIN orgs o ON o.login = m.org
      GROUP BY m.org
      ORDER BY total DESC
      LIMIT 20
    SQL
      puts "  #{row[0]} (#{row[1]}): #{row[2]} contributions"
    end

    db.close
  end

  desc "Q5: Do ISC members contribute to their own dependencies? (EXCLUDE=Microsoft)"
  task :dependency_contributions do
    db = open_query_db

    puts "=== Q5: Contributions to own dependencies ==="
    puts

    # Build org -> maintainer logins mapping
    org_maintainers = {}
    db.execute("SELECT org, login FROM maintainers").each do |org, login|
      (org_maintainers[org] ||= Set.new) << login
    end

    # Build package -> repo name mapping from packages table
    pkg_repos = {}
    db.execute("SELECT ecosystem, package_name, repository_url FROM packages WHERE repository_url IS NOT NULL AND repository_url != ''").each do |eco, name, url|
      repo_name = url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      pkg_repos[[eco, name]] = repo_name
    end

    puts "#{pkg_repos.size} dependency packages with known GitHub repos"

    # Build login -> external activity mapping (repo -> {source, count})
    login_activity = {}
    db.execute("SELECT login, repo, source, count FROM external_activity").each do |login, repo, source, count|
      ((login_activity[login] ||= {})[repo] ||= []) << [source, count]
    end

    # For each org's dependencies, check if any of its maintainers contribute to the dependency's repo
    matches = []
    db.execute(<<-SQL).each do |org, company, eco, pkg_name|
      SELECT DISTINCT r.org, o.company, d.ecosystem, d.package_name
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN orgs o ON o.login = r.org
    SQL
      dep_repo = pkg_repos[[eco, pkg_name]]
      next unless dep_repo

      maintainers = org_maintainers[org] || Set.new
      maintainers.each do |login|
        activity = login_activity.dig(login, dep_repo)
        next unless activity
        activity.each do |source, count|
          matches << [company, pkg_name, dep_repo, login, source, count]
        end
      end
    end

    orgs_contributing = matches.map { |r| r[0] }.uniq
    packages_contributed_to = matches.map { |r| r[1] }.uniq
    people = matches.map { |r| r[3] }.uniq

    puts "#{orgs_contributing.size} orgs have maintainers contributing to their dependencies"
    puts "#{packages_contributed_to.size} dependency packages receive contributions from their dependents"
    puts "#{people.size} people contribute to packages their org depends on"
    puts

    puts "Top 20 orgs by dependency contributions:"
    by_org = matches.group_by { |r| r[0] }
    by_org.sort_by { |_, rows| -rows.sum { |r| r[5] } }.first(20).each do |company, rows|
      pkgs = rows.map { |r| r[1] }.uniq.size
      ppl = rows.map { |r| r[3] }.uniq.size
      total = rows.sum { |r| r[5] }
      puts "  #{company}: #{ppl} people contributing to #{pkgs} dependencies (#{total} contributions)"
    end

    puts
    puts "Top 20 most-contributed-to dependencies:"
    by_pkg = matches.group_by { |r| r[1] }
    by_pkg.sort_by { |_, rows| -rows.sum { |r| r[5] } }.first(20).each do |pkg, rows|
      orgs = rows.map { |r| r[0] }.uniq
      total = rows.sum { |r| r[5] }
      puts "  #{pkg}: #{total} contributions from #{orgs.size} orgs (#{orgs.first(3).join(', ')}#{orgs.size > 3 ? '...' : ''})"
    end

    db.close
  end

  desc "Q6: Activity type breakdown (EXCLUDE=Microsoft)"
  task :activity_types do
    db = open_query_db

    puts "=== Q6: Activity type breakdown ==="
    puts

    puts "Overall:"
    db.execute(<<-SQL).each do |row|
      SELECT source, COUNT(DISTINCT login) as people, SUM(count) as total, COUNT(DISTINCT repo) as repos
      FROM external_activity
      GROUP BY source
      ORDER BY total DESC
    SQL
      puts "  #{row[0]}: #{row[2]} contributions by #{row[1]} people across #{row[3]} repos"
    end

    puts
    puts "Per org (top 20 by total activity):"
    orgs = db.execute(<<-SQL)
      SELECT o.company, m.org, SUM(ea.count) as total
      FROM external_activity ea
      JOIN maintainers m ON m.login = ea.login
      JOIN orgs o ON o.login = m.org
      GROUP BY m.org
      ORDER BY total DESC
      LIMIT 20
    SQL

    orgs.each do |company, org, total|
      breakdown = db.execute(<<-SQL, [org])
        SELECT ea.source, SUM(ea.count)
        FROM external_activity ea
        JOIN maintainers m ON m.login = ea.login AND m.org = ?
        GROUP BY ea.source
        ORDER BY SUM(ea.count) DESC
      SQL
      parts = breakdown.map { |s, c| "#{s}:#{c}" }.join(", ")
      puts "  #{company} (#{org}): #{total} total - #{parts}"
    end

    db.close
  end

  desc "Q7: Critical shared dependencies (EXCLUDE=Microsoft)"
  task :shared_dependencies do
    db = open_query_db

    puts "=== Q7: Shared dependencies across ISC orgs ==="
    puts

    puts "Top 50 packages used by the most ISC orgs:"
    db.execute(<<-SQL).each do |row|
      SELECT d.ecosystem, d.package_name,
             COUNT(DISTINCT r.org) as org_count,
             COUNT(DISTINCT d.repo) as repo_count,
             p.downloads, p.dependent_packages_count, p.repository_url
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      LEFT JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      WHERE d.package_name NOT LIKE '.%'
      GROUP BY d.ecosystem, d.package_name
      ORDER BY org_count DESC, repo_count DESC
      LIMIT 50
    SQL
      dl = row[4] ? " #{row[4]} downloads," : ""
      dep = row[5] ? " #{row[5]} dependents," : ""
      repo = row[6] ? " #{row[6]}" : ""
      puts "  #{row[0]}/#{row[1]}: #{row[2]} orgs, #{row[3]} repos,#{dl}#{dep}#{repo}"
    end

    puts
    puts "Org overlap distribution:"
    db.execute(<<-SQL).each do |row|
      SELECT org_count, COUNT(*) as packages
      FROM (
        SELECT d.ecosystem, d.package_name, COUNT(DISTINCT r.org) as org_count
        FROM dependencies d
        JOIN repos r ON r.full_name = d.repo
        WHERE d.package_name NOT LIKE '.%'
        GROUP BY d.ecosystem, d.package_name
      )
      GROUP BY org_count
      ORDER BY org_count DESC
    SQL
      puts "  #{row[0]} orgs: #{row[1]} packages"
    end

    db.close
  end

  desc "Q8: Contribution vs dependency overlap (EXCLUDE=Microsoft)"
  task :dependency_gap do
    db = open_query_db

    puts "=== Q8: Dependency vs contribution gap ==="
    puts

    shared_deps = db.execute(<<-SQL)
      SELECT d.ecosystem, d.package_name, COUNT(DISTINCT r.org) as org_count,
             p.repository_url, p.downloads, p.dependent_packages_count
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      WHERE p.repository_url IS NOT NULL AND p.repository_url != ''
      GROUP BY d.ecosystem, d.package_name
      HAVING org_count >= 5
      ORDER BY org_count DESC
    SQL

    puts "#{shared_deps.size} shared dependencies (5+ orgs) with known repos"
    puts

    contributed = 0
    not_contributed = 0
    gap = []
    with_contributions = []

    shared_deps.each do |eco, pkg, org_count, repo_url, downloads, dependents|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      activity = db.get_first_value(
        "SELECT SUM(count) FROM external_activity WHERE repo = ?", [repo_name]
      )
      if activity && activity > 0
        contributed += 1
        with_contributions << [eco, pkg, org_count, repo_url, downloads, dependents, activity]
      else
        not_contributed += 1
        gap << [eco, pkg, org_count, downloads, dependents, repo_name]
      end
    end

    puts "#{contributed} shared deps receive contributions from ISC maintainers"
    puts "#{not_contributed} shared deps have NO contributions from ISC maintainers"
    puts

    puts "Top 30 contributed-to shared dependencies:"
    with_contributions.sort_by { |r| -r[6] }.first(30).each do |eco, pkg, org_count, repo_url, downloads, dependents, total_activity|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      top = db.execute(
        "SELECT login, source, count FROM external_activity WHERE repo = ? ORDER BY count DESC LIMIT 3",
        [repo_name]
      )
      contributors = top.map { |r| "#{r[0]}(#{r[1]}:#{r[2]})" }.join(", ")
      puts "  #{eco}/#{pkg}: #{org_count} orgs depend, #{downloads} downloads, #{total_activity} contributions - #{contributors}"
    end

    puts
    puts "Top 30 gap packages (most orgs depend on, nobody contributes to):"
    gap.sort_by { |r| -r[2] }.first(30).each do |eco, pkg, org_count, downloads, dependents, repo_name|
      puts "  #{eco}/#{pkg}: #{org_count} orgs depend, #{downloads} downloads, #{dependents} dependents - #{repo_name}"
    end

    db.close
  end
end
