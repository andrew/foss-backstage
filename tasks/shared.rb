require "json"
require "faraday"
require "faraday/retry"
require "fileutils"

ECOSYSTEMS_HOST = "GitHub"
COMMITS_API = "https://commits.ecosyste.ms/api/v1/"
ISSUES_API = "https://issues.ecosyste.ms/api/v1/"
USER_AGENT = "foss-backstage/1.0 (andrew@nesbitt.io)"
REPOS_API = "https://repos.ecosyste.ms/api/v1/"

def ecosystems_client(base_url)
  Faraday.new(url: base_url) do |f|
    f.headers["User-Agent"] = USER_AGENT
    f.headers["Accept"] = "application/json"
    f.request :retry, max: 3, interval: 1, backoff_factor: 2,
      retry_statuses: [429, 500, 502, 503],
      retry_block: -> (env, *) {
        headers = env.is_a?(Hash) ? env[:response_headers] : env.response_headers
        reset = headers && headers["x-ratelimit-reset"]
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
rescue JSON::ParserError
  puts " JSON error (#{base_url}#{path})"
  nil
end

def api_ping(base_url, full_name)
  client = ecosystems_client(base_url)
  response = client.get("hosts/#{ECOSYSTEMS_HOST}/repositories/#{full_name}/ping", priority: true)
  response.status
rescue Faraday::Error => e
  puts " error: #{e.message}"
  nil
end
