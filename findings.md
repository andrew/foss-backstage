Findings from analysing 108 InnerSource Commons member organisations' GitHub activity. Package data is about 60% collected (13,274 of ~22k dependency packages resolved). Bot accounts have been filtered out using pattern matching (`-bot`, `[bot]`, `Bot` suffixes) plus a curated list.

Data sources: GitHub API (repos), ecosyste.ms commits/issues/repos/packages services (contributors, activity, dependencies, package metadata). Maintainers are identified by MEMBER/OWNER/COLLABORATOR association on issues, filtering out third-party contributors.

## The dataset

108 ISC member organisations own 23,696 GitHub repos. Of those, 14,202 are active (non-fork, non-archived). 76,725 people have maintainer-level access across these orgs after filtering bots.

Microsoft dominates the dataset with ~39,700 maintainers across 13 GitHub orgs, roughly half the total. Numbers are presented both with and without Microsoft where the difference matters.

## Q2: Do ISC members publish well-used open source?

26.6% of active repos publish packages (3,776 repos producing 14,557 packages). Total downloads: 29.9 billion. Microsoft accounts for 26.3 billion of that, driven by NuGet test platform packages (1.5 billion each), tslib (1.3 billion npm downloads), and the windows-sys Cargo crate family (769 million).

Without Microsoft: 22.8% of repos publish packages, with 2.2 billion total downloads. The top publishers are Stack Overflow (998 million, mostly StackExchange.Redis), Adobe (565 million), Stripe (505 million), Twilio (470 million), and GitHub (428 million).

Some orgs punch well above their repo count. CH Robinson has only 6 packages but 28 million downloads. Nubank has 24 packages with 15 million downloads. Philips has 47 packages with 6.9 million.

## Q3: Do ISC members contribute to external open source?

8,142 maintainers (10.6%) have activity on repos outside their own organisation. They've made 4.9 million contributions to 107,206 external repos.

By percentage of maintainers active externally, the standouts are IBM (40.8%), Comcast (26.7%), Nokia (25.7%), Adobe (23.5%), Sourcegraph (22.8%), and Siemens (20.9%). SAP has 317 externally-active maintainers but that's only 3.9% of their 8,078 total.

By raw contribution volume: Microsoft (3.4 million), GitHub (658k), IBM (343k), SAP (248k), Adobe (157k), Tencent (154k). There's a long tail after that, with Sourcegraph at 117k and Siemens at 81k.

Roughly 90% of maintainers across ISC orgs show no external open source activity at all. The ones who do contribute are prolific: the top individual (Guido van Rossum at Microsoft) has 169k contributions across 107 external repos, mostly CPython work.

## Q6: Activity type breakdown

Across all orgs:
- Commits: 4.1 million (84%) by 5,808 people
- Pull requests: 359k (7.4%) by 6,612 people
- Maintaining: 241k (4.9%) by 3,559 people
- Issues: 156k (3.2%) by 6,258 people

More people open issues and PRs than make direct commits, but committers produce far higher volume per person. The "maintaining" category (review, triage, merge activity) involves the fewest people but high volume per person, a core group doing heavy project maintenance.

SAP's profile is unusual. Where most orgs are 70-85% commits, SAP's external activity is more evenly spread: commits (186k), PRs (33k), maintaining (19k), issues (9k). Worth investigating whether this reflects a different workflow or tooling.

## Q5: Do ISC members contribute to their own dependencies?

Of 108 orgs, only 22 have any maintainers contributing back to packages they depend on. 487 people across those orgs contribute to 2,743 dependency packages.

Adobe leads with 101 people contributing 134k times to 1,674 dependencies. IBM follows with 148 people and 48k contributions to 916 dependencies. GitHub has 128 people contributing 32k times to 796 dependencies.

After that there's a steep drop: Baidu (1,472 contributions), Bloomberg (963), Disney (920), DiDi (887), Comcast (837). 86 orgs contribute nothing to their dependencies at all.

A quirk in the data: many of Adobe's contributions are to Parcel packages (all from the same monorepo), and Microsoft's DefinitelyTyped contributions show up across all @types/* packages. The contribution count per unique upstream project is lower than the per-package numbers suggest.

## Q7: Shared dependencies

The most widely-used dependency across ISC orgs is actions/checkout (32 orgs, 813 repos). Then the usual npm ecosystem: inherits (31 orgs), supports-color (31), semver (31), has-flag (31), debug (30 orgs with 2.2 billion downloads), chalk (30 orgs, 1.7 billion downloads).

The distribution follows a long tail. 25 packages are used by 30+ orgs. 558 packages are used by exactly 5 orgs. 14,932 packages are used by only one org.

npm dominates the dependency graph with 502k entries, followed by Go (20k), Maven (7k), PyPI (6k), GitHub Actions (4k), and RubyGems (4k).

The top shared packages by download volume are staggering. ansi-styles has 2.2 billion downloads and 30 ISC orgs depend on it. debug has 2.2 billion. minimatch has 2 billion. These are the plumbing of the npm ecosystem and they show up everywhere.

## Q8: Dependency vs contribution gap

Of 3,209 shared dependencies (used by 5+ orgs) with known GitHub repos, 1,722 (54%) receive at least some contribution from ISC maintainers. 1,487 (46%) receive none at all.

That 54% is inflated by monorepo effects. Microsoft maintainers contribute to DefinitelyTyped, which maps to hundreds of @types/* packages. Adobe contributes to Parcel, mapping to dozens of @parcel/* packages. The number of distinct upstream projects receiving contributions is smaller than it looks.

The gap packages are the headline finding. These are packages that 29-31 ISC orgs depend on, with hundreds of millions of downloads, and zero contributions from any ISC maintainer:

- npm/chalk: 30 orgs depend, 1.7 billion downloads, 130k dependents
- npm/ansi-styles: 30 orgs depend, 2.2 billion downloads
- npm/has-flag: 31 orgs depend, 1 billion downloads
- npm/find-up: 30 orgs depend, 845 million downloads
- npm/cross-spawn: 29 orgs depend, 646 million downloads
- npm/braces: 29 orgs depend, 476 million downloads
- npm/inflight: 29 orgs depend, 222 million downloads (archived/unmaintained)

Many of these are maintained by a single person (sindresorhus, isaacs, jonschlinkert, micromatch). The ISC collectively depends on them but doesn't contribute code, issues, or even triage help.

The Go gap is equally striking. github.com/pkg/errors (17 orgs, 99k dependents globally), golang.org/x/crypto (18 orgs, 126k dependents), github.com/fsnotify/fsnotify (16 orgs, 60k dependents) all receive no ISC contributions.

## What Microsoft does to the numbers

Microsoft is roughly half the dataset by maintainer count and 70% of the contribution volume. Some specific effects:

- With Microsoft: 10.6% of maintainers active externally. Without: 11.2%. Microsoft's huge org actually lowers the average.
- With Microsoft: 84% of contributions are commits. Without: roughly 59%. Microsoft's profile is heavily commit-weighted.
- With Microsoft: 26.6% of repos publish packages. Without: 22.8%.
- Microsoft contributes 26.3 billion of 29.9 billion total package downloads.

The story changes depending on whether you're asking "what does the ISC collectively do" vs "what does a typical ISC member do." Microsoft is an outlier in every dimension, and including all their orgs (Azure, dotnet, NuGet, PowerShell, etc.) makes them even more dominant.

## Still to come

- Package data collection still running (~60% complete), will sharpen Q5/Q7/Q8 numbers
- Q1 (activity over time) needs time-series data from ecosyste.ms
- Q4 (staff activity after joining ISC) needs membership timeline data
- Q9 (funding) needs repos.ecosyste.ms funding data
- Industry/size categorization of the 108 orgs
- Identify supply chain security projects (OpenSSF, etc.) among dependencies
