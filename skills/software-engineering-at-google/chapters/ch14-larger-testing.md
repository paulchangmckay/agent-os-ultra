# Chapter 14: Larger Testing

## Core Idea
Larger tests exist to close the fidelity gap unit tests can't close (unfaithful doubles, configuration, load, unanticipated behavior, emergent effects) — but their cost and flakiness scale worse than unit tests, so the discipline is to make the System Under Test (SUT) as small as fidelity allows and to give every large test explicit ownership.

## Frameworks Introduced
- **Fidelity**: how reflective a test is of the real behavior of the system under test, along two dimensions — environment (how close the test's runtime setup is to production) and data (how realistic the test's inputs are).
  - How: move along the fidelity spectrum from unit test → single-process SUT → single-machine SUT → multimachine SUT → shared staging → production, accepting more cost/risk at each step for more realism.
- **SUT taxonomy**, judged by hermeticity (isolation from other traffic/components) and fidelity (accuracy to the real production topology):
  - Single-process SUT: SUT and test code in one binary; can be "small" size if single-threaded; least faithful to production topology.
  - Single-machine SUT: separate binaries (as in prod) but all on one machine; "medium" size; ideally uses production launch configs.
  - Multimachine SUT: distributed like a real cloud deployment; "large" size; higher fidelity, higher network/machine flakiness.
  - Shared environments (staging/production): cheapest (already exists) but risks conflicts with other simultaneous uses and end-user impact.
  - Hybrids: run part of the SUT explicitly, let it call into shared backends — often necessary because no company can fully replicate all interconnected services.
  - When to use: pick the smallest/most hermetic SUT that still gives the fidelity the test actually needs; hermeticity and fidelity are usually in tension.
- **Record/Replay proxies**: a "Record Mode" large test runs continuously post-submit against real external services and logs the traffic; a "Replay Mode" small(er) test replays those logs during development/presubmit, matching requests via a matcher.
  - When to use: when you need higher fidelity than a hand-written fake but can't afford to hit the real dependency on every test run.
- **Test Strategy**: the part of a test plan that identifies a system's primary risk vectors and which testing approaches (from the list of large-test types) mitigate each one.

## Key Concepts
- **Hyrum's Law** (reintroduced): the effective user contract includes all observable behaviors, not just the documented API — meaning unit tests, however thorough, can't cover behaviors nobody anticipated specifying.
- **Vacuum effect**: unit tests deliberately eliminate real dependencies, network, and data chaos for speed/reliability — which also means they can't catch bugs that only emerge from that chaos.
- **Consumer-driven contract tests**: an external pattern (Pact, Spring Cloud Contracts) where client and provider share a contract that drives automated tests on both sides; Google doesn't use this internally due to heavy reliance on protocol buffers.
- **A/B diff (regression) testing**: sends identical traffic to an old and new version of a system and diffs the responses, rather than asserting an explicit expected output; requires human reconciliation of "expected" vs. "regression" differences.
- **A-A testing**: comparing a system against itself, used to isolate nondeterminism/noise so it can be filtered out of real A-B diffs.
- **Prober**: a functional test run continuously against production performing well-known, deterministic (usually read-only) actions as an early-warning smoke test.
- **Canary analysis**: comparing health metrics between a partially-rolled-out ("canary") version and the baseline during a staged production release.
- **DiRT (Disaster Recovery Testing)**: Google's annual company-wide fault-injection war game (e.g., simulating an earthquake isolating headquarters), distinct from continuous chaos engineering (Google's tool: Catzilla).
- **Bug bash**: a scheduled session where a cross-functional group manually, exploratorily tests a product to surface unanticipated behaviors.

## Mental Models
- Think of end-to-end test scenarios as growing combinatorially with the number of nodes (services) in the SUT graph — a small social-network example with 6 servers and 3 databases already has 14 edges; adding a photo-analysis pipeline multiplies scenarios further, so exhaustive end-to-end coverage doesn't scale and alternate strategies (chained tests, A/B diffs) become necessary.
- Think of low-fidelity doubles as compounding risk exponentially with N: if two service doubles are each only 10% accurate, the chance of a real bug slipping through is 1 − (0.1 × 0.1) = 99%. High fidelity matters more, not less, as systems get larger.
- Treat "chained tests" as a way to shrink a large end-to-end scenario into multiple smaller pairwise integration tests, using a persisted data repository to pass one test's output as the next test's input — the smallest-possible-test principle applied to a multi-hop user journey.
- Treat internal system timeouts as a test-environment tuning knob, not a fixed production constant — production hardcodes latency assumptions for a distributed topology that a single-machine SUT doesn't have; make these tunable and lower them in tests.

## Anti-patterns
- **Testing in production without considering discoverability**: the Webdriver Torso case study — automated test videos uploaded to a public (if obscure) YouTube channel were discovered and publicized by outside media before Google acknowledged them; always consider end-user/public discoverability of test data placed in production.
- **UI-to-backend end-to-end tests as the default**: multiplicative maintenance cost (brittle to look-and-feel changes, async timing issues) for both UI and backend; split at the UI/API boundary and drive backend tests through the public API instead.
- **Testing against real third-party APIs**: no public shared environment, and often a per-call cost; treat third-party dependencies as an explicit seam to double or record/replay.
- **Sleep-based waits in large tests**: same problem as in unit tests, but worse — as the test fleet gets overloaded, sleep-based tests fail more, get rerun more, and increase load further in a spiral.
- **No large-scale-change coverage for large tests**: because large tests lack standardized infrastructure, LSC tooling often can't safely run them, so they get skipped during broad refactors — accumulating hidden risk.
- **Undocumented test ownership**: without a named owner, large tests become harder to modify and slower to triage on failure — they rot.

## Code Examples
```
assertThat(response.Contains("Colossal Cave"))
```
- **What it demonstrates**: a minimal explicit assertion used in a large functional test (verifying a Google Search response for the query "xyzzy" contains an expected result) — the simplest of the large-test verification styles, alongside manual verification and A/B diff comparison.

```
verify(databaseReader, atMostOnce()).selectRecords();
```
- **What it demonstrates**: interaction testing used legitimately at large-test scope to validate a caching feature actually reduces database calls — a case where state testing can't easily express "called at most once."

## Reference Tables

| Larger test type | SUT | Data | Verification |
|---|---|---|---|
| Functional (one/more binaries) | Single-machine hermetic or cloud-isolated | Handcrafted | Assertions |
| Browser/device testing | Same as functional, via frontend | Handcrafted | Assertions |
| Performance/load/stress | Cloud-deployed isolated | Handcrafted or multiplexed from production | Diff (performance metrics) |
| Deployment configuration | Single-machine hermetic or cloud-isolated | None | Assertions (doesn't crash) |
| Exploratory | Production or shared staging | Production or known test universe | Manual |
| A/B diff (regression) | Two cloud-deployed isolated environments | Multiplexed/sampled from production | A/B diff comparison |
| UAT | Machine-hermetic or cloud-isolated | Handcrafted | Assertions |
| Probers/canary analysis | Production | Production | Assertions + A/B diff of metrics |
| Disaster recovery/chaos engineering | Production | Production + user-crafted (fault injection) | Manual + A/B diff of metrics |
| User evaluation | Production | Production | Manual + A/B diff of metrics |

| SUT type | Hermeticity | Fidelity | Typical size |
|---|---|---|---|
| Single-process | Highest | Lowest | Small |
| Single-machine | High | Medium | Medium |
| Multimachine | Medium | High | Large |
| Shared staging/production | Lowest | Highest | Large (or "in production") |

## Worked Example
A social network SUT (Figure 14-3 in the book) has two user groups, two UIs, three databases, an indexing pipeline, and six servers — 14 graph edges — and is already described as difficult to exhaustively test end-to-end. To reduce its size at a "problem boundary," the team replaces its databases with in-memory doubles and removes a server outside the actual scope of concern, shrinking it enough to plausibly fit on a single machine (a single-machine SUT). This illustrates the chapter's core cost/fidelity trade-off directly: the reduced SUT sacrifices some fidelity (in-memory DBs aren't the real datastore) in exchange for being small enough to run alongside normal compiles, links, and unit tests — "the easiest and most stable 'integration' tests for our engineers" — while a genuinely full-fidelity test of the same system would require a slower, flakier multimachine or shared-staging SUT.

## Key Takeaways
1. Use larger tests specifically to close fidelity gaps unit tests structurally can't close: unfaithful doubles, configuration drift, load behavior, unanticipated inputs, and emergent (cross-component) behavior.
2. Choose the smallest, most hermetic SUT that still delivers the fidelity the test needs — hermeticity and fidelity trade off against each other.
3. Split tests at natural seams (UI/API boundary, third-party dependency boundary) rather than writing one large end-to-end test across the whole stack.
4. A/B diff testing is Google's most common large-test pattern because it sidesteps hand-authoring explicit expected outputs, but it requires investment in noise reduction and a human approval step.
5. Give every large test an explicit, empowered owner (project lead, feature owner, or `OWNERS`-file-derived) — without ownership, large tests rot and failures take longer to resolve.
6. Make large-test failures self-diagnosing: a clear failure message, a way to trace the actual root cause across process boundaries (e.g., via request-ID tracing like Dapper), and contact info for the test's owners.
7. Drive down flakiness by reducing SUT scope first, then by replacing sleeps with event-driven waits and reactive polling, tuning internal timeouts explicitly for test environments.

## Connects To
- **Ch 11 (Testing Overview)**: revisits and deepens the ice-cream-cone antipattern and Hyrum's Law references from the overview chapter.
- **Ch 13 (Test Doubles)**: "unfaithful doubles" here is a direct continuation of the fidelity discussion and the @DoNotMock motivation from the prior chapter.
- **Ch 22 (Large-Scale Changes)**: large tests' lack of standardization is cited as a specific reason they're often skipped during LSCs.
- **Ch 9 (Code Review)**: `OWNERS` files, reused here to derive large-test ownership automatically.
- **Ch 17 (Code Search)** / **Ch 23 (Continuous Integration)**: Code Search and Kythe are the discovery tools used to find who depends on a system before/while running large tests against it (also directly reused in Ch 15's deprecation discovery tooling).
