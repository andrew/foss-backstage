require_relative "shared"
require "sqlite3"
require "json"
require "csv"
require "set"

def create_tables(db)
  db.execute_batch <<-SQL
    CREATE TABLE IF NOT EXISTS orgs (
      login TEXT PRIMARY KEY,
      company TEXT
    );

    CREATE TABLE IF NOT EXISTS repos (
      full_name TEXT PRIMARY KEY,
      org TEXT,
      fork BOOLEAN,
      archived BOOLEAN,
      status TEXT
    );

    CREATE TABLE IF NOT EXISTS maintainers (
      login TEXT,
      org TEXT,
      commits INTEGER DEFAULT 0,
      maintainer_activity INTEGER DEFAULT 0,
      PRIMARY KEY (login, org)
    );

    CREATE TABLE IF NOT EXISTS dependencies (
      repo TEXT,
      ecosystem TEXT,
      package_name TEXT,
      requirements TEXT,
      kind TEXT
    );

    CREATE TABLE IF NOT EXISTS external_activity (
      login TEXT,
      repo TEXT,
      source TEXT,
      count INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS external_repos (
      full_name TEXT PRIMARY KEY,
      owner TEXT,
      description TEXT,
      stars INTEGER DEFAULT 0,
      language TEXT,
      license TEXT,
      archived BOOLEAN,
      fork BOOLEAN,
      topics TEXT
    );

    CREATE TABLE IF NOT EXISTS owners (
      login TEXT PRIMARY KEY,
      name TEXT,
      kind TEXT,
      company TEXT,
      description TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_repos_org ON repos(org);
    CREATE INDEX IF NOT EXISTS idx_maintainers_login ON maintainers(login);
    CREATE INDEX IF NOT EXISTS idx_maintainers_org ON maintainers(org);
    CREATE INDEX IF NOT EXISTS idx_dependencies_repo ON dependencies(repo);
    CREATE INDEX IF NOT EXISTS idx_dependencies_package ON dependencies(ecosystem, package_name);
    CREATE INDEX IF NOT EXISTS idx_external_activity_login ON external_activity(login);
    CREATE INDEX IF NOT EXISTS idx_external_activity_repo ON external_activity(repo);
    CREATE INDEX IF NOT EXISTS idx_external_repos_owner ON external_repos(owner);
  SQL
end

def load_org_aliases
  company_orgs = {}
  CSV.read("innersource_github_profiles.csv", headers: true).each do |row|
    company = row["Organisation"]
    org = row["GitHub Profile"].split("/").last
    company_orgs[org.downcase] = company
  end
  if File.exist?("org_aliases.csv")
    CSV.read("org_aliases.csv", headers: true).each do |row|
      company = row["Organisation"]
      org = row["GitHub Profile"].split("/").last
      company_orgs[org.downcase] = company
    end
  end
  company_orgs
end

def all_org_logins_for(login, company_orgs)
  company = company_orgs[login.downcase]
  return Set[login.downcase] unless company
  company_orgs.select { |_, c| c == company }.keys.to_set
end

namespace :db do
  desc "Build SQLite database from collected data"
  task :build do
    File.delete(DB_PATH) if File.exist?(DB_PATH)
    db = SQLite3::Database.new(DB_PATH)
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA synchronous=NORMAL")
    create_tables(db)

    company_orgs = load_org_aliases

    # Orgs
    puts "Loading orgs..."
    CSV.read("innersource_github_profiles.csv", headers: true).each do |row|
      login = row["GitHub Profile"].split("/").last
      db.execute("INSERT OR IGNORE INTO orgs (login, company) VALUES (?, ?)", [login, row["Organisation"]])
    end

    # Repos
    puts "Loading repos..."
    Dir.glob("data/repos/*.json").each do |file|
      org = File.basename(file, ".json")
      repos = JSON.parse(File.read(file))
      repos.each do |r|
        db.execute("INSERT OR IGNORE INTO repos VALUES (?, ?, ?, ?, ?)",
          [r["full_name"], org, r["fork"] ? 1 : 0, r["archived"] ? 1 : 0, r["status"]])
      end
    end

    # Maintainers
    puts "Loading maintainers..."
    Dir.glob("data/contributors/*.json").each do |file|
      org = File.basename(file, ".json")
      contributors = JSON.parse(File.read(file))
      contributors.each do |c|
        next unless c["login"]
        db.execute("INSERT OR IGNORE INTO maintainers VALUES (?, ?, ?, ?)",
          [c["login"], org, c["commits"], c["maintainer_activity"]])
      end
    end

    # Dependencies
    puts "Loading dependencies..."
    db.transaction do
      Dir.glob("data/dependencies/**/*.json").each do |file|
        repo = file.sub("data/dependencies/", "").sub(".json", "")
        manifests = JSON.parse(File.read(file))
        manifests.each do |m|
          (m["dependencies"] || []).each do |dep|
            db.execute("INSERT INTO dependencies VALUES (?, ?, ?, ?, ?)",
              [repo, dep["ecosystem"], dep["package_name"], dep["requirements"], dep["kind"]])
          end
        end
      end
    end

    # External activity
    puts "Loading external activity..."
    db.transaction do
      Dir.glob("data/activity/*.json").each do |file|
        data = JSON.parse(File.read(file))
        login = data["login"]
        next unless login

        org_logins = Set.new
        # Find which orgs this person belongs to
        db.execute("SELECT org FROM maintainers WHERE login = ?", [login]).each do |row|
          all_org_logins_for(row[0], company_orgs).each { |o| org_logins << o }
        end

        external = ->(repo_name) {
          owner = repo_name.split("/").first.downcase
          owner != login.downcase && !org_logins.include?(owner)
        }

        (data.dig("commits", "repositories") || []).each do |r|
          next unless external.call(r["full_name"])
          db.execute("INSERT INTO external_activity VALUES (?, ?, ?, ?)",
            [login, r["full_name"], "commits", r["commit_count"]])
        end

        (data.dig("issues", "issue_repos") || []).each do |r|
          next unless external.call(r["repository"])
          db.execute("INSERT INTO external_activity VALUES (?, ?, ?, ?)",
            [login, r["repository"], "issues", r["count"]])
        end

        (data.dig("issues", "pull_request_repos") || []).each do |r|
          next unless external.call(r["repository"])
          db.execute("INSERT INTO external_activity VALUES (?, ?, ?, ?)",
            [login, r["repository"], "pull_requests", r["count"]])
        end

        (data.dig("issues", "maintaining") || []).each do |r|
          next unless external.call(r["repository"])
          db.execute("INSERT INTO external_activity VALUES (?, ?, ?, ?)",
            [login, r["repository"], "maintaining", r["count"]])
        end
      end
    end

    # External repos
    puts "Loading external repos..."
    db.transaction do
      Dir.glob("data/external_repos/**/*.json").each do |file|
        data = JSON.parse(File.read(file))
        next if data["error"]
        db.execute("INSERT OR IGNORE INTO external_repos VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
          [data["full_name"], data["owner"], data["description"],
           data["stargazers_count"], data["language"], data["license"],
           data["archived"] ? 1 : 0, data["fork"] ? 1 : 0,
           (data["topics"] || []).join(",")])
      end
    end

    # Owners
    puts "Loading owners..."
    Dir.glob("data/owners/*.json").each do |file|
      data = JSON.parse(File.read(file))
      next if data["error"]
      db.execute("INSERT OR IGNORE INTO owners VALUES (?, ?, ?, ?, ?)",
        [data["login"], data["name"], data["kind"], data["company"], data["description"]])
    end

    db.close

    # Print stats
    db = SQLite3::Database.new(DB_PATH)
    puts
    puts "Database built: #{DB_PATH}"
    puts "  orgs: #{db.get_first_value("SELECT COUNT(*) FROM orgs")}"
    puts "  repos: #{db.get_first_value("SELECT COUNT(*) FROM repos")}"
    puts "  maintainers: #{db.get_first_value("SELECT COUNT(DISTINCT login) FROM maintainers")}"
    puts "  dependencies: #{db.get_first_value("SELECT COUNT(*) FROM dependencies")}"
    puts "  external_activity: #{db.get_first_value("SELECT COUNT(*) FROM external_activity")}"
    puts "  external_repos: #{db.get_first_value("SELECT COUNT(*) FROM external_repos")}"
    puts "  owners: #{db.get_first_value("SELECT COUNT(*) FROM owners")}"
    db.close
  end
end
