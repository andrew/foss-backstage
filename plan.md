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

1. Write `rake db:build` to load flat files into SQLite
2. Write query tasks against the database for Q3, Q5, Q6, Q7, Q8
3. Collect package/usage data from repos.ecosyste.ms for Q2
4. Collect funding data for Q9
5. Figure out timeline approach for Q1
