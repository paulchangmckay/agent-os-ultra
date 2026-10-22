# Patterns — Software Engineering at Google

Concrete techniques and processes from the book. See [cheatsheet.md](cheatsheet.md) for decision rules, [glossary.md](glossary.md) for term definitions.

## GSM Framework (Goals-Signals-Metrics)
**When to use**: Selecting what to measure for engineering productivity.
**How**: Define the Goal (what you want, stated without a specific metric), identify Signals (how you'd know the goal is met), then pick Metrics (a proxy that's actually measurable and traceable back to the signal).
**Trade-offs**: Prevents picking a metric first and rationalizing a goal backward — but requires discipline to keep goals metric-free during definition. (Ch7)

## QUANTS
**When to use**: Ensuring a productivity-measurement effort covers all dimensions, not just one.
**How**: Cover Quality of code, Attention/focus, iNtellectual complexity, Tempo/velocity, Satisfaction — balance metrics across all of them so improving one doesn't silently degrade another.
**Trade-offs**: More overhead to track multiple dimensions vs. a single headline number; the payoff is avoiding local optimization. (Ch7)

## One-Version Rule
**When to use**: An organization has repeated internal debate over "which version of X should I depend on?"
**How**: Establish policy that only one version of any given internal dependency exists in the build at a time; remove the choice rather than resolve it case-by-case.
**Trade-offs**: Requires investment in upgrade tooling (someone has to move everyone forward together), but eliminates diamond-dependency conflicts and the "lost labor" of shading/linker-hiding workarounds. (Ch16)

## Large-Scale Change (LSC) Process
**When to use**: A refactor or migration is too large for a single traditional code review (touches thousands of files/many teams).
**How**: Break the change into many small, independently-reviewable, automatable commits; use tooling to generate and land them at scale; treat "making LSCs" as a repeatable organizational habit, not a one-off project.
**Trade-offs**: Requires investment in tooling (static analysis, codemods, automated review routing) up front; pays off because traditional refactoring approaches break down at Google's scale. (Ch22)

## Trunk-Based Development
**When to use**: Default branching strategy for any team above trivial scale.
**How**: Commit to a single shared trunk/head; avoid long-lived feature branches; keep changes small and frequently integrated.
**Trade-offs**: Requires strong CI and fast presubmit checks to keep trunk healthy; in exchange, avoids costly merge conflicts and is empirically tied (DORA/Accelerate research) to high-performing engineering organizations. (Ch16, Ch23)

## Flag-Guarded Rollout
**When to use**: Shipping any feature or behavior change, especially at scale or to a broad user base.
**How**: Gate the new code path behind a flag; roll out staged (small % → larger %) using real production signal, not just synthetic pre-launch testing; keep the flag as an isolation/kill switch.
**Trade-offs**: Adds code complexity (flag branches to maintain and eventually clean up) in exchange for the ability to isolate and roll back a bad change without a redeploy. (Ch24)

## Presubmit / Post-submit CI Split
**When to use**: Structuring a CI pipeline as codebase size and test-suite runtime grow.
**How**: Run fast, deterministic, high-signal tests presubmit (blocking); run slower, larger, less-deterministic tests post-submit (non-blocking but monitored), with actionable feedback routed back to the author.
**Trade-offs**: Post-submit failures can land in trunk temporarily; the trade is keeping the author's fast feedback loop fast. Requires ownership discipline to actually fix post-submit breakages promptly. (Ch23)

## Test-Double Hierarchy (prefer-real ladder)
**When to use**: Deciding what a unit test should depend on.
**How**: Try a real implementation first; if too slow/unavailable, use a fake (a lightweight but behaviorally faithful implementation someone maintains); avoid stubs/mocks unless nothing else works, because they encode implementation details.
**Trade-offs**: Fakes cost upkeep for whoever owns the real system; mocks are cheap to write but brittle under refactors — cheapness up front trades for fragility later. (Ch13)

## DAMP over DRY (in tests)
**When to use**: Writing or sharing setup code across test cases.
**How**: Prefer Descriptive And Meaningful Phrases (some duplication) over strict Don't-Repeat-Yourself abstraction in test code specifically.
**Trade-offs**: Slightly more repeated code, but each test stays independently readable — a failing test's cause is legible without tracing through shared helper abstractions. (Ch12)

## Static Analysis at the Review Point
**When to use**: Rolling out a new automated code-quality check.
**How**: Integrate the check into code review (surfacing fixes to the reviewer/author at review time) rather than only at compile time or in a separate dashboard; tune aggressively for false-positive rate; let domain experts contribute new checks.
**Trade-offs**: Requires an investment in tooling and a feedback channel between check-authors and check-consumers, but this is what keeps developer trust (and thus actual usage) of the analysis high. (Ch20)

## Blameless Postmortem / Psychological Safety Foundation
**When to use**: Building a knowledge-sharing or learning culture.
**How**: Establish psychological safety first (safe to admit "I don't know" or "I made a mistake") before layering structured mechanisms (tutorials, classes, documentation) on top.
**Trade-offs**: Cultural investment with a delayed payoff; skipping straight to structured knowledge-sharing tooling without the safety foundation tends to fail because people won't surface real gaps. (Ch3)
