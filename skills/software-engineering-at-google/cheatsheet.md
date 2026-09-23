# Cheatsheet — Software Engineering at Google

Decision-ready judgment calls, not definitions. See [glossary.md](glossary.md) for terms.

## Core Decision Rules

| Situation | Do | Because |
|---|---|---|
| Choosing which best practice to apply | Ask the code's expected life span first | Practices for code living hours differ from code living decades — no universal "best practice" (Ch1) |
| An API has many internal users | Assume every observable behavior is depended upon | Hyrum's Law — the written contract doesn't matter once usage scale is high (Ch1) |
| A task repeats across the org | Make it linear-or-better scalable in human input, prefer policy over heroics | Non-scalable processes become boiled-frog problems that surface too late (Ch1) |
| Justifying a decision | Mix data + assumption + precedent + argument, but weight data highest | "Because I said so" fails; pure-data-only is rarely achievable (Ch1) |
| Picking a metric | Run it through GSM (Goals→Signals→Metrics) and check QUANTS coverage | Prevents optimizing one productivity dimension at another's expense (Ch7) |
| Reviewing code | Optimize for the reader, not the author | The code is read far more often than written (Ch9) |
| Writing a rule/style guide entry | Back it with data; automate enforcement | Un-enforced rules decay; data keeps rules defensible when challenged (Ch8) |
| Writing a unit test | Test via public API, test state not interactions, name for behavior | Interaction/implementation-coupled tests are brittle under refactoring (Ch12) |
| Choosing a test double | Prefer real impl > fake > stub > mock, in that order | Each step down trades fidelity for speed/isolation (Ch13) |
| Deciding to deprecate a system | Compare ongoing maintenance cost vs. removal cost, including ecosystem drag | Removal is usually harder than building — Hyrum's Law strikes here too (Ch15) |
| Choosing branch strategy | Default to trunk-based development | DORA/Accelerate research ties it to high-performing orgs; long-lived branches aren't the default (Ch16) |
| Defining build artifacts | Prefer fine-grained modules over coarse ones | Enables parallelism and incremental builds (Ch18) |
| Pinning external dependency versions | Version explicitly under source control; never track "latest" | "Latest" makes builds unreproducible (Ch18, Ch21) |
| Trusting a version bump (SemVer) | Back it with CI/testing evidence, not just the version number | SemVer alone is a lossy human risk-estimate; testing gives actual evidence (Ch21) |
| Structuring CI test tiers | Fast/deterministic tests presubmit; slow/flaky-prone tests post-submit | Keeps the fast feedback loop fast without dropping coverage (Ch23) |
| Rolling out a change | Flag-guard it, stage the rollout, ship small and often | Isolates failure, makes reality (not synthetic env) the benchmark (Ch24) |

## Trade-off Matrix: Test Doubles (Ch13)

| Double | Fidelity | Speed/Isolation | Risk | Use when |
|---|---|---|---|---|
| Real implementation | Highest | Lowest | None (it's real) | Always prefer if fast/deterministic enough |
| Fake | High | High | Fake drifts from real behavior over time | Real impl too slow/unavailable; own the fake's upkeep |
| Stub | Low | High | Brittle, hides real logic | Only need a fixed canned response |
| Mock (interaction test) | Lowest | High | Brittle to refactors, couples to implementation | Last resort — avoid when possible |

## Thresholds & Defaults

- Life-span ratio driving "no universal best practice": **~100,000x** between shortest- and longest-lived code (Ch1).
- Trunk-based development, not long-lived dev branches: the DORA-backed default (Ch16).
- Dependency versions: always pinned/explicit, never "latest" (Ch18, Ch21).
- CI test placement: fast+reliable → presubmit; slow+less-deterministic → post-submit (Ch23).

## Tells & Smells

| If you see… | You're probably in… |
|---|---|
| A rule nobody can justify with data | A rule that will erode under the first serious challenge (Ch8) |
| Tests that break on every refactor despite unchanged behavior | Interaction-testing / mock overuse (Ch12, Ch13) |
| A team debating "which version of X should I depend on?" | A missing One-Version Rule — solve it at the policy level (Ch16) |
| A dependency imported with no ongoing-support plan | An unpriced future maintenance cost (Ch21) |
| A large refactor stalled on "too big to ever finish" | Needs an LSC (Large-Scale Change) process, not a traditional refactor (Ch22) |
| A feature shipped with no kill switch | Missing flag guard — no way to isolate the failure (Ch24) |

## Decision Tree: "Should I add this rule/policy?"

1. Does it recur across the org? → No: handle case-by-case, skip the rule.
2. Yes → Can it be backed by data? → No: reconsider; "because I said so" won't survive scrutiny (Ch1, Ch8).
3. Yes → Can enforcement be automated? → No: expect slow decay; plan a human-review fallback (Ch8).
4. Yes → Codify it, automate enforcement, revisit as data changes (Ch1, Ch8, Ch20).
