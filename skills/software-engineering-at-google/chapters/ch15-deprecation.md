# Chapter 15: Deprecation

## Core Idea
Code is a liability, not an asset — functionality is the asset — so deprecation (the orderly migration away from and removal of obsolete systems) must be planned, staffed, and owned like any other engineering project, not left to hope and warning labels.

## Frameworks Introduced
- **Advisory vs. Compulsory Deprecation**: the two ends of a continuum for how a deprecation is enforced.
  - Advisory: no deadline, no dedicated resources, "aspirational" — relies on users voluntarily migrating. Works only when the new system's benefits are transformative, not incremental, and even then rarely finishes existing migrations on its own ("hope is not a strategy").
  - Compulsory: has a removal deadline with real enforcement — a dedicated team can break noncompliant users after sufficient warning. Requires active staffing through completion; an unfunded compulsory mandate reads to customer teams as "mean spirited" and creates friction.
  - When to use: advisory for early adoption/awareness of a new system; compulsory once you actually intend the old system to go away on a schedule.
- **Deprecation Warning Properties — Actionability and Relevance**: every deprecation warning needs both.
  - Actionable: the user can practically act on it now (e.g., a tool suggests the exact replacement call).
  - Relevant: it surfaces at the moment the user is actually doing the relevant work (e.g., while writing the code, not weeks after submission).
  - When to use: as a checklist before adding any deprecation warning — warnings failing either test just add to "alert fatigue" without producing migration.
- **Deprecation Tooling Categories**: discovery, migration, backsliding prevention.
  - Discovery: find who uses the obsolete system and how (Code Search, Kythe, production logging/sampling, treating the global test suite as an oracle for "is this symbol still referenced").
  - Migration: reuse Large-Scale Change (LSC) tooling and code review infrastructure to update the codebase at scale.
  - Backsliding prevention: stop new uses from being added while migration is in progress (Tricorder static analysis warnings at review time; build-system visibility whitelists pruned as teams migrate away).

## Key Concepts
- **Deprecation**: the process of orderly migration away from and eventual removal of an obsolete system.
- **Code as liability**: the premise that code's ongoing costs (maintenance, ecosystem drag, operational resources) must be weighed against the value of the functionality it provides — not treated as inherently valuable simply for existing.
- **Alert fatigue**: the health-care-borrowed term for what happens when deprecation warnings accumulate (especially transitively, e.g., library A depends on B depends on C, and C's warning surfaces through both) until users ignore them entirely.
- **Change aversion**: emotional attachment to systems the deprecator helped build ("I like this code!"), a genuine but self-defeating obstacle to deprecation.
- **In situ evolution**: incrementally refactoring an existing system in place rather than fully replacing it — often cheaper than a full migration, and still counts as (incremental) deprecation of the old parts.
- **Process owner**: an explicit, empowered individual/team responsible for running a deprecation to completion; without one, deprecation either never finishes (falls to advisory-by-default) or never starts.
- **Backsliding**: new code continuing to add dependencies on a system that's actively being removed, forcing the deprecation team into "whack-a-mole."

## Mental Models
- Treat deprecation like nuclear power plant decommissioning: the best time to plan for eventual removal is at design time, by asking "how easy will it be for consumers to migrate away?" and "can I replace parts of my system incrementally?" — not as an afterthought once the system is obsolete.
- Think of every existing system as exerting a "conceptual pull": comparatively many existing uses of an old system will keep attracting new uses ("Please use the new system" rarely overcomes this pull) unless the old path is actively closed off.
- Apply Hyrum's Law to removal specifically: the more users a system has, the more likely they depend on unspecified, "happens to work" behavior — so removal (the "ultimate change") will shake loose dependencies nobody knew existed.
- Treat milestones for a deprecation project the same way you'd treat milestones for building a new one: because "we haven't deleted it yet" is a poor sole measure of progress and bad for team morale, recognize incremental wins (e.g., deleting a key subcomponent) along the way.

## Anti-patterns
- **Assuming age alone justifies deprecation**: some old systems (the chapter cites LaTeX) are still the right tool; deprecation is warranted only when a system is demonstrably obsolete *and* a comparable-or-better replacement exists.
- **Running compulsory deprecation without staffing**: an unfunded mandate that pushes migration work onto customer teams creates the "running to stay in place" friction the chapter warns about, and tends to stall.
- **Letting a deprecated system become "abandoned"**: original owners move to the successor project and leave the obsolete system ownerless but still load-bearing — it does not fade away on its own and still needs dedicated removal effort.
- **Marking things deprecated and walking away**: reduces some new uses but "rarely leads to teams actively migrating away" from existing ones — deprecation markers alone are not a migration strategy.
- **Over-warning**: naive tooling that flags every deprecated symbol everywhere (rather than, e.g., only newly changed lines) produces so much noise that engineers tune it all out.
- **Vetoable "compulsory" deprecations**: if a single critical downstream team can block the deadline indefinitely, the deprecation isn't actually compulsory — this undermines the enforcement mechanism the whole approach depends on.

## Reference Tables

| Dimension | Advisory Deprecation | Compulsory Deprecation |
|---|---|---|
| Deadline | None | Explicit removal deadline |
| Resourcing | Not dedicated | Actively staffed migration team |
| Enforcement | None — relies on voluntary migration | Team can break noncompliant users after warning |
| Best for | Early awareness, transformative new systems | Actually removing the old system on a schedule |
| Typical outcome if used alone | Slows new adoption of old system, rarely completes migration | Finishes, if staffed and not politically vetoed |

| Tooling category | Purpose | Google examples |
|---|---|---|
| Discovery | Find who/how the obsolete system is used | Code Search, Kythe, production logging/sampling, global test suite as oracle |
| Migration | Update the codebase at scale | LSC process and tooling, code review infra |
| Backsliding prevention | Stop new dependencies during migration | Tricorder static analysis (`@deprecated` annotations), build-system visibility whitelists |

## Worked Example
A team wants to retire an obsolete internal library. They start with *discovery*: using Code Search and Kythe to statically find all current callers, plus production logging to catch dynamic/runtime dependencies the static analysis misses, and they treat the company's global test suite as an oracle — if all references to the old symbol are gone and tests still pass, the removal is safe. They intentionally schedule planned outages of increasing duration in the weeks before the actual turndown (mirroring DiRT-style exercises), which surfaces teams who didn't even know they had a dependency on the old system, giving those teams time to prepare or negotiate the timeline. During the migration itself, they reuse LSC tooling to mechanically update the discovered call sites. Throughout, they turn on Tricorder-based backsliding prevention (a `@deprecated`-style annotation surfaced at code-review time with a suggested replacement, sometimes with a push-button fix) so that new code doesn't keep adding fresh dependencies on the system while old ones are still being migrated away. Finally, they use build-system visibility whitelists to mechanically shrink the set of allowed dependents as teams complete migration, pruning the whitelist automatically as it empties out — turning "is anyone still using this?" from a manual question into an automatable one.

## Key Takeaways
1. Code is a liability, not an asset — evaluate every system's ongoing costs against the value of the functionality it provides, not against how much effort went into building it.
2. Deprecation requires a replacement with comparable-or-better functionality to exist first; age alone is never sufficient justification.
3. Advisory deprecation can raise awareness but essentially never completes a migration on its own — "hope is not a strategy." Use compulsory deprecation, fully staffed, when you actually need the old system gone.
4. Every deprecation warning must be both actionable and relevant, or it just contributes to alert fatigue.
5. Design for eventual deprecation up front — ask how easily consumers could migrate away, and how the system could be replaced incrementally — the same way engineering disciplines like nuclear plant design account for decommissioning.
6. Give deprecation efforts an explicit, empowered owner and real enforcement power (the ability to break noncompliant users after sufficient warning), or the effort will stall indefinitely.
7. Invest in discovery, migration, and backsliding-prevention tooling together — skipping backsliding prevention turns deprecation into an endless whack-a-mole game.

## Connects To
- **Ch 16 (Version Control and Branch Management)**: dependency management practices referenced directly as relevant to designing systems for easier future deprecation.
- **Ch 22 (Large-Scale Changes)**: LSC tooling and process is the primary mechanism used to actually execute migration work at scale.
- **Ch 19 (Critique: Google's Code Review Tool)**: code review tooling, and Tricorder specifically, is how backsliding-prevention warnings are surfaced to authors.
- **Ch 20 (Static Analysis)**: Tricorder and ErrorProne-style annotations are the concrete mechanism for both deprecation warnings and backsliding prevention.
- **Ch 17 (Code Search)** and **Ch 23 (Continuous Integration)**: Code Search and Kythe are the discovery tools used to find dependents of an obsolete system, the same tools introduced for large-test dependency discovery in Ch 14.
- **Ch 7 (Measuring Engineering Productivity)**: research techniques from this chapter are cited as a way to build the case that a given deprecation effort is worthwhile.
- **Hyrum's Law** (external/running concept across the book): explains why deprecation is structurally hard — real-world usage always exceeds the documented contract.
