require "json"

namespace :repos do
  desc "Summarize collected repo data"
  task :summary do
    dir = "data/repos"
    totals = { orgs: 0, repos: 0, forks: 0, archived: 0, active: 0 }

    Dir.glob(File.join(dir, "*.json")).sort.each do |file|
      org = File.basename(file, ".json")
      repos = JSON.parse(File.read(file))
      forks = repos.count { |r| r["fork"] }
      archived = repos.count { |r| r["archived"] }
      active = repos.count { |r| r["status"] == "active" && !r["fork"] }

      puts "#{org}: #{repos.size} repos (#{active} active, #{forks} forks, #{archived} archived)"

      totals[:orgs] += 1
      totals[:repos] += repos.size
      totals[:forks] += forks
      totals[:archived] += archived
      totals[:active] += active
    end

    puts
    puts "Total: #{totals[:orgs]} orgs, #{totals[:repos]} repos (#{totals[:active]} active, #{totals[:forks]} forks, #{totals[:archived]} archived)"
  end
end
