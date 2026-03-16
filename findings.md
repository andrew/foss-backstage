Findings from analysing 108 InnerSource Commons member organisations' GitHub activity. Bot accounts filtered using pattern matching (`-bot`, `[bot]`, `Bot` suffixes) plus a curated list.

Data sources: GitHub API (repos), ecosyste.ms commits/issues/repos/packages services (contributors, activity, dependencies, package metadata). Maintainers identified by MEMBER/OWNER/COLLABORATOR association on issues, filtering out third-party contributors.

## Open source is growing

GitHub's Innovation Graph (github.com/github/innovationgraph) tracks platform-wide growth quarterly from Q1 2020 to Q3 2025. Everything is up and to the right: developers went from 52 million to 190 million (3.6x), repositories from 140 million to 440 million (3.1x), git pushes from 98 million to 251 million per quarter (2.6x), and organisations from 3.5 million to 8.9 million (2.6x). Growth is steady quarter over quarter, with a small seasonal dip in Q3 pushes each year.

More people and more organisations are building on open source every quarter. That makes the question of whether ISC members are contributing back more pressing, not less.

## The dataset

108 ISC member organisations own 23,696 GitHub repos. 14,202 are active (non-fork, non-archived). 76,724 people have maintainer-level access across these orgs.

45 orgs are software companies, 63 are non-software (banking, retail, automotive, etc.). By size: 32 huge (100k+ employees), 40 large (10k-100k), 27 medium (1k-10k), 9 small (<1k).

Microsoft dominates with ~39,700 maintainers across 13 GitHub orgs, roughly half the total. Numbers are presented with and without Microsoft where it matters.

## Q2: Do ISC members publish well-used open source?

26.6% of active repos publish packages (3,776 repos, 14,557 packages). Software companies publish from 27.3% of their repos vs 23.9% for non-software companies.

8.25 million repos depend on ISC-published packages. Microsoft's TypeScript dominates: 2.1 million dependent repos. tslib follows at 1.7 million. After that it drops sharply -- @rushstack/eslint-patch at 926k, then GitHub's pages-gem at 369k. Without the TypeScript packages: 3.5 million dependent repos. Outside Microsoft, the most-depended-on ISC packages are GitHub's Jekyll gems, Stripe's client libraries (46k dependent repos across npm/Ruby/Python), Twilio's SDKs (22k), and Adobe's react-spectrum component library (11k).

Total downloads: 29.9 billion. A caveat: download periods vary by ecosystem. npm figures (3.9 billion of the total) are last-month downloads from the registry. nuget (17.7 billion) and cargo (6.3 billion) are all-time. Microsoft accounts for 26.3 billion, driven by NuGet test platform packages (1.5 billion each), tslib (1.3 billion/month npm), and the windows-sys Cargo crate family (769 million all-time). Top publishers after Microsoft are Stack Overflow (998 million, mostly StackExchange.Redis), Adobe (565 million), Stripe (505 million), Twilio (470 million), and GitHub (428 million).

Some orgs punch above their repo count. CH Robinson has 6 packages with 28 million downloads. Nubank has 24 with 15 million. Philips has 47 with 6.9 million.

## Q3: Do ISC members contribute to external open source?

8,142 maintainers (10.6%) have activity on repos outside their own organisation. 4.6 million contributions to 107,206 external repos.

By participation rate: IBM (40.8%), Comcast (26.7%), Nokia (25.7%), Adobe (23.5%), Sourcegraph (22.8%), Siemens (21.0%). SAP has 317 active but that's only 3.9% of 8,078 total.

By volume: Microsoft (3.4 million), GitHub (658k), IBM (343k), SAP (248k), Adobe (157k), Tencent (154k).

About 90% of maintainers show no external activity. The ones who do are prolific.

## Q6: Activity type breakdown

4.6 million external contributions total:
- Commits: 4.1 million (89%) by 5,808 people
- Pull requests: 359k (8%) by 6,612 people
- Issues: 156k (3%) by 6,258 people

More people open issues and PRs than commit, but committers produce far higher volume per person.

Of the 6,258 people filing issues, 5,538 (88%) also contribute code (commits or PRs). Only 720 people file issues without any code contributions, and they account for just 1,941 issues (1.2% of the total). Issue-only behaviour is rare and low volume.

## Q5: Do ISC members contribute to their own dependencies?

59 of 108 orgs have maintainers contributing back to packages they depend on. 3,210 people contribute to 10,894 dependency packages.

Microsoft leads with 1,779 people contributing 4.2 million times to 7,817 dependencies. Adobe follows with 122 people and 140k contributions to 1,943 dependencies. IBM has 471 people with 128k contributions to 2,269 dependencies. SAP: 145 people, 97k contributions, 1,449 dependencies. GitHub: 225 people, 70k contributions, 1,191 dependencies.

After that there's a steep drop. ING Bank (22k contributions), Tencent (12k), Mercari (4.8k), Twilio (3.9k), Intuit (3.4k). 49 orgs contribute nothing to their dependencies.

The "most contributed-to dependencies" list is dominated by DefinitelyTyped (@types/* packages). Since all @types packages live in one monorepo, every contributor to DefinitelyTyped shows up against every @types package their org depends on. The actual number of distinct upstream projects receiving contributions is lower than the per-package count suggests. Same effect with Parcel (@parcel/*) for Adobe.

In raw commit terms: 2,704 ISC members have contributed 235,866 commits to their dependency packages, 4.3% of the 5.5 million total commits on those repos. Narrowing to critical packages: 1,360 members have contributed 40,979 commits, 1.2% of the 3.4 million total commits on critical repos -- 30 commits per person.

## Q7: Shared dependencies

The most widely used dependency: actions/checkout (68 orgs). Then npm/inherits and npm/semver (67 orgs each), npm/supports-color and npm/has-flag (67 orgs). After that the usual npm plumbing: debug, chalk, once, ms, minimatch, balanced-match (all 66 orgs).

npm dominates the dependency graph. The top shared packages by download volume: semver (2.5 billion), ansi-styles (2.2 billion), debug (2.2 billion), minimatch (2 billion), strip-ansi (1.8 billion), chalk (1.7 billion). These are the plumbing of npm.

Of the 9,301 shared dependencies (5+ orgs) with known repos: 4,025 (43%) are maintained by a single registry maintainer. 4,208 (45%) are marked as critical to all open source by packages.ecosyste.ms. 3,377 (36%) show signs of being unhealthy: no release in the past two years while still having open issues. 1,428 of those combine stale releases, open issues, and only one or two maintainers.

## Q8: Dependency vs contribution gap

4,508 (48%) of those shared dependencies receive some contribution from ISC maintainers. 4,793 (52%) receive none.

That 48% is inflated by monorepo effects. DefinitelyTyped contributions map to hundreds of @types packages. Parcel contributions map to dozens of @parcel packages. The number of distinct upstream projects getting real attention is much smaller.

The gap packages are the headline finding. These are depended on by 65-67 ISC orgs, have hundreds of millions to billions of downloads, and zero contributions:

- npm/has-flag: 67 orgs, 1 billion downloads
- npm/inherits: 67 orgs, 553 million downloads
- npm/ansi-styles: 66 orgs, 2.2 billion downloads
- npm/chalk: 66 orgs, 1.7 billion downloads, 130k dependents
- npm/find-up: 66 orgs, 845 million downloads
- npm/once: 66 orgs, 407 million downloads
- npm/normalize-path: 66 orgs, 384 million downloads
- npm/cross-spawn: 65 orgs, 646 million downloads
- npm/braces: 65 orgs, 476 million downloads
- npm/inflight: 65 orgs, 222 million downloads (archived/unmaintained)
- npm/iconv-lite: 65 orgs, 761 million downloads

Many maintained by a single person (sindresorhus, isaacs, jonschlinkert, micromatch). The ISC collectively depends on them but contributes nothing back.

## Funding

27% of dependency packages have funding links in their metadata. The breakdown: GitHub Sponsors (10,124), Other (5,716), OpenCollective (3,737), Tidelift (968), Patreon (720), PayPal (324), Buy Me a Coffee (206).

Packages with funding links are slightly more likely to receive ISC contributions (45.8%) than those without (35.9%). But unfunded packages receive far more total contribution volume (6 million vs 390k), likely because the biggest projects (React, TypeScript, Kubernetes) don't need tip jars.

The gap packages almost all have funding set up. sindresorhus (has-flag, find-up, chalk ecosystem) has GitHub sponsors. isaacs (once, minimatch, glob) has sponsors. juliangruber (balanced-match, brace-expansion) has GitHub Sponsors and PayPal. ljharb (concat-map, function-bind) has sponsors.

These maintainers have set up funding, ISC members depend on their work, but the contribution flows in neither code nor money from ISC members to these projects.

## Abandoned dependencies

Archived dependency repos are still in active use by ISC orgs. The worst cases: @humanwhocodes/config-array (56 orgs), loader-utils (55 orgs, 224 million downloads), q (54 orgs), npmlog (51 orgs), source-list-map (46 orgs), memory-fs (44 orgs).

Go has its own set of zombies: gopkg.in/yaml.v2 and v3 (45 and 41 orgs, 90k dependents each), github.com/golang/mock (40 orgs), github.com/mitchellh/mapstructure (40 orgs, 33k dependents), github.com/client9/misspell (40 orgs). These packages have successors but migration hasn't happened.

## Bus factor

6,470 shared dependency repos (5+ ISC orgs) were checked against commits.ecosyste.ms for contributor data. The results are sobering.

Many of the most widely used packages have a single person who can publish updates. supports-color (67 orgs, 1.6 billion downloads), has-flag (67 orgs, 1 billion downloads), chalk (66 orgs, 1.7 billion downloads), minimatch (66 orgs, 2 billion downloads), once (66 orgs, 407 million downloads) -- all have exactly one person with the publish bit. The pattern repeats across the top 30 most-depended-on packages.

The "highest risk" packages combine three signals: low commit diversity (DDS), no commits in the past year, and wide ISC usage. has-flag (67 orgs, 1 billion downloads, 7 committers ever, dormant), normalize-path (66 orgs, 384 million downloads, 3 committers, dormant), function-bind (65 orgs, 482 million downloads, dormant), yallist (65 orgs, 879 million downloads, 3 committers, dormant), cross-spawn (65 orgs, 646 million downloads, dormant). imurmurhash-js is the extreme case: 63 orgs depend on it, 328 million downloads, and it has had exactly one committer in its entire history.

The combination of single-publisher, low DDS, and no recent activity means that if these maintainers lose interest, burn out, or have their accounts compromised, dozens of ISC member organisations are exposed. The ISC collectively depends on these packages but contributes nothing back to them.

## Ecosystem gaps

Contribution rates vary by language ecosystem. Carthage has the worst gap at 89.5% of dependencies receiving no ISC contributions, followed by Packagist (PHP, 87.7%), CRAN (R, 84.7%), Bower (80.8%), Clojars (77.3%), SwiftPM (75.5%), CocoaPods (73.1%). Go is at 67.4%, npm at 60.5%, cargo at 61.4%. Conda has the smallest gap at 48.4%, followed by pub (Dart, 40.1%). Docker and Maven effectively show 0% gap (though Maven has no repo URL mappings).

## Cross-ISC contributions

705 people from 52 ISC orgs contribute to 444 repos at 44 other ISC orgs. 82,281 total cross-ISC contributions.

Microsoft is the largest source (71.6k contributions to 31 ISC orgs by 360 people), followed by GitHub (7k) and Baidu (1.3k). On the receiving end, Sourcegraph dominates with 77.5k contributions from 24 ISC orgs -- the Microsoft-to-Sourcegraph flow alone is 70k contributions by 112 people. Microsoft itself receives contributions from 43 ISC orgs (2.6k contributions from 210 people).

Beyond the Microsoft/Sourcegraph outlier, the cross-ISC network is thin. Most org-to-org flows are under 100 contributions.

## Maintainer overlap

3,028 maintainers appear in multiple ISC orgs, all cross-company. Most (2,760) span exactly 2 orgs, but some span many more. The top multi-org accounts include prolific cross-project contributors like eltociear (13 orgs, 8.2k external contributions) and serial typo-fixers/documentation contributors who make small PRs across many organisations.

## License analysis

MIT dominates shared dependencies (9,440 packages), followed by Apache 2.0 (3,527). Copyleft dependencies are mostly MPL: axe-core (MPL, 38 orgs), hashicorp/hcl (MPL, 37 orgs), go-sql-driver/mysql (MPL, 26 orgs), postcss-values-parser (MPL, 26 orgs). pylint (GPL, 29 orgs) is the most widely used GPL dependency. GPL/AGPL dependencies are otherwise rare in the shared set.

## Industry breakdown

Non-software companies have a higher external participation rate (16.6%) than software companies (10.1%), though software companies contribute more in absolute volume. This is partly because software companies have far more maintainers per org, diluting the percentage.

By industry, manufacturing stands out: 24.5% participation rate and 190.8 contributions per capita, driven largely by Siemens. Healthcare (Philips) shows 31.5% participation. Banking is low at 15.7% participation and 30.4 per capita.

Small companies (<1k employees) have the highest per-capita contribution rate at 175.6 contributions per maintainer, though this reflects a few highly active small orgs like Sourcegraph (461 per capita) and Etsy (197 per capita). Huge companies (100k+) contribute 78.7 per capita with Microsoft, 58.1 without.

## Docker base images

980 distinct Docker base images are used across ISC orgs. The most common: node (38 orgs), python (32), ubuntu (32), golang (31), alpine (30). All official images point to docker-library/official-images as their upstream. nginx, postgres, and redis each appear in 16 orgs. openjdk and debian in 18 each.

## What Microsoft does to the numbers

Microsoft is roughly half the dataset by maintainer count and 70% of contribution volume.

- With Microsoft: 10.6% externally active. Without: 11.2%. Microsoft lowers the average.
- With Microsoft: 84% commits. Without: ~59%. Microsoft is heavily commit-weighted.
- With Microsoft: 26.6% of repos publish packages. Without: 22.8%.
- Microsoft: 26.3 billion of 29.9 billion total downloads.
- Microsoft: 4.2 million of 4.8 million dependency contributions (mostly DefinitelyTyped and LLVM).

## Still to come

- Q4 (staff activity after joining ISC) needs membership timeline data
