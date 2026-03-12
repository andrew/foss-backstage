Preliminary findings from analysing 108 InnerSource Commons member organisations' GitHub activity. Package data is still being collected (4,337 of ~22k dependency packages resolved so far), so numbers for Q5/Q7/Q8 will shift as more data arrives. Everything else should be close to final.

Data sources: GitHub API (repos), ecosyste.ms commits/issues/repos/packages services (contributors, activity, dependencies, package metadata). Maintainers are identified by MEMBER/OWNER/COLLABORATOR association on issues, filtering out third-party contributors.

## The dataset

108 ISC member organisations own 23,696 GitHub repos. Of those, 14,202 are active (non-fork, non-archived). 76,900 people have maintainer-level access across these orgs.

Microsoft dominates the dataset with 39,825 maintainers across 13 GitHub orgs, roughly half the total. Numbers are presented both with and without Microsoft where the difference matters.

## Q2: Do ISC members publish well-used open source?

15.7% of active repos publish packages (2,228 repos, 7,726 packages). Without Microsoft that rises to 22.8% of repos, because Microsoft has many repos that don't publish packages.

Total downloads across all published packages: 10 billion. Microsoft accounts for 7.8 billion of that, mostly NuGet packages (Application Insights alone is over 5 billion). Stack Overflow's StackExchange.Redis has 910 million downloads. TypeScript (npm) has 502 million.

Without Microsoft, total downloads are 2.2 billion across 6,420 packages. The top publishers are Stack Overflow, Adobe, GitHub, SAP, and Intuit.

## Q3: Do ISC members contribute to external open source?

8,159 maintainers (10.6%) have activity on repos outside their own organisation. They've made 5.7 million contributions to 111,650 external repos.

Without Microsoft: 4,357 maintainers (11.2%) with 3 million contributions to 76,197 repos. The percentage is actually slightly higher, suggesting Microsoft's large headcount includes more people who only work on internal repos.

By percentage of maintainers active externally, the standouts are IBM (40.6%), Comcast (26.6%), Nokia (25.4%), Adobe (23.4%), Sourcegraph (22.6%), and Siemens (20.6%). SAP has 318 externally-active maintainers but that's only 3.9% of their 8,103 total.

By raw contribution volume, Microsoft leads with 4.2 million, followed by SAP (1.08 million), GitHub (659k), IBM (343k), and Adobe (157k). SAP's high volume comes largely from pull requests and maintainer activity rather than commits, an unusual pattern compared to other orgs where commits dominate.

## Q6: Activity type breakdown

Across all orgs, the split is:
- Commits: 4.17 million (73%) by 5,817 people
- Pull requests: 771k (13.5%) by 6,624 people
- Maintaining: 614k (10.7%) by 3,567 people
- Issues: 160k (2.8%) by 6,264 people

More people file issues and PRs than make commits, but committers produce far higher volume per person. The "maintaining" category (review, triage, merge activity) involves the fewest people but high volume per person, suggesting a core group doing heavy project maintenance work.

SAP stands out again: their top activity type is pull requests (444k), followed by maintaining (392k), with commits third (231k). Most other orgs have commits as their dominant activity by a wide margin.

Without Microsoft, commits drop to 1.78 million (59%), pull requests rise to 640k (21%), and maintaining to 518k (17%). Microsoft's contribution profile is heavily commit-weighted, which pulls the overall distribution.

## Q5: Do ISC members contribute to their own dependencies?

With the partial package data we have (4,000 dependency packages resolved), only 20 of 108 orgs have any maintainers contributing back to packages they depend on. 235 people contribute to 886 dependency packages.

GitHub leads (91 people, 304 dependencies, 7,933 contributions), followed by Adobe (59 people, 531 dependencies, 7,463 contributions). After that there's a steep drop: Comcast (368 contributions), Bloomberg (359), IBM (352).

The most contributed-to dependency is github.com/cilium/ebpf (1,493 contributions from GitHub). The Lit web components ecosystem (@lit/reactive-element and related packages) gets 458 contributions from Adobe maintainers.

These numbers will grow as more package data comes in, but the shape of the distribution is likely stable: a small number of orgs do the vast majority of dependency contribution.

## Q7: Shared dependencies

The most widely-used dependency across ISC orgs is actions/checkout (32 orgs, 715 repos). After that it's the usual npm ecosystem suspects: inherits (31 orgs), semver (31), supports-color (31), chalk (30), debug (30).

The distribution follows a long tail. 25 packages are used by 30+ orgs. 558 packages are used by exactly 5 orgs. 14,932 packages are used by only one org.

The npm ecosystem dominates the dependency graph with 502k dependency entries, followed by Go (20k), Maven (7k), and PyPI (6k).

## Q8: Dependency vs contribution gap

Of 701 shared dependencies (used by 5+ orgs) that have known GitHub repos, 508 receive at least some contribution from ISC maintainers. 193 receive none at all.

72% coverage sounds good, but the contributions are heavily concentrated. A handful of people at GitHub and Adobe account for most of the activity on shared dependencies. Many of the "contributed to" packages have just one or two people making a few contributions.

The gap packages (widely depended on, zero contributions) include core infrastructure: @istanbuljs/schema (24 orgs depend on it), @bcoe/v8-coverage (23 orgs), @jridgewell/resolve-uri (21 orgs), and many Go standard library adjacent packages like github.com/pmezard/go-difflib (18 orgs, 69k dependents ecosystem-wide).

Several of the gap packages have tens of thousands of dependents globally. go-difflib has 69k, golang.org/x/crypto has 126k, github.com/pkg/errors has 99k. These are foundational and nobody in the ISC member base is contributing to them.

## What Microsoft does to the numbers

Microsoft is roughly half the dataset by maintainer count and three quarters of the contribution volume. Some specific effects:

- With Microsoft: 10.6% of maintainers active externally. Without: 11.2%. Microsoft's huge org actually lowers the average.
- With Microsoft: 73% of contributions are commits. Without: 59%. Microsoft's contribution profile is heavily commit-weighted.
- With Microsoft: 15.7% of repos publish packages. Without: 22.8%. Microsoft has many repos that don't produce packages.
- Microsoft contributes 7.8 billion of the 10 billion total package downloads. TypeScript alone is 502 million.

The story changes depending on whether you frame it as "what does the ISC collectively do" vs "what does a typical ISC member do." Microsoft is the elephant in the room for the former but obscures the latter.

## Still to come

- Full package data (22k packages, currently 4,337 resolved) will fill in Q5/Q7/Q8 numbers significantly
- Published packages data is still being collected for org repos
- Q1 (activity over time) needs time-series data
- Q4 (staff activity after joining ISC) needs membership timeline data
- Q9 (funding) needs repos.ecosyste.ms funding data
