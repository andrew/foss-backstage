We have raw data collected across several stages. Now we need to aggregate it into a SQLite database so we can query across datasets to answer the talk's questions.

## Data we have

- `data/repos/` - repos per org from GitHub API
- `data/contributors/` - maintainers per org from commits + issues ecosyste.ms
- `data/activity/` - per-maintainer external activity (commit repos, issue repos, PR repos, maintaining)
- `data/owners/` - external org metadata from repos.ecosyste.ms
- `data/external_repos/` - repo metadata for repos maintainers contribute to
- `data/dependencies/` - dependency manifests for org repos
- `org_aliases.csv` - mapping of companies to additional GitHub orgs

## Aggregation database

A `rake db:build` task that loads all flat files into SQLite tables:

- `orgs` (login, company, repo_count)
- `repos` (full_name, org, fork, archived, status)
- `maintainers` (login, org, commits, maintainer_activity)
- `dependencies` (repo, ecosystem, package_name)
- `external_activity` (maintainer_login, repo_full_name, source: commits/issues/prs/maintaining, count)
- `external_repos` (full_name, owner, stars, language, license, archived)
- `owners` (login, name, kind, company)

## Queries we can then write

**Q2: Do ISC members publish well-used open source?**
Join org repos with packages.ecosyste.ms data (dependents, downloads). We don't have this yet but repos.ecosyste.ms has a `usage` endpoint that maps repos to packages.

**Q3: Do ISC members contribute to open source?**
Count external_activity rows per org, excluding own orgs (using org_aliases). Already partly answered by activity:summary.

**Q5: Do ISC members contribute to their own dependencies?**
Join dependencies with external_activity. For each org, find packages they depend on, then check if their maintainers have activity on those package repos.

**Q6: Activity type breakdown**
Group external_activity by source (commits, issues, PRs, maintaining) per org.

**Q7: Critical shared dependencies**
Count dependencies shared across multiple orgs. We already see npm:debug in 1855 repos. Filter to packages used by N+ different ISC orgs.

**Q8: Contribution vs dependency overlap**
For shared dependencies from Q7, check external_activity to see which ones ISC maintainers actually contribute to. The gap between "we depend on this" and "we contribute to this" is the interesting finding.

**Q8.2: Health of dependencies**
repos.ecosyste.ms has scorecard data. We could pull that for the top shared dependencies.

## Data gaps

- **Q1 (activity over time):** Need time-series data. The issues service has `past_year_` prefixed fields but not full history. Could use the timeline service or query issues with date ranges.
- **Q2 (dependents/downloads):** Need packages.ecosyste.ms data. The repos usage endpoint can map repos to packages.
- **Q4 (staff after switching):** Need ISC membership join dates per org. Not clear where this comes from.
- **Q9 (funding):** repos.ecosyste.ms has funding_links on repos. The funds service tracks funding sources. Neither collected yet.

## Next steps

1. ~~Write `rake db:build` to load flat files into SQLite~~
2. ~~Write query tasks against the database for Q3, Q5, Q6, Q7, Q8~~
3. ~~Collect package/usage data from packages.ecosyste.ms for Q2~~
4. ~~Collect funding data from package metadata funding_links~~
5. Figure out timeline approach for Q1
6. Rebuild db and refresh findings once all package data finishes downloading

## Further ideas

- **Cross-ISC contribution:** Do ISC members contribute to each other's repos? We have the data to check this already. Could show a network graph of which orgs contribute to which other ISC orgs.
- **License analysis:** We have license data on external_repos. What licenses do ISC members depend on vs what licenses they publish under? Any copyleft dependencies in permissive-licensed projects?
- **Abandoned dependencies:** Cross-reference shared dependencies with their repo's last commit date or archived status. How many orgs depend on something that hasn't been touched in years?
- **Bus factor on critical packages:** For the top shared deps, how many active maintainers does the upstream repo have? Single-maintainer packages that 30 orgs depend on are a supply chain risk.
- **Scorecard data:** repos.ecosyste.ms has OpenSSF Scorecard scores. Pull those for the top shared dependencies to assess security posture.
- **Org size vs contribution rate:** Categorize orgs by repo count or maintainer count, then see if larger orgs contribute more or less per capita. IBM has 40% external participation with 2,600 maintainers, SAP has 4% with 8,000. Is that a pattern?
- **Language ecosystem gaps:** The dependency data is heavily npm-skewed. Are Go, Python, or Ruby dependencies better or worse served by ISC contributions? Different ecosystems may have different contribution cultures.
- **Funding vs contribution:** For packages that have funding links, are they more or less likely to also receive code contributions from ISC members? Does money substitute for code or do they correlate?
- **Industry clustering:** Tag the 108 orgs by industry (finance, tech, retail, etc.) and see if certain industries contribute more. Do banks contribute differently than tech companies?
- **Time-series from ecosyste.ms:** The issues service has `past_year_` fields. Could plot year-over-year trends for at least recent history. The timeline service at timeline.ecosyste.ms may have more granular data.
- **Maintainer overlap:** Which people are maintainers at multiple ISC orgs? Could indicate job-hopping patterns or consultants. The multi-org maintainers might be the most valuable contributors.
- **Docker base image dependencies:** Docker images (node, python, alpine, ubuntu) show up as dependencies used by 10-15 orgs. Worth calling out separately since they're a different kind of supply chain from library packages.
- **ISC members sponsoring each other:** If we pull GitHub Sponsors data for ISC org accounts, are any of them sponsoring the maintainers they depend on?
