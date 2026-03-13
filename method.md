We started with a CSV of 108 InnerSource Commons member organisations and their GitHub logins. Some organisations have multiple GitHub orgs (Microsoft has 13, for example). We manually classified each organisation as software or non-software, assigned an industry, and estimated employee count to create size tiers.

All data collection used ecosyste.ms APIs rather than the GitHub API directly. GitHub's API doesn't expose dependency graphs, dependent counts, or package registry metadata at all, so ecosyste.ms was the only practical way to get this data. It also pre-indexes and caches data from GitHub, package registries, and commit history, which meant we could query across 23,696 repos without worrying about GitHub rate limits.

The pipeline has six stages, each implemented as a Rake task that writes JSON files to a `data/` directory.

**Stage 1: Repos.** For each GitHub org, we fetched the full list of public repositories from repos.ecosyste.ms. This gave us 23,696 repos, of which 14,202 are active (non-fork, non-archived).

**Stage 2: Contributors.** We pinged commits.ecosyste.ms and issues.ecosyste.ms to trigger indexing of each org's active repos, then fetched contributor data. Contributors are people with MEMBER, OWNER, or COLLABORATOR association on issues in the org's repos, which filters out drive-by contributors and gives us the people who actually maintain these projects. 76,724 maintainers across all orgs.

Bot accounts were filtered using pattern matching (`-bot`, `[bot]`, `Bot` suffixes) plus a curated list of known bots like Dependabot, Renovate, and Copilot.

**Stage 3: External activity.** For each maintainer, we fetched their commit and issue activity from commits.ecosyste.ms and issues.ecosyste.ms. We then filtered to only activity on repos outside their own organisation (including org aliases, so Microsoft contributors to Azure repos don't count as external). This produced the external contribution dataset: who contributes where, how much, and what kind of activity (commits, PRs, issues, maintaining).

**Stage 4: Dependencies.** We fetched dependency manifests from repos.ecosyste.ms for every active repo. This parses package manager files (package.json, go.mod, Gemfile, pom.xml, etc.) and returns structured dependency lists. 2.6 million dependency records across all repos.

**Stage 5: Package metadata.** For each dependency, we looked up package metadata from packages.ecosyste.ms. Raw dependency names were parsed using the purl (Package URL) library to strip version numbers and deduplicate. A dependency like `csstype@3.1.0` and `csstype@2.6.20` both resolve to the same package. This reduced around 60,000 raw entries to 51,000 unique packages.

The package metadata includes download counts, dependent package counts, repository URLs, funding links, and the list of people with publish access to the registry. We also fetched published packages for each org's repos to see what ISC members produce, not just what they consume.

**Stage 6: Bus factor.** For shared dependencies used by 5 or more ISC orgs, we fetched commit statistics from commits.ecosyste.ms. This gives total committers, past-year committers, total commits, and DDS (Developer Distribution Score, a measure of how concentrated commit authorship is). Combined with the package maintainer count from stage 5, this lets us identify packages with single points of failure.

All six stages write flat JSON files. In total the pipeline made around 358,000 HTTP requests to ecosyste.ms APIs, producing 8.6 GB of cached JSON across the `data/` directory. The biggest chunks are package metadata (4.5 GB, 62,000 files), external repo lookups (1 GB, 179,000 files), and owner metadata (215 MB, 55,000 files).

A build step loads everything into a SQLite database (448 MB) with indexes for efficient querying. The database holds 108 orgs, 23,696 repos, 76,724 maintainers, 2.6 million dependency records, 236,000 external activity records, 162,000 external repos, 49,000 packages, and 14,557 published packages. The query tasks run SQL against this database to produce the findings.

The whole pipeline is idempotent. Each fetch task skips files that already exist, so you can re-run after adding new orgs or if a fetch gets interrupted. Rebuilding the database from the JSON files takes about 30 seconds.

Data sources and what we used them for:

- repos.ecosyste.ms: repository lists, dependency manifests, external repo metadata, owner information
- commits.ecosyste.ms: contributor lists (who maintains each repo), commit statistics and DDS for bus factor analysis
- issues.ecosyste.ms: issue and PR activity, maintainer identification via association filtering
- packages.ecosyste.ms: package metadata, download counts, funding links, registry maintainer lists, published packages by repo
- GitHub Innovation Graph: platform-wide growth statistics (developers, repos, pushes, orgs) from Q1 2020 to Q3 2025
