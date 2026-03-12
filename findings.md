Findings from analysing 108 InnerSource Commons member organisations' GitHub activity. Dependency data is still being collected so numbers for dependency-related questions will shift slightly on final run. Bot accounts filtered using pattern matching (`-bot`, `[bot]`, `Bot` suffixes) plus a curated list.

Data sources: GitHub API (repos), ecosyste.ms commits/issues/repos/packages services (contributors, activity, dependencies, package metadata). Maintainers identified by MEMBER/OWNER/COLLABORATOR association on issues, filtering out third-party contributors.

## The dataset

108 ISC member organisations own 23,696 GitHub repos. 14,202 are active (non-fork, non-archived). 76,725 people have maintainer-level access across these orgs.

Microsoft dominates with ~39,700 maintainers across 13 GitHub orgs, roughly half the total. Numbers are presented with and without Microsoft where it matters.

## Q2: Do ISC members publish well-used open source?

26.6% of active repos publish packages (3,776 repos, 14,557 packages). Total downloads: 29.9 billion. Microsoft accounts for 26.3 billion, driven by NuGet test platform packages (1.5 billion each), tslib (1.3 billion npm), and the windows-sys Cargo crate family (769 million).

Without Microsoft: 22.8% of repos publish, 2.2 billion downloads. Top publishers are Stack Overflow (998 million, mostly StackExchange.Redis), Adobe (565 million), Stripe (505 million), Twilio (470 million), and GitHub (428 million).

Some orgs punch above their repo count. CH Robinson has 6 packages with 28 million downloads. Nubank has 24 with 15 million. Philips has 47 with 6.9 million.

## Q3: Do ISC members contribute to external open source?

8,142 maintainers (10.6%) have activity on repos outside their own organisation. 4.9 million contributions to 107,206 external repos.

By participation rate: IBM (40.8%), Comcast (26.7%), Nokia (25.7%), Adobe (23.5%), Sourcegraph (22.8%), Siemens (20.9%). SAP has 317 active but that's only 3.9% of 8,078 total.

By volume: Microsoft (3.4 million), GitHub (658k), IBM (343k), SAP (248k), Adobe (157k), Tencent (154k).

About 90% of maintainers show no external activity. The ones who do are prolific: Guido van Rossum at Microsoft has 169k contributions across 107 external repos.

## Q6: Activity type breakdown

Overall:
- Commits: 4.1 million (84%) by 5,808 people
- Pull requests: 359k (7.4%) by 6,612 people
- Maintaining: 241k (4.9%) by 3,559 people
- Issues: 156k (3.2%) by 6,258 people

More people open issues and PRs than commit, but committers produce far higher volume per person. Maintaining involves the fewest people but high volume each, a core group doing heavy project maintenance.

SAP's profile is unusual: commits (187k), PRs (33k), maintaining (19k), issues (9k). Most other orgs are 70-85% commits. Worth investigating whether this reflects a different workflow.

## Q5: Do ISC members contribute to their own dependencies?

32 of 108 orgs have maintainers contributing back to packages they depend on. 1,877 people contribute to 5,074 dependency packages.

Microsoft leads with 1,170 people contributing 1.5 million times to 3,693 dependencies. Adobe follows with 122 people and 140k contributions to 1,943 dependencies. IBM has 307 people with 74k contributions to 1,503 dependencies. GitHub: 186 people, 42k contributions, 997 dependencies.

After that there's a steep drop. ING Bank (18k contributions), Mercari (4.7k), Intuit (2.9k), Baidu (2.2k). 76 orgs contribute nothing to their dependencies.

The "most contributed-to dependencies" list is dominated by DefinitelyTyped (@types/* packages). Since all @types packages live in one monorepo, every contributor to DefinitelyTyped shows up against every @types package their org depends on. The actual number of distinct upstream projects receiving contributions is lower than the per-package count suggests. Same effect with Parcel (@parcel/*) for Adobe.

## Q7: Shared dependencies

The most widely used dependency: npm/supports-color (38 orgs). Then npm/has-flag and npm/inherits (37 orgs each). After that the usual npm plumbing: ansi-styles, chalk, debug, minimatch, ms, balanced-match (all 36 orgs).

The long tail: 25 packages used by 30+ orgs. 1,049 packages used by exactly 5 orgs. 25,609 packages used by only one org.

npm dominates the dependency graph. The top shared packages by download volume are staggering: ansi-styles (2.2 billion), debug (2.2 billion), minimatch (2 billion), chalk (1.7 billion). These are the plumbing of npm.

## Q8: Dependency vs contribution gap

6,007 shared dependencies (5+ orgs) with known repos. 2,965 (49%) receive some contribution from ISC maintainers. 3,042 (51%) receive none.

That 49% is inflated by monorepo effects. DefinitelyTyped contributions map to hundreds of @types packages. Parcel contributions map to dozens of @parcel packages. The number of distinct upstream projects getting real attention is much smaller.

The gap packages are the headline finding. These are depended on by 35-37 ISC orgs, have hundreds of millions to billions of downloads, and zero contributions:

- npm/chalk: 36 orgs, 1.7 billion downloads, 130k dependents
- npm/ansi-styles: 36 orgs, 2.2 billion downloads
- npm/has-flag: 37 orgs, 1 billion downloads
- npm/find-up: 36 orgs, 845 million downloads
- npm/iconv-lite: 36 orgs, 761 million downloads
- npm/cross-spawn: 35 orgs, 646 million downloads
- npm/braces: 35 orgs, 476 million downloads
- npm/inflight: 35 orgs, 222 million downloads (archived/unmaintained)

Many maintained by a single person (sindresorhus, isaacs, jonschlinkert, micromatch). The ISC collectively depends on them but contributes nothing back.

The Go gap is equally striking: github.com/pkg/errors (99k dependents globally), golang.org/x/crypto (126k dependents), github.com/fsnotify/fsnotify (60k dependents), all with zero ISC contributions.

## Consumption vs contribution CSV

`data/consumption_vs_contribution.csv` contains 4,410 unique dependency repos with columns for depending org count, downloads, dependents, commits/issues/PRs/maintaining from ISC members, and funding links. This is the data behind Ben's chart sketch.

4,410 dependency repos total. 2,821 receive zero ISC contributions. 1,758 (40%) have funding links. Of the zero-contribution repos, 1,132 (40%) have funding links set up, meaning the maintainers are asking for support they're not getting.

## Funding

34% of dependency packages have funding links in their metadata. The breakdown: GitHub Sponsors (3,954), OpenCollective (1,611), Tidelift (367), Patreon (277), others (515+).

The gap packages almost all have funding set up. sindresorhus (has-flag, find-up, chalk ecosystem) has 208 GitHub sponsors. isaacs (once, minimatch, glob) has sponsors. juliangruber (balanced-match, brace-expansion) has GitHub Sponsors and PayPal. ljharb (concat-map, function-bind) has 71 sponsors.

These maintainers have set up funding, ISC members depend on their work, but the contribution flows in neither code nor money from ISC members to these projects.

## What Microsoft does to the numbers

Microsoft is roughly half the dataset by maintainer count and 70% of contribution volume.

- With Microsoft: 10.6% externally active. Without: 11.2%. Microsoft lowers the average.
- With Microsoft: 84% commits. Without: ~59%. Microsoft is heavily commit-weighted.
- With Microsoft: 26.6% of repos publish packages. Without: 22.8%.
- Microsoft: 26.3 billion of 29.9 billion total downloads.
- Microsoft: 1.5 million of 1.8 million dependency contributions (mostly DefinitelyTyped).

## Still to come

- Dependency data collection still running, will sharpen all dependency numbers
- Q1 (activity over time) needs time-series data
- Q4 (staff activity after joining ISC) needs membership timeline data
- Industry/size categorization of orgs
- Cross-ISC contribution network (do members contribute to each other?)
- Bus factor analysis on critical shared dependencies
- License analysis across the dependency graph
