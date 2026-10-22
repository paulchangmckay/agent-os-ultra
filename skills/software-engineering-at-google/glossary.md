# Glossary — Software Engineering at Google

**Always Be Deciding / Always Be Leaving / Always Be Scaling** — Ben Collins-Sussman's three leadership mantras for leading at scale: keep making trade-off decisions on ambiguous problems, build an org that works without you present, and proactively manage your own scaling responsibility (Ch 6)

**Artifact-based build system** — A build system organized around declared build artifacts and their dependencies (vs. arbitrary tasks); scales and parallelizes better than task-based systems (Ch 18)

**Beyoncé Rule** — "If you liked it, you should have put a test on it" — if a behavior matters enough to protect, it needs an automated test, not a manual check (Ch 11)

**Bias is the default** — The premise underlying Ch4's equity argument: absent deliberate correction, systems and teams default to encoding the biases of their builders (Ch 4)

**Compute as a Service** — A standardized, managed abstraction for running production workloads, letting software be adapted once to a distributed environment rather than per-team infrastructure being rebuilt repeatedly (Ch 25)

**Continuous Delivery (CD)** — The practice of keeping software always releasable and shipping small, frequent, flag-guarded changes evaluated against real production reality (Ch 24)

**Continuous Integration (CI)** — The practice of automatically verifying every integration (build + test) as early as possible to catch problematic changes fast (Ch 23)

**Critique** — Google's internal code review tool; emphasizes tight tool integration and an explicit "attention set" to reduce reviewer friction (Ch 19)

**DAMP (Descriptive And Meaningful Phrases)** — The preferred alternative to DRY specifically inside test code; favors independently-readable tests over shared abstraction (Ch 12)

**Dependency (as a contract)** — A relationship with give-and-take obligations on both provider and consumer sides; providers must be clear about what they promise to hold stable over time (Ch 21)

**Fake** — A lightweight but behaviorally faithful test double, maintained by the owner of the real implementation; preferred over stubs/mocks when a real implementation can't be used directly (Ch 13)

**GSM (Goals-Signals-Metrics)** — Framework for selecting measurement metrics: define the Goal metric-free, identify Signals that indicate the goal is met, then pick traceable Metrics (Ch 7)

**Hyrum's Law** — With a sufficient number of users of an API, all observable behaviors of the system — not just the documented contract — will eventually be depended upon by somebody (Ch 1)

**Large-Scale Change (LSC)** — An organizational process for making sweeping, cross-codebase changes as many small automatable commits rather than one traditional refactor, which breaks down at scale (Ch 22)

**One-Version Rule** — Policy that only one version of any given internal dependency exists in the build at once, removing "which version should I depend on?" as a per-engineer decision (Ch 16)

**Programming vs. Software Engineering** — Programming produces code for the moment; software engineering extends that to the maintenance of that code across its full, often much longer, useful life span (Ch 1)

**Psychological Safety** — The foundational precondition for a knowledge-sharing culture: people must feel safe admitting what they don't know before any structured knowledge tooling can work (Ch 3)

**QUANTS** — Framework for covering all dimensions of engineering productivity when selecting metrics: Quality of code, Attention, iNtellectual complexity, Tempo, Satisfaction (Ch 7)

**SemVer (Semantic Versioning)** — A lossy human-risk-estimate encoded as a version number; useful as a heuristic but not a substitute for actual CI/testing evidence of compatibility (Ch 21)

**Static Analysis** — Automated analysis of source code (without executing it) to catch bugs, antipatterns, and technical debt, most effective when integrated directly into the code review workflow (Ch 20)

**Stub / Mock** — Test doubles that supply canned responses or verify interactions rather than real behavior; both trade fidelity for speed but risk brittleness by encoding implementation details, especially mocks used for interaction testing (Ch 13)

**Sustainability** — A codebase's capacity to respond to changes in dependencies, technology, or requirements over its expected life span, whether or not that capacity is exercised (Ch 1)

**Test Scope** — How much code a test is intended to validate (e.g. one method vs. a whole system), distinct from test size (Ch 11, Ch 12)

**Test Size** — The resources a test consumes and what it's allowed to do (e.g. network access, disk access); one of Google's two primary test-classification axes alongside scope (Ch 11)

**Trunk-Based Development** — Committing to a single shared trunk/head instead of long-lived branches; empirically tied to high-performing engineering organizations per DORA/Accelerate research (Ch 16)
