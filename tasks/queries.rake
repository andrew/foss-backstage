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

  desc "Export consumption vs contribution CSV (EXCLUDE=Microsoft)"
  task :csv do
    db = open_query_db

    deps = db.execute(<<-SQL)
      SELECT d.ecosystem, d.package_name,
             COUNT(DISTINCT r.org) as depending_orgs,
             p.downloads, p.dependent_packages_count, p.repository_url, p.funding_links
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      WHERE p.repository_url IS NOT NULL AND p.repository_url <> ''
        AND d.package_name NOT LIKE '.%'
      GROUP BY d.ecosystem, d.package_name
      HAVING depending_orgs >= 5
      ORDER BY depending_orgs DESC, p.downloads DESC
    SQL

    seen_repos = Set.new
    results = []

    deps.each do |eco, name, org_count, downloads, dependents, repo_url, funding_links|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      next if seen_repos.include?(repo_name)
      seen_repos << repo_name

      activity = db.execute(
        "SELECT source, SUM(count), COUNT(DISTINCT login) FROM external_activity WHERE repo = ? GROUP BY source",
        [repo_name]
      )

      commits = 0; issues = 0; prs = 0; maintaining = 0
      commit_people = 0; issue_people = 0; pr_people = 0; maint_people = 0

      activity.each do |source, total, people|
        case source
        when "commits" then commits = total; commit_people = people
        when "issues" then issues = total; issue_people = people
        when "pull_requests" then prs = total; pr_people = people
        when "maintaining" then maintaining = total; maint_people = people
        end
      end

      has_github_sponsors = funding_links&.include?("github.com/sponsors") ? true : false
      has_opencollective = funding_links&.include?("opencollective.com") ? true : false
      has_tidelift = funding_links&.include?("tidelift.com") ? true : false
      has_any_funding = funding_links && funding_links.length > 0

      results << [
        "#{eco}/#{name}", repo_name, org_count, downloads, dependents,
        commits, commit_people, issues, issue_people, prs, pr_people, maintaining, maint_people,
        commits + issues + prs + maintaining,
        has_any_funding, has_github_sponsors, has_opencollective, has_tidelift,
        funding_links
      ]
    end

    output = "data/consumption_vs_contribution.csv"
    CSV.open(output, "w") do |csv|
      csv << %w[package repo depending_orgs downloads dependents commits commit_people issues issue_people prs pr_people maintaining maint_people total_contributions has_funding has_github_sponsors has_opencollective has_tidelift funding_links]
      results.each { |r| csv << r }
    end

    with_funding = results.count { |r| r[14] }
    zero_contrib = results.select { |r| r[13] == 0 }
    zero_with_funding = zero_contrib.count { |r| r[14] }

    puts "#{results.size} unique dependency repos written to #{output}"
    puts "#{with_funding}/#{results.size} have funding links (#{(with_funding.to_f / results.size * 100).round(1)}%)"
    puts "#{zero_contrib.size} receive zero ISC contributions"
    puts "#{zero_with_funding}/#{zero_contrib.size} of those have funding links (#{(zero_with_funding.to_f / zero_contrib.size * 100).round(1)}%)"

    db.close
  end

  desc "Cross-ISC contributions: do ISC members contribute to each other's repos?"
  task :cross_isc do
    db = open_query_db

    puts "=== Cross-ISC contributions ==="
    puts

    # Build set of all ISC org logins
    isc_orgs = Set.new
    db.execute("SELECT login FROM orgs").each { |row| isc_orgs << row[0].downcase }

    # Find external activity where the repo owner is another ISC org
    cross = db.execute(<<-SQL)
      SELECT ea.login, ea.repo, ea.source, ea.count, m.org as home_org
      FROM external_activity ea
      JOIN maintainers m ON m.login = ea.login
    SQL

    matches = []
    cross.each do |login, repo, source, count, home_org|
      target_owner = repo.split("/").first.downcase
      next unless isc_orgs.include?(target_owner)
      next if target_owner == home_org.downcase
      matches << [home_org, login, target_owner, repo, source, count]
    end

    people = matches.map { |r| r[1] }.uniq
    source_orgs = matches.map { |r| r[0] }.uniq
    target_orgs = matches.map { |r| r[2] }.uniq
    target_repos = matches.map { |r| r[3] }.uniq
    total = matches.sum { |r| r[5] }

    puts "#{people.size} people from #{source_orgs.size} ISC orgs contribute to #{target_repos.size} repos at #{target_orgs.size} other ISC orgs"
    puts "#{total} total cross-ISC contributions"
    puts

    puts "Top 20 source orgs (contributing TO other ISC orgs):"
    by_source = matches.group_by { |r| r[0] }
    by_source.sort_by { |_, rows| -rows.sum { |r| r[5] } }.first(20).each do |org, rows|
      company = db.get_first_value("SELECT company FROM orgs WHERE login = ?", [org])
      targets = rows.map { |r| r[2] }.uniq
      puts "  #{company} (#{org}): #{rows.sum { |r| r[5] }} contributions to #{targets.size} ISC orgs by #{rows.map { |r| r[1] }.uniq.size} people"
    end

    puts
    puts "Top 20 target orgs (receiving FROM other ISC orgs):"
    by_target = matches.group_by { |r| r[2] }
    by_target.sort_by { |_, rows| -rows.sum { |r| r[5] } }.first(20).each do |org, rows|
      company = db.get_first_value("SELECT company FROM orgs WHERE login = ?", [org])
      sources = rows.map { |r| r[0] }.uniq
      puts "  #{company} (#{org}): #{rows.sum { |r| r[5] }} contributions from #{sources.size} ISC orgs by #{rows.map { |r| r[1] }.uniq.size} people"
    end

    puts
    puts "Top 20 org-to-org flows:"
    by_flow = matches.group_by { |r| [r[0], r[2]] }
    by_flow.sort_by { |_, rows| -rows.sum { |r| r[5] } }.first(20).each do |(src, tgt), rows|
      src_company = db.get_first_value("SELECT company FROM orgs WHERE login = ?", [src])
      tgt_company = db.get_first_value("SELECT company FROM orgs WHERE login = ?", [tgt])
      puts "  #{src_company} -> #{tgt_company}: #{rows.sum { |r| r[5] }} contributions by #{rows.map { |r| r[1] }.uniq.size} people"
    end

    db.close
  end

  desc "License analysis: what licenses do ISC orgs depend on?"
  task :licenses do
    db = open_query_db

    puts "=== License analysis ==="
    puts

    # Licenses of dependency repos
    puts "Licenses of external repos ISC maintainers contribute to:"
    db.execute(<<-SQL).each do |row|
      SELECT COALESCE(er.license, 'unknown') as license, COUNT(DISTINCT er.full_name) as repos
      FROM external_repos er
      GROUP BY license
      ORDER BY repos DESC
      LIMIT 30
    SQL
      puts "  #{row[0]}: #{row[1]} repos"
    end

    puts
    puts "Licenses of shared dependencies (5+ ISC orgs depend on):"
    db.execute(<<-SQL).each do |row|
      SELECT COALESCE(er.license, 'unknown') as license,
             COUNT(DISTINCT p.package_name) as packages
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      JOIN external_repos er ON er.full_name = REPLACE(REPLACE(p.repository_url, 'https://github.com/', ''), '.git', '')
      WHERE p.repository_url IS NOT NULL AND p.repository_url <> ''
      GROUP BY license
      ORDER BY packages DESC
      LIMIT 30
    SQL
      puts "  #{row[0]}: #{row[1]} packages"
    end

    puts
    puts "Copyleft dependencies (GPL/LGPL/AGPL/MPL) used by ISC orgs:"
    db.execute(<<-SQL).each do |row|
      SELECT er.license, d.ecosystem, d.package_name, COUNT(DISTINCT r.org) as org_count,
             p.repository_url
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      JOIN external_repos er ON er.full_name = REPLACE(REPLACE(p.repository_url, 'https://github.com/', ''), '.git', '')
      WHERE er.license LIKE '%GPL%' OR er.license LIKE '%MPL%' OR er.license LIKE '%AGPL%'
        OR er.license LIKE '%Copyleft%' OR er.license LIKE '%EUPL%'
      GROUP BY d.ecosystem, d.package_name
      HAVING org_count >= 3
      ORDER BY org_count DESC
      LIMIT 30
    SQL
      puts "  #{row[1]}/#{row[2]} (#{row[0]}): #{row[3]} orgs - #{row[4]}"
    end

    db.close
  end

  desc "Abandoned dependencies: archived or stale dependency repos"
  task :abandoned do
    db = open_query_db

    puts "=== Abandoned dependencies ==="
    puts

    puts "Archived dependency repos still depended on by ISC orgs:"
    db.execute(<<-SQL).each do |row|
      SELECT d.ecosystem, d.package_name, COUNT(DISTINCT r.org) as org_count,
             p.downloads, p.dependent_packages_count, p.repository_url
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      JOIN external_repos er ON er.full_name = REPLACE(REPLACE(p.repository_url, 'https://github.com/', ''), '.git', '')
      WHERE er.archived = 1
        AND p.repository_url IS NOT NULL AND p.repository_url <> ''
      GROUP BY d.ecosystem, d.package_name
      HAVING org_count >= 3
      ORDER BY org_count DESC
    SQL
      puts "  #{row[0]}/#{row[1]}: #{row[2]} orgs, #{row[3]} downloads, #{row[4]} dependents - #{row[5]}"
    end

    puts
    total_archived = db.get_first_value(<<-SQL)
      SELECT COUNT(DISTINCT d.ecosystem || '/' || d.package_name)
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      JOIN external_repos er ON er.full_name = REPLACE(REPLACE(p.repository_url, 'https://github.com/', ''), '.git', '')
      WHERE er.archived = 1
        AND p.repository_url IS NOT NULL AND p.repository_url <> ''
    SQL
    puts "#{total_archived} total archived dependency packages in use"

    db.close
  end

  desc "Org size vs contribution rate"
  task :org_size do
    db = open_query_db

    puts "=== Org size vs external contribution rate ==="
    puts

    puts "%-30s %8s %8s %8s %10s %8s" % ["Company", "Maint.", "Active", "Rate", "Contribs", "Per cap."]
    puts "-" * 85

    db.execute(<<-SQL).each do |row|
      SELECT o.company, o.login,
             COUNT(DISTINCT m.login) as total_maintainers,
             COUNT(DISTINCT ea.login) as active_externally,
             COALESCE(SUM(ea.count), 0) as total_contributions
      FROM orgs o
      JOIN maintainers m ON m.org = o.login
      LEFT JOIN external_activity ea ON ea.login = m.login
      GROUP BY o.login
      HAVING total_maintainers >= 10
      ORDER BY total_maintainers DESC
    SQL
      company, login, total, active, contribs = row
      rate = (active.to_f / total * 100).round(1)
      per_capita = total > 0 ? (contribs.to_f / total).round(1) : 0
      puts "%-30s %8d %8d %7.1f%% %10d %8.1f" % [company || login, total, active, rate, contribs, per_capita]
    end

    db.close
  end

  desc "Language ecosystem gaps: contribution rates by dependency ecosystem"
  task :ecosystem_gaps do
    db = open_query_db

    puts "=== Contribution rates by dependency ecosystem ==="
    puts

    # Get all dependency ecosystems with their package counts and org counts
    ecosystems = db.execute(<<-SQL)
      SELECT d.ecosystem,
             COUNT(DISTINCT d.package_name) as packages,
             COUNT(DISTINCT r.org) as orgs,
             COUNT(DISTINCT d.repo) as repos
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      WHERE d.package_name NOT LIKE '.%'
      GROUP BY d.ecosystem
      HAVING packages >= 10
      ORDER BY packages DESC
    SQL

    puts "%-20s %8s %6s %8s %10s %10s %8s" % ["Ecosystem", "Packages", "Orgs", "With repo", "Contrib'd", "Gap", "Gap %"]
    puts "-" * 85

    ecosystems.each do |eco, pkg_count, org_count, repo_count|
      # How many dependency packages in this ecosystem have known repos and contributions?
      with_repo = db.get_first_value(<<-SQL, [eco])
        SELECT COUNT(DISTINCT d.package_name)
        FROM dependencies d
        JOIN repos r ON r.full_name = d.repo
        JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
        WHERE d.ecosystem = ?
          AND p.repository_url IS NOT NULL AND p.repository_url <> ''
          AND d.package_name NOT LIKE '.%'
        GROUP BY d.ecosystem
      SQL
      with_repo ||= 0

      contributed = db.get_first_value(<<-SQL, [eco])
        SELECT COUNT(DISTINCT d.package_name)
        FROM dependencies d
        JOIN repos r ON r.full_name = d.repo
        JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
        JOIN external_activity ea ON ea.repo = REPLACE(REPLACE(p.repository_url, 'https://github.com/', ''), '.git', '')
        WHERE d.ecosystem = ?
          AND p.repository_url IS NOT NULL AND p.repository_url <> ''
          AND d.package_name NOT LIKE '.%'
      SQL
      contributed ||= 0

      gap = with_repo - contributed
      gap_pct = with_repo > 0 ? (gap.to_f / with_repo * 100).round(1) : 0

      puts "%-20s %8d %6d %8d %10d %10d %7.1f%%" % [eco, pkg_count, org_count, with_repo, contributed, gap, gap_pct]
    end

    db.close
  end

  desc "Funding vs contribution correlation"
  task :funding_vs_contribution do
    db = open_query_db

    puts "=== Funding vs contribution correlation ==="
    puts

    # All dependency packages with repos, split by funding status
    deps = db.execute(<<-SQL)
      SELECT p.ecosystem, p.package_name, p.repository_url, p.funding_links,
             p.downloads, p.dependent_packages_count
      FROM packages p
      WHERE p.repository_url IS NOT NULL AND p.repository_url <> ''
    SQL

    funded_contrib = 0; funded_no_contrib = 0
    unfunded_contrib = 0; unfunded_no_contrib = 0
    funded_total_activity = 0; unfunded_total_activity = 0

    deps.each do |eco, name, repo_url, funding, downloads, dependents|
      repo_name = repo_url.sub(%r{https?://github\.com/}, "").sub(/\.git$/, "")
      activity = db.get_first_value("SELECT SUM(count) FROM external_activity WHERE repo = ?", [repo_name]).to_i
      has_funding = funding && funding.length > 0

      if has_funding
        if activity > 0
          funded_contrib += 1
          funded_total_activity += activity
        else
          funded_no_contrib += 1
        end
      else
        if activity > 0
          unfunded_contrib += 1
          unfunded_total_activity += activity
        else
          unfunded_no_contrib += 1
        end
      end
    end

    funded_total = funded_contrib + funded_no_contrib
    unfunded_total = unfunded_contrib + unfunded_no_contrib

    puts "Packages WITH funding links:"
    puts "  #{funded_total} total"
    puts "  #{funded_contrib} receive ISC contributions (#{(funded_contrib.to_f / funded_total * 100).round(1)}%)"
    puts "  #{funded_no_contrib} receive none (#{(funded_no_contrib.to_f / funded_total * 100).round(1)}%)"
    puts "  #{funded_total_activity} total contributions"
    puts "  #{funded_total > 0 ? (funded_total_activity.to_f / funded_total).round(1) : 0} avg contributions per package"
    puts

    puts "Packages WITHOUT funding links:"
    puts "  #{unfunded_total} total"
    puts "  #{unfunded_contrib} receive ISC contributions (#{(unfunded_contrib.to_f / unfunded_total * 100).round(1)}%)"
    puts "  #{unfunded_no_contrib} receive none (#{(unfunded_no_contrib.to_f / unfunded_total * 100).round(1)}%)"
    puts "  #{unfunded_total_activity} total contributions"
    puts "  #{unfunded_total > 0 ? (unfunded_total_activity.to_f / unfunded_total).round(1) : 0} avg contributions per package"
    puts

    puts "Funding type breakdown across all dependency packages:"
    funding_types = Hash.new(0)
    deps.each do |_, _, _, funding, _, _|
      next unless funding && funding.length > 0
      funding.split(",").each do |link|
        case link
        when /github\.com\/sponsors/ then funding_types["GitHub Sponsors"] += 1
        when /opencollective\.com/ then funding_types["OpenCollective"] += 1
        when /tidelift\.com/ then funding_types["Tidelift"] += 1
        when /patreon\.com/ then funding_types["Patreon"] += 1
        when /buymeacoffee/ then funding_types["Buy Me a Coffee"] += 1
        when /paypal/ then funding_types["PayPal"] += 1
        else funding_types["Other"] += 1
        end
      end
    end
    funding_types.sort_by { |_, c| -c }.each do |type, count|
      puts "  #{type}: #{count}"
    end

    db.close
  end

  desc "Maintainer overlap: people who maintain at multiple ISC orgs"
  task :maintainer_overlap do
    db = open_query_db

    puts "=== Maintainer overlap across ISC orgs ==="
    puts

    multi = db.execute(<<-SQL)
      SELECT m.login, COUNT(DISTINCT m.org) as org_count,
             GROUP_CONCAT(DISTINCT m.org) as orgs,
             SUM(m.commits) as total_commits
      FROM maintainers m
      GROUP BY m.login
      HAVING org_count > 1
      ORDER BY org_count DESC, total_commits DESC
    SQL

    puts "#{multi.size} maintainers appear in multiple ISC orgs"
    puts

    by_count = multi.group_by { |r| r[1] }
    by_count.sort_by { |k, _| -k }.each do |count, rows|
      puts "#{count} orgs: #{rows.size} maintainers"
    end

    puts
    puts "Top 30 multi-org maintainers:"
    multi.first(30).each do |login, org_count, orgs, commits|
      # Check external activity too
      ext = db.get_first_value("SELECT SUM(count) FROM external_activity WHERE login = ?", [login]).to_i
      org_list = orgs.split(",")
      companies = org_list.map { |o| db.get_first_value("SELECT company FROM orgs WHERE login = ?", [o]) }.compact.uniq
      puts "  #{login}: #{org_count} orgs (#{companies.join(', ')}), #{commits} commits, #{ext} external contributions"
    end

    # Check if multi-org maintainers are same-company (org aliases) or truly cross-company
    puts
    puts "Cross-company vs same-company overlap:"
    cross_company = 0
    same_company = 0
    multi.each do |login, org_count, orgs, _|
      org_list = orgs.split(",")
      companies = org_list.map { |o| db.get_first_value("SELECT company FROM orgs WHERE login = ?", [o]) }.compact.uniq
      if companies.size > 1
        cross_company += 1
      else
        same_company += 1
      end
    end
    puts "  Same company (org aliases): #{same_company}"
    puts "  Cross-company: #{cross_company}"

    db.close
  end

  desc "Docker base image dependencies shared across ISC orgs"
  task :docker do
    db = open_query_db

    puts "=== Docker/container base image dependencies ==="
    puts

    docker = db.execute(<<-SQL)
      SELECT d.package_name, COUNT(DISTINCT r.org) as org_count,
             COUNT(DISTINCT d.repo) as repo_count,
             p.downloads, p.dependent_packages_count, p.repository_url
      FROM dependencies d
      JOIN repos r ON r.full_name = d.repo
      LEFT JOIN packages p ON p.ecosystem = d.ecosystem AND p.package_name = d.package_name
      WHERE d.ecosystem = 'docker'
      GROUP BY d.package_name
      ORDER BY org_count DESC, repo_count DESC
    SQL

    if docker.empty?
      puts "No docker dependencies found in the dataset."
    else
      puts "#{docker.size} distinct Docker base images used"
      puts

      puts "Docker images by ISC org usage:"
      docker.each do |name, org_count, repo_count, downloads, dependents, repo_url|
        extra = []
        extra << "#{downloads} pulls" if downloads && downloads > 0
        extra << "#{dependents} dependents" if dependents && dependents > 0
        extra << repo_url if repo_url
        suffix = extra.empty? ? "" : " - #{extra.join(', ')}"
        puts "  #{name}: #{org_count} orgs, #{repo_count} repos#{suffix}"
      end
    end

    db.close
  end

  desc "Industry breakdown: software vs non-software, by industry and size (EXCLUDE=Microsoft)"
  task :industry do
    db = open_query_db

    puts "=== Industry breakdown ==="
    puts

    # Software vs non-software summary
    puts "Software vs non-software:"
    puts
    puts "%-15s %5s %10s %8s %8s %10s %8s" % ["Type", "Orgs", "Maint.", "Active", "Rate", "Contribs", "Per cap."]
    puts "-" * 75

    db.execute(<<-SQL).each do |row|
      SELECT o.type,
             COUNT(DISTINCT o.login) as orgs,
             COUNT(DISTINCT m.login) as maintainers,
             COUNT(DISTINCT ea.login) as active,
             COALESCE(SUM(ea.count), 0) as contributions
      FROM orgs o
      JOIN maintainers m ON m.org = o.login
      LEFT JOIN external_activity ea ON ea.login = m.login
      GROUP BY o.type
      ORDER BY maintainers DESC
    SQL
      type, orgs, maint, active, contribs = row
      rate = (active.to_f / maint * 100).round(1)
      per_cap = (contribs.to_f / maint).round(1)
      puts "%-15s %5d %10d %8d %7.1f%% %10d %8.1f" % [type, orgs, maint, active, rate, contribs, per_cap]
    end

    puts
    puts "By industry:"
    puts
    puts "%-20s %5s %10s %8s %8s %10s %8s" % ["Industry", "Orgs", "Maint.", "Active", "Rate", "Contribs", "Per cap."]
    puts "-" * 80

    db.execute(<<-SQL).each do |row|
      SELECT o.industry,
             COUNT(DISTINCT o.login) as orgs,
             COUNT(DISTINCT m.login) as maintainers,
             COUNT(DISTINCT ea.login) as active,
             COALESCE(SUM(ea.count), 0) as contributions
      FROM orgs o
      JOIN maintainers m ON m.org = o.login
      LEFT JOIN external_activity ea ON ea.login = m.login
      GROUP BY o.industry
      ORDER BY maintainers DESC
    SQL
      industry, orgs, maint, active, contribs = row
      rate = (active.to_f / maint * 100).round(1)
      per_cap = (contribs.to_f / maint).round(1)
      puts "%-20s %5d %10d %8d %7.1f%% %10d %8.1f" % [industry, orgs, maint, active, rate, contribs, per_cap]
    end

    puts
    puts "By size:"
    puts
    puts "%-10s %5s %10s %8s %8s %10s %8s" % ["Size", "Orgs", "Maint.", "Active", "Rate", "Contribs", "Per cap."]
    puts "-" * 65

    sizes = ["huge", "large", "medium", "small"]
    sizes.each do |size|
      row = db.get_first_row(<<-SQL, [size])
        SELECT COUNT(DISTINCT o.login),
               COUNT(DISTINCT m.login),
               COUNT(DISTINCT ea.login),
               COALESCE(SUM(ea.count), 0)
        FROM orgs o
        JOIN maintainers m ON m.org = o.login
        LEFT JOIN external_activity ea ON ea.login = m.login
        WHERE o.size = ?
      SQL
      orgs, maint, active, contribs = row
      rate = maint > 0 ? (active.to_f / maint * 100).round(1) : 0
      per_cap = maint > 0 ? (contribs.to_f / maint).round(1) : 0
      puts "%-10s %5d %10d %8d %7.1f%% %10d %8.1f" % [size, orgs, maint, active, rate, contribs, per_cap]
    end

    # Publishing by type
    puts
    puts "Package publishing by type:"
    puts
    puts "%-15s %8s %8s %8s %12s" % ["Type", "Repos", "Publish", "Rate", "Downloads"]
    puts "-" * 60

    db.execute(<<-SQL).each do |row|
      SELECT o.type,
             COUNT(DISTINCT r.full_name) as repos,
             COUNT(DISTINCT pp.repo) as publishing,
             SUM(pp.downloads) as downloads
      FROM orgs o
      JOIN repos r ON r.org = o.login AND r.fork = 0 AND r.archived = 0
      LEFT JOIN published_packages pp ON pp.repo = r.full_name
      GROUP BY o.type
    SQL
      type, repos, publishing, downloads = row
      rate = (publishing.to_f / repos * 100).round(1)
      puts "%-15s %8d %8d %7.1f%% %12d" % [type, repos, publishing, rate, downloads.to_i]
    end

    db.close
  end
end
