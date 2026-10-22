# Chapter 23: Continuous Integration

## Core Idea
CI's job is to decide *which tests to run when* and *how to compose the system under test at each stage* — the goal isn't "100% green" or "run everything on presubmit," it's catching problems as early and cheaply as possible while treating engineer time as the scarcest resource.

## Frameworks Introduced
- **Continuous Integration (redefined for scale)**: "the continuous assembling and testing of our entire complex and rapidly evolving ecosystem" — broader than Fowler's classic definition, because dependencies now include upstream microservices, ML models, evolving OSes/runtimes, and platforms owned by other teams, not just your own repo.
  - When to use: any system with dependencies you don't fully control, updating on their own schedule.
- **CB / CD / CT split**: Continuous Build (integrates latest code at head, runs build+test, produces "green head" vs. "true head"), Continuous Delivery (assembles Release Candidates from green head, promotes/tests them through environments), Continuous Testing (the connective tissue — progressively larger-scoped tests as a change moves rightward through its lifecycle).
  - When to use: as the three-part decomposition for designing any org's CI pipeline; CD is developed further in Ch. 24.
- **"CI Is Alerting" framing** (Titus Winters): treat CI as the left-shifted twin of production monitoring/alerting — both exist to "identify problems automatically, as soon as possible," so SRE best practices (error budgets, don't alert on non-actionable signals, cause-based vs. symptom-based checks) transfer directly to CI policy.
  - When to use: when deciding CI gating policy (e.g., is "100% green to commit" the right bar?).
  - How: apply the SRE lesson that 100% uptime is the wrong target — pursuing 100% green CI is comparably expensive and creates presubmit/submission race conditions; not every test failure should block commits, just as not every alert should page.
- **Hermetic Testing**: tests run against a fully self-contained environment (no external/live dependencies) for determinism and isolation.
  - When to use: whenever test stability on presubmit matters more than fidelity to live backends.
  - How: either fully sandbox the stack (feasible for smaller systems) or use record/replay to cache and replay live backend responses (cheaper at scale, but trades false positives — cache hit masks a real change — against false negatives — unnecessary cache misses that block submission).

## Key Concepts
- **Green head vs. true head**: true head = latest committed change; green head = latest change the Continuous Build has verified passing. Engineers commonly develop against green head but must sync to true head before submitting.
- **Release Candidate (RC)**: a deployable unit assembled from code + configuration + dependencies that passed the CB — configuration is included and versioned/tested alongside code because "a large percentage of production bugs are caused by silly configuration problems."
- **Version skew**: a distributed system state containing multiple incompatible versions of code/data/config simultaneously (a canarying/RC-promotion risk).
- **Mid-air collision**: two changes touching unrelated files that nonetheless combine to break a test — occurs because presubmit tests a change against a repo state that may shift before submission.
- **Build Cop**: the team member responsible for keeping their project's tests green in TAP regardless of who broke them; drops other work to fix or roll back the offending change immediately.
- **Culprit finding**: isolating which change in a batch caused a test failure — done by automatically re-splitting a failing batch and rerunning each change in isolation, plus manual binary-search tooling.
- **Canarying**: deploying to a small percentage of production first as an intermediate feedback loop before full rollout.
- **Probers**: the same test suite run continuously against production itself, to verify both production's health and the tests' continued relevance.

## Mental Models
- Think of the "life of a code change" as a monotonically more expensive pipeline: local edit-compile-debug loop → presubmit → post-submit integration → staging/QA → internal dogfood → external bug reports/press. Push detection as far left as is economically sensible, but never assume presubmit can or should be exhaustive.
- Use "defense in depth" for testing: no single stage (presubmit, post-submit, RC test, production probers) is sufficient alone — the combination is what delivers confidence.
- A CI policy question ("should this test run on presubmit?") is really a resource-allocation question: fast+reliable tests earn a spot in the expensive, blocking presubmit lane; slow or flaky tests belong in the cheaper, non-blocking post-submit lane, with mechanisms (Build Cop, rollback) to handle the failures that do slip through.
- Rollback and testing are mutually reinforcing, not independent: "tests give us confidence to change, rollbacks give us confidence to undo" — without tests, rollback isn't provably safe; without fast rollback, broken tests can't be fixed quickly enough to preserve trust in the suite.

## Anti-patterns
- **Running all tests on presubmit**: too expensive in engineer wait-time, and blocks people on failures unrelated to their own change (flakiness, instability) — the reason presubmit is deliberately non-exhaustive.
- **Treating every test failure as equally blocking**: mirrors treating every alert as page-worthy; if a failure's root cause is well understood and clearly won't affect production, blocking all commits on it is unreasonable.
- **Dumping end-to-end test failures into a raw log**: doesn't scale past a handful of consumers (Takeout hit this at ~90 integrated product plug-ins) — feedback must be both accessible and actionable, not just recorded.
- **Silently commenting out failing tests**: makes it too easy to forget about a real problem; Takeout instead tags disabled tests with a bug ID so the suite stays "green" without losing track of known issues.
- **Manual comparison of CI vs. production to isolate upstream failures**: expensive use of a Build Cop's time — the fix is to run the identical test suite against both continuously and diff results automatically, or to add hermetic record/replay to eliminate upstream noise entirely.

## Code Examples
```text
Feedback loop speed ranking (fastest -> slowest):
1. Local edit-compile-debug loop
2. Automated presubmit test results to the change author
3. Post-submit integration failure between two projects' changes
4. Staging-environment incompatibility with an upstream microservice, caught by QA
5. Internal-user bug reports (dogfooding)
6. External-user or press bug/outage reports
```
- **What it demonstrates**: CI's core lever is moving detection as far up this list as is economically justified ("shifting left on testing").

## Reference Tables

| Stage | What runs | Why |
|---|---|---|
| Presubmit | Fast, reliable tests only (usually project-scoped unit tests) | Protect engineer productivity; ~95%+ of changes passing presubmit also pass the rest |
| Post-submit (TAP) | All potentially affected tests, including large/slow ones | Async, doesn't block the author; failures land on the Build Cop |
| Release Candidate | Full suite re-run against the assembled RC | Sanity check after recompilation, auditability, supports cherry-picks and emergency pushes |
| Production (probers) | Same suite run against live production | Verifies both production's health and the tests' continued relevance |

| Record/replay failure mode | Cause | Effect |
|---|---|---|
| False positive | Cache hit too aggressive, masks a real behavior change | Test passes when it shouldn't |
| False negative | Cache miss too aggressive, stale responses need constant refresh | Test fails when it shouldn't (often submit-blocking) |

## Worked Example
**Google Takeout's CI evolution** (case study, 4 scenarios):
1. **Continuously broken dev deploys** — Takeout grew from 1 product to backing 10+ Google products (Drive, Gmail, etc.), each an independently configured instance sharing the same binary. Flag/config incompatibilities caused nightly deployment breakage, only discovered the next day. Fix: sandboxed mini-environments run on presubmit to verify every configuration's server starts up healthy — cut nightly failures 50%, prevented 95% of bad-config breakages. End-to-end tests couldn't move to presubmit (they need test accounts under real security constraints), so the team instead ran them post-submit every 2 hours against a fresh RC built from green head — cutting the "culprit set" (candidate changes to blame) by 12x versus once-daily.
2. **Indecipherable test logs** — as plug-in integrations grew to 90+ products, raw log-dumped end-to-end failures became unmanageable. Fix: a parameterized test runner with a friendly pass/fail UI and failure messages containing direct links to the relevant log lines — cut the Takeout team's involvement in debugging client failures by 35%.
3. **Debugging "all of Google"** — because Takeout's tests exercised 90+ real product backends, its CI incidentally caught unrelated production bugs, but this made failure isolation (is this our bug or theirs?) hard. Fix: run the identical test suite continuously against production itself, then diff results against post-submit CI to isolate what's new in Takeout's own build. Future direction: hermetic record/replay to remove upstream noise entirely.
4. **Keeping it green** — with many plug-in-owned end-to-end tests, the suite was nearly always red from bugs the Takeout team didn't own. Fix: tag failing tests with an associated bug ID to suppress them from breaking "green" status without losing visibility; auto-detect via the bug-tracker API when a tagged test starts passing again (or a bug closes) and prompt cleanup — a self-maintaining suite, tracked via a "mean time to clean up" (MTTCU) metric. A parallel mechanism let plug-in engineers register a feature flag/change ID plus expected pre/post output, so tests could stay correct through gradual feature rollouts instead of needing manual per-environment disabling.

## Key Takeaways
1. CI is fundamentally a resource-allocation and test-placement decision, not a binary "do we have CI" question — decide which tests run when, and how faithfully to build the system under test at each stage.
2. Presubmit should be fast and reliable only; accept some post-submit escapes as the price of engineer productivity, and invest in Build-Cop discipline plus fast rollback to catch them.
3. Hermetic testing (sandboxed or record/replay) is the primary lever for making larger-scoped tests presubmit-safe — pick sandboxing for small systems, record/replay at scale, and expect to tune the false-positive/false-negative tradeoff continuously.
4. Apply SRE alerting discipline to CI: not every failure should block, not every test needs to be 100% green, and error-budget-style thinking beats absolutism.
5. Culprit finding at scale requires both automatic batch-splitting/rerun and dedicated bisection tooling — flakiness and infra noise make "just check which change broke it" nontrivial past a few changes per second.
6. Make CI feedback both accessible (visible logs/history to everyone, flake classification) and actionable (direct links, clear pass/fail UI) — readability of output is itself a force multiplier on CI's value.
7. CI cost isn't new cost — it's production firefighting cost shifted left to a cheaper, earlier stage; teams that think they "can't afford CI" are often already paying more for it downstream.

## Connects To
- **Ch 11 (Testing Overview)**: the exponential cost-of-bugs-over-time curve is the foundational argument for fast feedback loops.
- **Ch 13 (Test Doubles)**: fakes as one hermetic-backend option, with the same fidelity-vs-maintenance-cost tradeoff.
- **Ch 14 (Larger Testing)**: record/replay as a technique for hermetic integration testing.
- **Ch 16 (Version Control and Branch Management)**: trunk-based development ("head") is the substrate CB/CD operate on.
- **Ch 22 (Large-Scale Changes)**: TAP's "train" batching model for LSCs is a specialized derivative of TAP's general presubmit/post-submit batching described here.
- **Ch 24 (Continuous Delivery)**: this chapter's RC/CD definitions are expanded fully in the next chapter.
- **SRE / Site Reliability Engineering (O'Reilly)**: error budgets and alerting fidelity concepts are imported wholesale into the "CI is alerting" framing; Rapid (Google's release-automation system) is referenced but detailed there, not here.
