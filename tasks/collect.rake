desc "Fetch repos then ping ecosyste.ms to start indexing (LIMIT=n to restrict orgs)"
task :collect => ["repos:fetch", "contributors:ping"]
