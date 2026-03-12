Findings from analysing 108 InnerSource Commons member organisations' GitHub activity. Bot accounts filtered using pattern matching (`-bot`, `[bot]`, `Bot` suffixes) plus a curated list.

Data sources: GitHub API (repos), ecosyste.ms commits/issues/repos/packages services (contributors, activity, dependencies, package metadata). Maintainers identified by MEMBER/OWNER/COLLABORATOR association on issues, filtering out third-party contributors.

## The dataset

108 ISC member organisations own 23,696 GitHub repos. 14,202 are active (non-fork, non-archived). 76,724 people have maintainer-level access across these orgs.

45 orgs are software companies, 63 are non-software (banking, retail, automotive, etc.). By size: 32 huge (100k+ employees), 40 large (10k-100k), 27 medium (1k-10k), 9 small (<1k).

Microsoft dominates with ~39,700 maintainers across 13 GitHub orgs, roughly half the total. Numbers are presented with and without Microsoft where it matters.

## Q2: Do ISC members publish well-used open source?

26.6% of active repos publish packages (3,776 repos, 14,557 packages). Total downloads: 29.9 billion. Microsoft accounts for 26.3 billion, driven by NuGet test platform packages (1.5 billion each), tslib (1.3 billion npm), and the windows-sys Cargo crate family (769 million).

Without Microsoft: 35.3% of software company repos publish packages vs 23.9% of non-software company repos. Top publishers after Microsoft are Stack Overflow (998 million, mostly StackExchange.Redis), Adobe (565 million), Stripe (505 million), Twilio (470 million), and GitHub (428 million).

Some orgs punch above their repo count. CH Robinson has 6 packages with 28 million downloads. Nubank has 24 with 15 million. Philips has 47 with 6.9 million.

## Q3: Do ISC members contribute to external open source?

8,142 maintainers (10.6%) have activity on repos outside their own organisation. 4.9 million contributions to 107,206 external repos.

By participation rate: IBM (40.8%), Comcast (26.7%), Nokia (25.7%), Adobe (23.5%), Sourcegraph (22.8%), Siemens (21.0%). SAP has 317 active but that's only 3.9% of 8,078 total.

By volume: Microsoft (3.4 million), GitHub (658k), IBM (343k), SAP (248k), Adobe (157k), Tencent (154k).

About 90% of maintainers show no external activity. The ones who do are prolific.

## Q6: Activity type breakdown

Overall:
- Commits: 4.1 million (84%) by 5,808 people
- Pull requests: 359k (7.4%) by 6,612 people
- Maintaining: 241k (4.9%) by 3,559 people
- Issues: 156k (3.2%) by 6,258 people

More people open issues and PRs than commit, but committers produce far higher volume per person. Maintaining involves the fewest people but high volume each, a core group doing heavy project maintenance.

## Q5: Do ISC members contribute to their own dependencies?

32 of 108 orgs have maintainers contributing back to packages they depend on. 2,148 people contribute to 5,937 dependency packages.

Microsoft leads with 1,341 people contributing 1.6 million times to 4,338 dependencies. Adobe follows with 122 people and 140k contributions to 1,943 dependencies. IBM has 371 people with 82k contributions to 1,724 dependencies. GitHub: 218 people, 50k contributions, 1,081 dependencies.

After that there's a steep drop. ING Bank (18k contributions), Mercari (4.8k), Intuit (2.9k), Baidu (2.2k). 76 orgs contribute nothing to their dependencies.

The "most contributed-to dependencies" list is dominated by DefinitelyTyped (@types/* packages). Since all @types packages live in one monorepo, every contributor to DefinitelyTyped shows up against every @types package their org depends on. The actual number of distinct upstream projects receiving contributions is lower than the per-package count suggests. Same effect with Parcel (@parcel/*) for Adobe.

## Q7: Shared dependencies

The most widely used dependency: actions/checkout (38 orgs). Then npm/inherits, npm/semver, npm/supports-color, and npm/has-flag (37 orgs each). After that the usual npm plumbing: debug, chalk, once, ms, minimatch, balanced-match (all 36 orgs).

npm dominates the dependency graph. The top shared packages by download volume: semver (2.5 billion), ansi-styles (2.2 billion), debug (2.2 billion), minimatch (2 billion), chalk (1.7 billion), strip-ansi (1.8 billion). These are the plumbing of npm.

## Q8: Dependency vs contribution gap

6,075 shared dependencies (5+ orgs) with known repos. 2,998 (49%) receive some contribution from ISC maintainers. 3,077 (51%) receive none.

That 49% is inflated by monorepo effects. DefinitelyTyped contributions map to hundreds of @types packages. Parcel contributions map to dozens of @parcel packages. The number of distinct upstream projects getting real attention is much smaller.

The gap packages are the headline finding. These are depended on by 35-37 ISC orgs, have hundreds of millions to billions of downloads, and zero contributions:

- npm/has-flag: 37 orgs, 1 billion downloads
- npm/inherits: 37 orgs, 553 million downloads
- npm/ansi-styles: 36 orgs, 2.2 billion downloads
- npm/chalk: 36 orgs, 1.7 billion downloads, 130k dependents
- npm/find-up: 36 orgs, 845 million downloads
- npm/iconv-lite: 36 orgs, 761 million downloads
- npm/once: 36 orgs, 407 million downloads
- npm/cross-spawn: 35 orgs, 646 million downloads
- npm/braces: 35 orgs, 476 million downloads
- npm/inflight: 35 orgs, 222 million downloads (archived/unmaintained)

Many maintained by a single person (sindresorhus, isaacs, jonschlinkert, micromatch). The ISC collectively depends on them but contributes nothing back.

## Funding

35% of dependency packages have funding links in their metadata. The breakdown: GitHub Sponsors (5,290), OpenCollective (2,316), Tidelift (586), Patreon (341), others (3,599).

Packages with funding links are slightly more likely to receive ISC contributions (47.4%) than those without (39.5%). But unfunded packages receive far more total contribution volume (2.1 million vs 250k), likely because the biggest projects (React, TypeScript, Kubernetes) don't need tip jars.

The gap packages almost all have funding set up. sindresorhus (has-flag, find-up, chalk ecosystem) has 208 GitHub sponsors. isaacs (once, minimatch, glob) has sponsors. juliangruber (balanced-match, brace-expansion) has GitHub Sponsors and PayPal. ljharb (concat-map, function-bind) has 71 sponsors.

These maintainers have set up funding, ISC members depend on their work, but the contribution flows in neither code nor money from ISC members to these projects.

## Abandoned dependencies

372 archived dependency packages are still in active use by ISC orgs. The worst cases: @humanwhocodes/config-array (29 orgs), q (29 orgs), loader-utils (27 orgs, 224 million downloads), npmlog (24 orgs), memory-fs (24 orgs).

Go has its own set of zombies: gopkg.in/yaml.v2 and v3 (23 and 20 orgs, 90k dependents each), github.com/golang/mock (21 orgs), github.com/json-iterator/go (20 orgs, 49k dependents). These packages have successors but migration hasn't happened.

## Ecosystem gaps

Contribution rates vary by language ecosystem. Packagist (PHP) has the worst gap at 84.6% of dependencies receiving no ISC contributions, followed by Bower (74.3%), Hex (Elixir, 73.5%), CocoaPods (71.7%). Go is at 65.1%, npm at 58.1%. GitHub Actions has the smallest gap at 49.4%, and Docker and Maven effectively show 0% gap (though Maven has no repo URL mappings).

## Cross-ISC contributions

705 people from 52 ISC orgs contribute to 444 repos at 44 other ISC orgs. 82,281 total cross-ISC contributions.

Microsoft is the largest source (71.6k contributions to 31 ISC orgs by 360 people), followed by GitHub (7k) and Baidu (1.3k). On the receiving end, Sourcegraph dominates with 77.5k contributions from 24 ISC orgs -- the Microsoft-to-Sourcegraph flow alone is 70k contributions by 112 people. Microsoft itself receives contributions from 43 ISC orgs (2.6k contributions from 210 people).

Beyond the Microsoft/Sourcegraph outlier, the cross-ISC network is thin. Most org-to-org flows are under 100 contributions.

## Maintainer overlap

3,029 maintainers appear in multiple ISC orgs, all cross-company. Most (2,760) span exactly 2 orgs, but some span many more. The top multi-org accounts include prolific cross-project contributors like eltociear (13 orgs, 8.2k external contributions) and serial typo-fixers/documentation contributors who make small PRs across many organisations.

## License analysis

MIT dominates shared dependencies (4,635 packages), followed by Apache 2.0 (1,537). Only three copyleft dependencies are used by 3+ ISC orgs: hashicorp/hcl (MPL, 21 orgs), axe-core (MPL, 18 orgs), go-sql-driver/mysql (MPL, 15 orgs). GPL/AGPL dependencies are rare in the shared set.

## Industry breakdown

Non-software companies have a higher external participation rate (16.6%) than software companies (10.2%), though software companies contribute more in absolute volume. This is partly because software companies have far more maintainers per org, diluting the percentage.

By industry, manufacturing stands out: 24.5% participation rate and 190.8 contributions per capita, driven largely by Siemens. Healthcare (Philips) shows 31.5% participation. Banking is low at 15.7% participation and 30.4 per capita.

Small companies (<1k employees) have the highest per-capita contribution rate at 175.6 contributions per maintainer, though this reflects a few highly active small orgs like Sourcegraph (461 per capita) and Etsy (197 per capita). Huge companies (100k+) contribute 78.7 per capita with Microsoft, 58.1 without.

## Docker base images

603 distinct Docker base images are used across ISC orgs. The most common: node (19 orgs), ubuntu (17), alpine (17), golang (16), python (15). All official images point to docker-library/official-images as their upstream. nginx, postgres, and redis each appear in 5-9 orgs.

## What Microsoft does to the numbers

Microsoft is roughly half the dataset by maintainer count and 70% of contribution volume.

- With Microsoft: 10.6% externally active. Without: 11.2%. Microsoft lowers the average.
- With Microsoft: 84% commits. Without: ~59%. Microsoft is heavily commit-weighted.
- With Microsoft: 26.6% of repos publish packages. Without: 22.8%.
- Microsoft: 26.3 billion of 29.9 billion total downloads.
- Microsoft: 1.6 million of 1.9 million dependency contributions (mostly DefinitelyTyped).

## Still to come

- Q1 (activity over time) needs time-series data
- Q4 (staff activity after joining ISC) needs membership timeline data
- Bus factor analysis on critical shared dependencies
