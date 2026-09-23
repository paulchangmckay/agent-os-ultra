# Chapter 20: Static Analysis

## Core Idea
Static analysis tooling succeeds or fails on developer trust, not analytical power: a low *effective* false-positive rate, tight integration into the existing code-review workflow, and a real feedback loop between analysis authors and consumers matter more than finding every possible bug.

## Frameworks Introduced
- **The "effective false positive" concept**: an issue is an effective false positive if the developer who saw it took no positive action — regardless of whether the finding was technically correct.
  - When to use: measuring any static analysis tool's real-world usefulness, not just its textbook precision/recall.
  - How: track "Not useful" clicks vs. "Please fix" clicks per analyzer; disable or fix analyzers whose not-useful rate stays high relative to fix requests. A technically-correct-but-confusingly-worded warning, or a technically-correct-but-unimportant warning, both count against the tool the same as an outright false positive.
- **Four criteria for a new Tricorder check**: understandable, actionable/easy to fix, <10% effective false positives, potential for significant code-quality impact.
  - When to use: gating whether a proposed analyzer check should be added to Tricorder (Google's static analysis platform).
  - How: require each new check to be evaluated against all four before rollout; the overall Tricorder-wide effective false-positive rate is kept just below 5%.
- **Three key lessons for making static analysis work**: focus on developer happiness, make analysis part of the core developer workflow, empower users to contribute.
  - When to use: designing or evaluating any static analysis program, not just a specific tool.
  - How: (1) measure and act on false-positive/not-useful feedback continuously; (2) integrate into code review — the point where developers are already in a "change mindset" and naturally blocked/waiting; (3) build simple-enough APIs (e.g., Refaster's before/after snippet specification) that domain experts, not just analysis specialists, can contribute checks.

## Key Concepts
- **Static analysis**: analyzing source code (not a running program) to find bugs, antipatterns, or technical debt without execution — contrasted with "dynamic" analysis.
- **False negative**: the analysis misses an issue it was designed to catch.
- **False positive**: the analysis incorrectly flags code as having an issue.
- **Effective false positive**: a user-perceived false positive — includes both correct-but-confusing and correct-but-unimportant findings, defined by "did the developer take positive action," not by technical correctness.
- **Tricorder**: Google's static analysis platform, integrated into Critique's diff viewer as gray comment-box findings; microservices architecture with analysis servers reading code over a FUSE filesystem; processes 50,000+ code review changes/day.
- **Presubmit check**: a check that can block committing a pending change (vs. a Tricorder finding, which is advisory unless a reviewer clicks "Please fix"); includes custom-built team-specific suites in addition to base checks.
- **Compiler-integrated check**: an analysis promoted into the compiler itself as a hard build-breaking error, reserved for checks with no effective false positives and high mechanical confidence (e.g., Error Prone `ERROR`-level checks).
- **Error Prone / clang-tidy**: compiler-extension tools identifying AST-level antipatterns for Java and C++ respectively.
- **Refaster**: a Tricorder-adjacent system letting any engineer write an analyzer by specifying before/after code snippets, rather than writing analysis code directly.

## Mental Models
- Treat static analysis as operating on a strict cost-benefit ledger for developer time: "fixing a static analysis warning could introduce a bug" — for code that already works and isn't being touched, the expected value of a fix can be negative, which is why Tricorder focuses on newly-introduced warnings/edited lines rather than the whole codebase.
- Think of code review as the "sweet spot" for analysis delivery: developers are already in a change mindset, already blocked waiting on a reviewer (giving analyzers time to run even if slow), and face social/peer pressure to address flagged issues — a combination no other integration point (IDE, standalone linter) replicates as well.
- Use "anything that can be fixed automatically should be fixed automatically" as a standing design rule — automated fixes reduce both the cognitive and time cost side of the cost-benefit ledger, and formatting issues specifically should never consume human reviewer attention.
- Model the false-positive feedback loop as the actual product being maintained: user trust, once lost (as happened when the C++ linter incorrectly ran against Objective-C files, or the HTML linter had near-zero signal), is expensive to rebuild — fixing the underlying analyzer beats adding a suppression/customization escape hatch.

## Anti-patterns
- **User-level (per-developer) customization of analysis results**: Google tried this early (confidence-level settings, per-analysis suppression in Critique), removed it, and immediately got complaints — but investigating those complaints surfaced real bugs and false positives in the underlying linters themselves. Lesson: customization was hiding tool defects, not expressing legitimate preference variation. Fixed instead: project-level customization only, which keeps every team member's view of a project's analysis results consistent.
- **Reporting compiler warnings instead of errors**: developers reliably ignore warnings; Google's policy is binary per check — either break the build (error) or don't surface it in compiler output at all. Go takes this furthest, making things other languages treat as warnings (unused imports/variables) into hard errors.
- **Retroactively flagging pre-existing issues in stable, working code**: except for high-severity categories (security, significant bugs), fixing old warnings in code that isn't being touched has unclear benefit and real risk (e.g., "fixing" dead code by wiring it back in reintroduces untested paths).
- **Shipping an analyzer before establishing a feedback channel**: pre-feedback-loop, "many developers would just ignore analysis results they did not understand" — the fix in one real case was as simple as rewording a confusing diagnostic message, which alone stopped a recurring stream of "Not useful" bug reports.

## Reference Tables

| Integration point | Timing / cost constraint | Notes |
|---|---|---|
| Code review (Tricorder in Critique) | Minutes acceptable — author already blocked waiting | Primary integration point; ~50,000+ changes/day |
| Presubmit | Runs at mail-out and at commit time | Can block commit; supports team-specific custom suites |
| Compiler | Must be fast, can't slow the build | Reserved for zero-effective-false-positive, correctness-only checks |
| IDE | <1s, ideally <100ms | Messier due to multi-IDE support burden; some analyses inaccurate on partial code |
| Code browsing (whole-codebase view) | No latency pressure | Used for security holistic views and cleanup planning |

| Tricorder new-check criterion | Requirement |
|---|---|
| Understandable | Any engineer can understand the output |
| Actionable and easy to fix | Guidance on how to fix, even if the fix itself takes effort |
| Effective false positives | Under 10% |
| Impact | Significant potential effect on code quality, even if not correctness-affecting |

## Worked Example
**Fixing a diagnostic message instead of the analyzer.** Error Prone shipped a check flagging calls to a Guava `printf`-like function that accepted only the `%s` format specifier, whenever the number of passed arguments didn't match the number of `%s` specifiers. The Error Prone team began receiving weekly "Not useful" bug reports insisting the check was wrong — the argument count matched the specifier count from the reporters' point of view. The actual root cause: users were passing other `printf`-style specifiers (like `%d`) that the function silently didn't support, so the "specifier count" they were counting by eye didn't match what the analyzer was actually checking against. The fix required no change to the underlying logic at all — the team changed the diagnostic text to explicitly state that the function accepts only `%s`, and the stream of "Not useful" reports stopped immediately. This is presented as the concrete case for why message clarity is itself a determinant of a check's effective false-positive rate, independent of the check's technical correctness.

**A compiler-check promotion in practice.** A hashing bug pattern — `(int) (f ^ (f >>> 32))` on a field typed as `long`, silently becoming a no-op right-shift-by-32 if the field's type ever narrows to `int` — was fixed in 31 places across Google's codebase before the corresponding Error Prone check was turned on as a hard compiler error. This illustrates the compiler-integration workflow: clean up every existing instance first (via a codebase-wide MapReduce-style compiler pass with auto-generated fixes), commit that cleanup, then flip the check on so no new instance can ever be committed again without breaking the build.

## Key Takeaways
1. Optimize for the *effective* false-positive rate (did the developer act?), not just technical precision — perception and message clarity are part of the tool's real accuracy.
2. Integrate static analysis into code review first; it's the point of maximum developer receptivity (already blocked, already in a change mindset, under mild peer pressure).
3. Auto-fix everything you can, especially style/formatting — human reviewer time should never go toward mechanically-detectable issues.
4. Prefer project-level customization over user-level customization; per-user suppression tends to hide real tool defects rather than express legitimate variance.
5. Reserve compiler-error-level enforcement for checks with zero effective false positives and high mechanical confidence; never emit ambiguous compiler *warnings*, since they get ignored.
6. Build and actively maintain a feedback channel (e.g., "Not useful" / "Please fix" buttons) between analysis consumers and analysis authors — this loop is what earns and preserves user trust at scale.
7. Empower non-specialist domain experts to contribute checks via simple APIs (e.g., before/after snippet-based tools like Refaster) rather than restricting analyzer authorship to a central tools team.

## Connects To
- **Ch 9 (Code Review)**: static analysis findings surfacing in the review tool is presented as a way to help the review process itself scale, not just to catch bugs independently of review.
- **Ch 17 (Code Search)**: analysis results (e.g., dead-code detection) are surfaced directly when browsing files in Code Search, reusing it as a distribution platform.
- **Ch 19 (Critique: Google's Code Review Tool)**: Tricorder is presented from the tool-architecture side here; Ch. 19 shows the same integration from the reviewer/author UI side (status chips, fix-preview, "Please fix").
- **Ch 22 (Large-Scale Changes)**: static analysis is called out as integral to the API deprecation process, preventing backsliding during codebase-wide migrations; team-specific presubmits can be skipped via `CLEANUP=` markers specifically to not obstruct LSCs.
- **Ch 23 (Continuous Integration)**: presubmit checks and compiler-break detection are described as running both pre-commit (presubmit) and post-commit (caught by CI) as a two-layer safety net.
