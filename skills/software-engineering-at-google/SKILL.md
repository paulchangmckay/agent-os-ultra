---
name: software-engineering-at-google
description: "Knowledge base from \"Software Engineering at Google\" by Titus Winters, Tom Manshreck, and Hyrum Wright. Use when applying Google's engineering practices for code review, testing strategy, dependency management, CI/CD, technical leadership, or software sustainability at scale, studying the book, or referencing its concepts."
---

<!-- argument-hint: [topic, framework name, or chapter number] -->

# Software Engineering at Google
**Authors**: Titus Winters, Tom Manshreck, Hyrum Wright (O'Reilly) | **Pages**: ~602 | **Chapters**: 25 | **Generated**: 2026-09-13

## How to Use This Skill

- **Without arguments** — load core frameworks for reference
- **With a topic** — ask about `testing`, `code review`, `dependency management`, or another indexed topic; I find and read the relevant chapter
- **With chapter** — ask for `ch12`; I load that specific chapter
- **Browse** — ask "what chapters do you have?" to see the full index

When you ask about a topic not covered in Core Frameworks below, I will read
the relevant chapter file before answering.

---

## Core Frameworks & Mental Models

**Software engineering ≠ programming.** Programming produces code for the moment; software engineering is programming integrated over the code's full life span, including maintenance. Life spans of short- vs. long-lived code differ by a factor of ~100,000x, so "best practice" only makes sense relative to a stated time horizon. (Ch1)

**Hyrum's Law.** With enough users of an API, every observable behavior — not just the documented contract — becomes something somebody depends on. Use this to explain why "just fix it, nobody uses that" is rarely true at scale, and why deprecation is harder than building. (Ch1, Ch15, Ch21)

**Sustainability over cleverness.** A codebase is sustainable when it *can* respond to changes in dependencies, tech, or requirements for its expected life span — whether or not you currently choose to. Design and rule-making should optimize for this, not for short-term velocity. (Ch1)

**Data + assumption + precedent + argument, not "because I said so."** Google's decision-making culture favors data-backed rules, but rarely achieves pure data-only decisions — weight data highest, be ready to change direction when data changes. (Ch1, Ch8)

**GSM + QUANTS for measurement.** Pick metrics via Goals→Signals→Metrics (define the goal metric-free first), and check coverage across QUANTS (Quality, Attention, iNtellectual complexity, Tempo, Satisfaction) so improving one productivity axis doesn't silently hurt another. Use whenever someone proposes a single headline productivity number. (Ch7)

**Leadership = Always Be Deciding / Leaving / Scaling.** Leading at scale means continuously making trade-off calls on ambiguous problems (Deciding), building an org that works without your constant presence (Leaving), and proactively managing your own scaling limits (Scaling). (Ch6)

**Beyoncé Rule: "If you liked it, you should have put a test on it."** Anything worth protecting needs an automated test — manual verification doesn't survive scale or turnover. Pairs with size (resource/permission footprint) and scope (how much code is validated) as the two axes for classifying tests. (Ch11, Ch12)

**Test-double preference ladder: real > fake > stub > mock.** Prefer a real implementation; fall back to a maintained fake; avoid stubs and especially interaction-testing mocks, which encode implementation details and break under refactors that don't change behavior. Use DAMP (Descriptive And Meaningful Phrases), not DRY, when sharing test setup code. (Ch12, Ch13)

**One-Version Rule + trunk-based development.** Remove "which version should I depend on?" as a per-engineer decision — pin one internal version org-wide, and default to trunk-based development over long-lived branches (DORA/Accelerate-backed). Never depend on "latest" for external dependencies; pin explicitly. (Ch16, Ch18, Ch21)

**Dependencies are contracts, SemVer is a lossy estimate.** A dependency relationship has obligations on both sides. SemVer encodes a human's risk guess, not a verified fact — trust actual CI/testing evidence over the version number alone when deciding to upgrade. (Ch21)

**LSCs: refactoring breaks at scale, so make change-making itself a habit.** Traditional one-PR refactors don't work across a codebase the size of Google's. A Large-Scale Change process — many small, automatable, independently reviewable commits — is the alternative, and the org capability to run LSCs should be treated as a standing muscle, not a one-off project. (Ch22)

**Ship small, ship flagged, ship against reality.** Continuous Delivery favors flag-guarded, staged rollouts validated against real production signal over synthetic pre-launch testing; presubmit CI should carry fast/reliable tests, post-submit the slower/less-deterministic ones. (Ch23, Ch24)

---

## Chapter Index

| # | Title | Key Frameworks |
|---|-------|----------------|
| [ch01](chapters/ch01-what-is-software-engineering.md) | What Is Software Engineering? | Hyrum's Law, sustainability, time-horizon dependent best practices |
| [ch02](chapters/ch02-how-to-work-well-on-teams.md) | How to Work Well on Teams | Genius Myth, bus factor, working-style awareness |
| [ch03](chapters/ch03-knowledge-sharing.md) | Knowledge Sharing | Psychological safety, readability program |
| [ch04](chapters/ch04-engineering-for-equity.md) | Engineering for Equity | Bias is the default, inclusive design |
| [ch05](chapters/ch05-how-to-lead-a-team.md) | How to Lead a Team | Servant leadership, delegation, TLM role |
| [ch06](chapters/ch06-leading-at-scale.md) | Leading at Scale | Always Be Deciding/Leaving/Scaling |
| [ch07](chapters/ch07-measuring-engineering-productivity.md) | Measuring Engineering Productivity | GSM, QUANTS |
| [ch08](chapters/ch08-style-guides-and-rules.md) | Style Guides and Rules | Data-backed rules, automated enforcement |
| [ch09](chapters/ch09-code-review.md) | Code Review | Optimize for the reader, review-type mapping |
| [ch10](chapters/ch10-documentation.md) | Documentation | Audience-first writing, doc freshness |
| [ch11](chapters/ch11-testing-overview.md) | Testing Overview | Test size vs. scope, Beyoncé Rule |
| [ch12](chapters/ch12-unit-testing.md) | Unit Testing | Public-API testing, DAMP over DRY |
| [ch13](chapters/ch13-test-doubles.md) | Test Doubles | Real > fake > stub > mock ladder |
| [ch14](chapters/ch14-larger-testing.md) | Larger Testing | SUT/Data/Action/Verification |
| [ch15](chapters/ch15-deprecation.md) | Deprecation | Advisory vs. compulsory deprecation |
| [ch16](chapters/ch16-version-control-and-branch-management.md) | Version Control and Branch Management | One-Version Rule, trunk-based dev |
| [ch17](chapters/ch17-code-search.md) | Code Search | Trust via completeness, low-latency search |
| [ch18](chapters/ch18-build-systems-and-build-philosophy.md) | Build Systems and Build Philosophy | Artifact-based vs. task-based builds |
| [ch19](chapters/ch19-critique-code-review-tool.md) | Critique: Google's Code Review Tool | Attention set, tool integration |
| [ch20](chapters/ch20-static-analysis.md) | Static Analysis | Review-integrated analysis, false-positive tuning |
| [ch21](chapters/ch21-dependency-management.md) | Dependency Management | Dependency-as-contract, SemVer limits |
| [ch22](chapters/ch22-large-scale-changes.md) | Large-Scale Changes | LSC process |
| [ch23](chapters/ch23-continuous-integration.md) | Continuous Integration | Presubmit/post-submit split |
| [ch24](chapters/ch24-continuous-delivery.md) | Continuous Delivery | Flag guards, staged rollout |
| [ch25](chapters/ch25-compute-as-a-service.md) | Compute as a Service | Standardized compute abstraction |

## Topic Index

- **Beyoncé Rule** → ch11
- **Bias / equity** → ch04
- **Branch management** → ch16
- **Build systems** → ch18
- **CI/CD** → ch23, ch24
- **Code review** → ch09, ch19
- **Code search** → ch17
- **Compute infrastructure** → ch25
- **Dependency management** → ch16, ch21
- **Deprecation** → ch15
- **Documentation** → ch10
- **DAMP vs. DRY** → ch12
- **Flag-guarded rollout** → ch24
- **GSM / QUANTS (metrics)** → ch07
- **Hyrum's Law** → ch01, ch15, ch21
- **Knowledge sharing** → ch03
- **Large-Scale Changes (LSC)** → ch22
- **Leadership** → ch05, ch06
- **One-Version Rule** → ch16
- **Psychological safety** → ch03
- **SemVer** → ch21
- **Static analysis** → ch20
- **Style guides / rules** → ch08
- **Sustainability** → ch01
- **Test doubles (fakes/stubs/mocks)** → ch13
- **Test size vs. scope** → ch11, ch12
- **Testing (unit)** → ch12
- **Testing (larger/integration)** → ch14
- **Trunk-based development** → ch16
- **Version control** → ch16

## Supporting Files

- [glossary.md](glossary.md) — all key terms with definitions
- [patterns.md](patterns.md) — all techniques and design patterns
- [cheatsheet.md](cheatsheet.md) — quick reference tables and decision guides

---

## Scope & Limits

This skill covers the book content only. For hands-on implementation in your codebase,
combine with project-specific tools. For topics beyond this book, check related skills
or ask the agent directly.
