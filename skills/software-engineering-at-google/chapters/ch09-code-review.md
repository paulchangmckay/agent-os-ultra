# Chapter 9: Code Review

## Core Idea
Code review at Google is mandatory for essentially every change and is optimized to scale via three independently-satisfiable approval "bits" (correctness/comprehension, ownership, readability), small single-reviewer changes, and heavy automation — delivering not just bug-catching but comprehension checks, consistency, knowledge sharing, psychological benefits, and a historical record.

## Frameworks Introduced
- **The three approval "bits"**: (1) LGTM from a peer for correctness and comprehension, (2) approval from a directory **owner** that the change belongs in their codebase, (3) approval from someone with language **readability** that it meets style/best-practice standards.
  - When to use: every code change at Google needs all three satisfied before submission.
  - How: any combination is valid — a single reviewer can hold all three (author-is-owner-with-readability needs only one peer LGTM); a junior engineer without ownership/readability needs a separate owner+readability approver.
- **Code Review Best Practices**: be polite and professional; write small changes (~200 LOC); write good change descriptions; keep reviewers to a minimum (one primary reviewer); automate wherever possible.
  - When to use: as the default operating rules for running code review at scale.
  - How: cap changes at digestible size, give first-line summaries plus a why-focused description, seek exactly one LGTM rather than unanimous consent, and offload formatting/linting/testing to presubmit automation.
- **Types of Code Reviews**: Greenfield reviews, behavioral changes/improvements/optimizations, bug fixes and rollbacks, refactorings/large-scale changes (LSCs) — each with a different review focus.
  - When to use: calibrating what a reviewer should check based on the change's category.
  - How: greenfield reviews check design/API/test/ownership completeness; behavioral changes check test coverage and whether the change actually improves the codebase (deletions count!); bug fixes should stay narrowly scoped and update tests; LSC reviews should flag only concerns specific to their own code, not the underlying automated tool.

## Key Concepts
- **LGTM ("looks good to me")**: the tagged state signaling a reviewer's consent to a change; only one LGTM is required by default.
- **Precommit review**: Google's review model — review happens before the change enters the codebase.
- **OWNERS files**: hierarchical, directory-scoped lists of engineers with approval rights and stewardship responsibility ("ownership," not possession) over that part of the codebase.
- **Readability**: a Google-specific certification (per language) that an engineer's code and reviews conform to that language's style guide and best practices — not mere comprehension.
- **Critique**: Google's custom code review tool (Gerrit is used mainly for open-source/Git-based projects).
- **Presubmit**: automated checks (tests, linters, formatters) run when a change is sent for review, rejecting the change before it reaches a human reviewer if problems are found.
- **PTAL**: "please take another look" — the convention for civilly reopening a review after addressing (or contesting) feedback.

## Mental Models
- Treat code as a liability, not an asset: even necessary code is a maintenance burden, so the review's first question is whether new code is warranted at all ("if you're writing it from scratch, you're doing it wrong").
- Separate "the customer is always right" (comprehension feedback — always address confusion, even if it just means explaining better) from author-deference on approach (don't force a different but equally valid design purely on reviewer preference).
- Treat each review comment as a TODO item: it must be addressed (agreed, explained, or countered) before being marked resolved — silence isn't resolution.
- Think of separating the three approval roles as a scaling optimization: it lets a peer focus purely on correctness/comprehension while an owner focuses purely on "does this fit my directory's long-term maintenance," without either duplicating the other's effort.

## Anti-patterns
- **Seeking unanimous consent from many reviewers**: diminishing returns after the first LGTM — the cost of additional reviewers quickly outweighs their marginal insight.
- **Large, sprawling changes**: harder to review, more likely to hide bugs, and delay dependent work; Google caps typical changes around 200 lines and expects initial feedback within a working day.
- **Scope creep in bug fixes**: fixing unrelated issues in the same change makes both regression-testing and rollback significantly harder.
- **Piecemeal reviewer feedback**: reviewers dribbling out unrelated new comments after each round frustrates authors and stalls momentum.
- **Re-litigating design decisions during code review**: design belongs in a design review/design doc process (Ch 10) before code exists — a code review is not that forum.
- **Treating LSC-generated changes like hand-written changes**: flagging concerns about the underlying tool/process (rather than the specific code) in an individual LSC review doesn't scale and should be escalated out-of-band instead.

## Reference Tables

| Review type | Primary focus | Key check |
|---|---|---|
| Greenfield (new code) | Long-term maintainability | Matches approved design; full API test coverage; OWNERS file exists; adequate comments |
| Behavioral change/optimization | Improvement vs. regression | Updated tests in CI; performance benchmarks if relevant; is a deletion possible instead? |
| Bug fix / rollback | Narrow correctness | Stays scoped to the bug; adds/updates the test that should have caught it; stays small enough to safely roll back |
| Refactoring / LSC | Applicability, not design | Correctness of the mechanical change only; concerns about the tool itself go to an LSC oversight group, not the individual review |

## Worked Example
**The six-step review flow, applied to a junior engineer's change.** (1) The author writes a change, snapshots it as a patch + description in Critique. (2) They self-review/apply automated fixes, then mail it to a reviewer. (3) The reviewer opens the diff and comments — some requiring resolution, some purely informational ("FYI"). (4) The author revises and re-uploads, replying to each comment (steps 3–4 repeat as needed). (5) Once satisfied, the reviewer marks LGTM. (6) The author may now commit — *provided* the other two approval bits are also satisfied. Suppose this junior engineer has neither ownership nor readability for the touched directory: they still only need one peer's LGTM for correctness/comprehension, but the change additionally needs a directory owner's approval (that it belongs there) and a readability-holder's approval (that it meets style standards) — which, in practice, often collapses into the *same* second reviewer, since owners frequently hold readability too. Contrast this with a tech lead who owns the directory and already holds readability in that language: for an identical change, they need only the one peer LGTM, because they implicitly satisfy the other two bits themselves.

## Key Takeaways
1. Optimize the process for small, fast, single-reviewer changes — this is what lets code review scale to tens of thousands of engineers without becoming a bottleneck.
2. Separate correctness/comprehension (LGTM) from code ownership from style/readability — each check can be satisfied by different people, or collapsed into one, depending on who's involved.
3. Defer to the author on design approach; be strict (customer-is-always-right) on comprehension — if a reviewer is confused, that confusion will recur for every future reader.
4. Automate everything mechanical (formatting, linting, tests) via presubmit so human reviewers spend their attention on correctness and design, not nits.
5. Match your review depth to the change type: greenfield needs design/test rigor; bug fixes need narrow scope; LSC reviews need narrow, code-specific scrutiny only.

## Connects To
- **Ch 3**: Knowledge Sharing — the readability process (mentoring new engineers into a language's conventions) is administered largely through code review.
- **Ch 8**: Style Guides and Rules — readability approval exists specifically to enforce the style guide covered in the previous chapter.
- **Ch 16**: Version Control and Branch Management — OWNERS files rely on the hierarchical directory-tree structure of Google's single repository.
- **Ch 19**: Critique — the tool underlying the process described in this chapter.
- **Ch 20 / Ch 22**: Static Analysis and Large-Scale Changes — presubmit automation and LSC-specific review norms extend directly from this chapter's automation and refactoring sections.
