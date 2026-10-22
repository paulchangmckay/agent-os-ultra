# Chapter 22: Large-Scale Changes

## Core Idea
As a codebase and organization grow, the largest atomic commit you can safely make counterintuitively shrinks — so sweeping infrastructure changes must be re-architected as automated, sharded, independently-tested-and-committed pipelines (LSCs) rather than one big commit.

## Frameworks Introduced
- **Large-Scale Change (LSC)**: any set of logically related changes that cannot practically be submitted as a single atomic commit (too many files for the tooling, guaranteed merge conflicts, or a federated-repo topology that makes atomicity technically impossible).
  - When to use: codebase-wide antipattern cleanup, replacing deprecated library usage, low-level infrastructure upgrades (e.g. compiler versions), migrating users from an old system to a new one.
  - How: centralize the work in the infrastructure/owning team (not each consuming team) — they hold the domain knowledge, and centralizing internalizes an "unfunded mandate" cost instead of diffusing it across every downstream team.
- **The Four-Phase LSC Process**: Authorization → Change Creation → Shard Management → Cleanup.
  - When to use: any LSC, from a single-character rename to a codebase-wide type migration.
  - How: (1) Authorization — author submits an FAQ-style proposal to an oversight committee, gets a "global approver" assigned; (2) Change Creation — generate one large comprehensive change via automated tooling (or, rarely, human-sharded generation for urgent security fixes); (3) Shard Management — a tool (Rosie) splits the change along project/ownership boundaries and runs each shard through an independent test→mail→review→submit pipeline; (4) Cleanup — prevent backsliding (e.g. via static-analysis lint) and decide what "done" means for this LSC.
- **The TAP Train**: batches multiple pending LSC shards together to amortize test cost. Steps: (1) run each candidate change against 1,000 random tests; (2) merge the survivors into one "train" uber-change; (3) run the union of all tests transitively affected by the whole train (can mean every test in the repo, taking 6+ hours); (4) for any nonflaky failure, rerun in isolation against each change to identify the culprit; (5) generate a per-change pass/fail report as submission evidence. Restarts fresh every 3 hours.
  - When to use: whenever you have many independent, narrow-scope, highly-scrutinized refactoring changes in flight simultaneously — exploits that most LSCs are pure refactors that preserve semantics and mostly pass.

## Key Concepts
- **Rosie**: Google's LSC platform — shards a master change by project/ownership boundaries, then independently tests, mails, reviews, and submits each shard, capping outstanding shard count and running at low priority to avoid overloading shared infra.
- **Haunted Graveyard**: an SRE term for an ancient, obtuse, or business-critical system nobody dares touch — the LSC-process antagonist; solved only by thorough testing, which lets you change ancient code with confidence.
- **Global approver**: a single reviewer with cross-repo ownership rights who handles review for an entire LSC's shards using pattern-based tooling, instead of routing every shard to each local project's owners.
- **Cattle vs. Pets**: hand-crafted engineer commits are "pets" (personal, painstaking); LSC shards are "cattle" (nameless, high-volume, cheaply regenerated/rolled back without taking it personally).
- **Kythe**: Google's semantic code-indexing tool, used to answer "who calls this function" / "what derives from this class" and to power refactoring tooling.
- **Backsliding**: reintroduction of a deprecated pattern/symbol after an LSC removed it — guarded against with Tricorder static-analysis checks at review time.
- **500-edit rule of thumb**: if a change requires more than ~500 individual edits, it's usually more efficient to learn and use LSC tooling than to hand-edit (lower for experienced "code janitors").

## Mental Models
- Think of test cost vs. diagnostic cost as a deliberate trade-off: Google over-runs tests (transitively affected tests, sometimes the whole test suite) because engineer time hunting a failure in a 10,000-file change is far more expensive than the extra compute of rerunning tests redundantly.
- Use "cattle, not pets" to set the right emotional/process posture for LSC shards — a rejected shard is a routine, cheap event, not a personal failure, because automation can regenerate it near-instantly.
- Treat heterogeneity (differing VCSs, CI systems, per-project presubmit rules, formatting styles) as the enemy of automation: LSCs work only when the bulk of the effort is done by computers, and computers need consistent environments — invest in consistency (style guides, autoformatters) for the sake of the robots, not just the humans.
- View LSC infrastructure investment like paving/pothole-repair: once the machinery exists for high-priority migrations, it becomes cheap enough to also fix small, previously-not-worth-it inconsistencies (the `stl_util.h` vs `map-util.h` example) — the existence of the tool changes the cost-benefit calculus for many smaller fixes.

## Anti-patterns
- **Organic, team-by-team migration ("unfunded mandate")**: diffuse benefits rarely motivate individual teams to migrate on their own initiative; centralizing cost and ownership in the infra team is faster and cheaper.
- **Reviewing every LSC shard with full local-owner rigor**: local owners trusting infra teams too much makes case-by-case full review both unnecessary friction and, ironically, under-scrutinized — route to a global approver with pattern-based tooling instead.
- **Hand-authoring LSC edits at scale**: manual editing beyond the ~500-edit threshold is inefficient and error-prone compared to codegen tooling; Operation RoseHub's 50-human/2,600-patch response was a rare, justified exception under time pressure, not the norm.
- **Ignoring language/tooling heterogeneity**: dynamically typed languages (Python, Ruby, JavaScript) lack the static information that makes automated, provably-safe LSC transformations tractable, making them intrinsically harder to maintain at LSC scale than statically typed ones.
- **Letting preexisting presubmit failures block an LSC**: LSC tooling ignores preexisting failures rather than fixing them inline — that's the local team's responsibility as part of the social contract with infra teams, not the LSC author's job.

## Reference Tables

| LSC Barrier | Why it blocks atomic commits |
|---|---|
| Technical limitations | Most VCS operations scale linearly with change size; some can't commit thousands of files atomically, or block other writers/readers during large commits |
| Merge conflicts | Conflict probability grows with number of files touched and number of engineers concurrently active |
| Haunted graveyards | Old, untested, business-critical code that no one dares change — blocks migrations and decommissions that depend on it |
| Heterogeneity | Divergent VCSs/CI/tooling/formatting per project prevents uniform automated transformation |
| Testing cost/diagnosability | Larger changes make failures harder to root-cause (25-file vs. 10,000-file diff) even though rerun cost is cheaper per-test at small scale |

## Worked Example
**Migrating `scoped_ptr` to `std::unique_ptr`** — the largest LSC attempted at Google up to that point:
1. Google's C++ codebase had a homegrown self-destructing smart pointer, `scoped_ptr`, predating C++11, with 500,000+ references across millions of source files.
2. C++11 introduced `std::unique_ptr`, strictly better (catches more bug classes) — but migrating required touching the entire codebase.
3. Over several months, engineers used Google's LSC infrastructure to convert references in parallel, at peak generating/testing/committing 700+ independent shard changes touching 15,000+ files *per day* (later scaled to ~10x that).
4. Approach: first make `scoped_ptr` a type alias of `std::unique_ptr` (so both names behaved identically), then do textual substitution of the alias name across the codebase, then finally delete the old alias — avoiding ever needing one atomic flag-day cutover.
5. Long tail of manual cleanup remained: Hyrum's Law-style hidden behavioral dependencies, race conditions with concurrently-running engineers' edits, and generated code invisible to the automated tooling — handled by hand as testing infrastructure surfaced them.
6. `scoped_ptr` used as a parameter type in some widely-used APIs made isolated shard changes hard; a call-graph-transitive rewrite tool was considered but rejected as producing commits too large to submit atomically — reinforcing that even LSC tooling has a ceiling on shard size.

## Key Takeaways
1. LSCs must be automated, not hand-edited, to scale — human effort should scale sublinearly with codebase size.
2. Centralize LSC ownership in the infrastructure/domain-expert team, not the many consuming teams — this both internalizes the "unfunded mandate" cost and produces more correct changes.
3. Test the transitive closure of affected tests per shard (accept redundant compute cost) because diagnosing a failure gets exponentially harder as change size grows.
4. Batch narrow, well-scrutinized refactoring shards together (TAP train model) to amortize the cost of running the full affected test set.
5. Treat LSC shards as "cattle" — cheap, automatable, and non-precious — to sustain the throughput and morale the process requires.
6. Type aliasing / forwarding functions (language features that let old and new names coexist) are what make incremental, non-atomic migration of a widely used symbol possible at all.
7. Invest early in codebase insight tooling (semantic indices like Kythe, AST-based transformers) and automated formatting — without them, large-scale automated changes can't "fit in" with human-authored code or scale past manual review.

## Connects To
- **Ch 8 (Style Guides and Rules)**: consistent formatting/style is what lets automated tooling produce human-readable, review-friendly diffs at scale.
- **Ch 9 (Code Review)**: LSC review reuses the standard review process but routes to a single global approver instead of per-project owners.
- **Ch 11 (Testing Overview)**: thorough test coverage is what turns "haunted graveyard" code into safely-changeable code.
- **Ch 15 (Deprecation)**: LSCs are the mechanism that actually executes a deprecation's migration step; cleanup/backsliding-prevention (Tricorder) is shared machinery.
- **Ch 16 (Version Control and Branch Management)**: monorepo visibility and trunk-based development are prerequisites for LSC tooling to even see the whole codebase.
- **Ch 17 (Code Search)** / **Ch 20 (Static Analysis)**: Kythe-based code search and Tricorder-based static analysis both underpin LSC change generation and backsliding prevention.
- **Ch 23 (Continuous Integration)**: TAP (Test Automation Platform) is Google's shared CI substrate, reused and adapted (the "train" model) specifically for LSC-scale testing.
- **Hyrum's Law**: LSC migrations routinely surface hidden behavioral dependencies that only manifest once a supposedly-safe refactor touches real usage.
