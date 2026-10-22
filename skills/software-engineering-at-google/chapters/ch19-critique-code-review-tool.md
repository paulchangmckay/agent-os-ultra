# Chapter 19: Critique: Google's Code Review Tool

## Core Idea
Code review tooling succeeds by supporting — never replacing — trust and human communication: Critique's design deliberately trades feature richness for simplicity, gives authors the same diff/analysis view reviewers get, and reduces scoring to a minimal, always-positive signal (LGTM / Approval / unresolved comments) so the system stays fast and unambiguous at Google's scale.

## Frameworks Introduced
- **Critique's four guiding principles**: Simplicity, Foundation of trust, Generic communication, Workflow integration.
  - When to use: evaluating or designing any code review tool's feature set.
  - How: default to *not* adding a feature if it complicates the data model for a small set of users (simplicity); trust authors to self-resolve minor comments rather than requiring re-review (trust); prefer freeform comments over rigid protocols since "communication problems are rarely solved through tooling" (generic communication); link out to specialized tools (Cider, Code Search, Rapid) rather than reimplementing them inside the review tool (workflow integration) — note the explicit rejected alternative: a unified "Code Central" tool.
- **The attention set ("whose turn" feature)**: an explicit, tool-maintained set of people a change is currently blocked on.
  - When to use: any review flow involving more than one reviewer, or asynchronous/cross-timezone collaboration.
  - How: update automatically when comments are published; render blocked usernames in bold; let users manage it manually when automation gets it wrong. Reframes review as inherently turn-based — it is always at least one specific person's turn to act.
- **Three-part change scoring**: LGTM + Approval + unresolved-comment count, deliberately kept binary/positive (no "Needs More Work" or "LGTM++").
  - When to use: designing a gatekeeping signal for mergeability.
  - How: require at least one LGTM regardless of Approval status (guarantees two pairs of eyes); let Approval represent gatekeeper sign-off separately from code-quality sign-off; make all negative feedback take the form of a concrete, addressable unresolved comment rather than an unqualified rejection.

## Key Concepts
- **Critique**: Google's primary internal code review tool, tightly integrated with Piper, Code Search, Cider, Tricorder, Rapid, and Zapfhahn.
- **Precommit review**: Critique's default mode — review happens before a change is committed to the codebase (vs. postcommit review models).
- **Snapshot**: a saved point-in-time patch of a change uploaded to Critique; diffs are computed between snapshot pairs.
- **LGTM ("looks good to me")**: reviewer stamp meaning the change meets standards and can be committed once unresolved comments are addressed.
- **Approval**: separate gatekeeper stamp meaning "I allow this to be committed" — distinct from LGTM, and every change needs an LGTM regardless of approval status.
- **Unresolved vs. resolved comments**: unresolved comments are soft requirements the author must address (by fixing code or explicitly marking resolved) before commit is unblocked; resolved comments are optional/informational.
- **GwsQ**: the tool (named after the Google Web Server team) that auto-assigns a specific reviewer from a team alias, factoring in code ownership, recent-change familiarity, and availability/timezone.
- **Tricorder integration**: static analysis findings surface directly in Critique's diff view as status chips, with click-to-preview/apply fix suggestions (detailed in Ch. 20).
- **Changelist Search**: the fast, fully-indexed search system powering Critique's customizable per-user dashboard.
- **Gerrit**: the standalone, open-source, Git-native code review tool used by Google teams (e.g., Chrome, Android) whose projects live outside the Piper monorepo; supports a richer, configurable scoring system (including a -2 veto) versus Critique's simpler model.

## Mental Models
- Think of the review-tool design space as a trade-off between simplicity and workflow integration: Critique consciously chose "many linked tools" over "one mega-tool" because embedding everything would complicate the core review experience for a marginal convenience gain.
- Treat comment "publishing" as an atomicity boundary: reviewers draft as-you-go but publish all comments together, so the author receives one coherent, complete thought rather than a stream of half-formed reactions.
- Model presubmit checks as the automated first line of gatekeeping that runs *before* a human reviewer's time is spent — cheap, fast checks catch issues early so slower human review time isn't wasted on mechanically-detectable problems.
- Use "time spent in review is time not spent coding" as the cost lens for every Critique design decision — most of the chapter's specific features (whose-turn, dashboard, side-by-side diff performance tuning) exist to shrink that cost.

## Anti-patterns
- **Unqualified negative review scores**: an earlier Critique design allowed a "Needs More Work" rating; the team removed it because negative feedback with no specific, addressable target doesn't give the author anything actionable — replaced entirely by unresolved comments, which must name something concrete to fix.
- **Building a unified "Code Central" super-tool**: explicitly considered and rejected — merging editing, reviewing, and searching into one tool was judged to sacrifice the simplicity that makes each individual tool fast and focused.
- **Requiring re-review of every minor edit regardless of change size**: contradicts the "foundation of trust" principle; Critique instead lets reviewers trust authors to handle small follow-up edits without a repeated LGTM cycle once a change is in a mostly-good state.
- **Treating comments as private/one-off instead of atomic and public**: drive-by review is explicitly allowed — "anyone can comment on changes" — rather than gating commentary behind an assigned-reviewer role.

## Reference Tables

| Review stage | What happens | Key Critique feature |
|---|---|---|
| 1. Create a change | Author uploads a snapshot; analyzers run | Diff view with whitespace/move-only toggles, Tricorder chips |
| 2. Request review | Author picks/gets assigned reviewers | GwsQ auto-assignment, reviewer-selection heuristics |
| 3. Comment | Reviewers draft and publish comments | Unresolved vs. resolved comment types |
| 4. Modify & reply | Author addresses comments, uploads new snapshots | Snapshot diffing, "Done"/"Ack" shortcuts |
| 5. Change approval | Reviewers score the change | LGTM + Approval + unresolved-comment count |
| 6. Commit | Author commits from within the tool | One-click commit button |

| Tool | Relationship to Critique |
|---|---|
| Cider | Web IDE — one click from a Critique change page to edit further |
| Code Search | Cross-reference/browsing — linked, not embedded |
| Tricorder | Static analysis — findings shown inline as diff-view chips |
| Rapid | Release packaging — linked to see if a change shipped |
| Zapfhahn | Test coverage — shown as gutter background colors in diff view |

## Worked Example
**A full review cycle for a small change.** An engineer authors a fix in their Piper workspace and uploads a snapshot to Critique, which immediately kicks off Tricorder analyzers (e.g., a linter). The author reviews their own diff and the analyzer chips first — wearing the reviewer's hat before anyone else sees it — and links the change to a tracking bug via autocomplete. Satisfied, they mail the change; GwsQ resolves the team alias to a specific available reviewer in a compatible timezone, and mailing the change triggers presubmit hooks (test suite, style/invariant checks). The reviewer opens the change from their dashboard's default "needs my attention" section (they're in the attention set, rendered in bold), reviews the intraline diff, clicks "Please fix" on one Tricorder finding, and drafts two comments — marking one unresolved, one resolved/informational — then publishes them atomically, which flips the attention set to the author. The author fixes the unresolved issue, clicks "Done," uploads a new snapshot (clearing all reviewers' per-file "reviewed" checkboxes), and replies. The reviewer, now trusting the fix given the earlier interaction, issues an LGTM plus Approval. With one LGTM, sufficient approvals, and zero unresolved comments, Critique's header turns green; the author clicks commit directly from Critique, and the change lands — after which it remains browsable via Code Search's file history for future archaeology.

## Key Takeaways
1. Trust and communication are the actual substance of code review; tooling can only reduce friction around them, never substitute for them.
2. Keep the mergeability signal minimal and unambiguous — a three-part score (LGTM/Approval/unresolved comments) scales better than a richer but more subjective rating scheme.
3. Give authors the reviewer's-eye view of their own change (diff + analyzer results) before sending it out — this alone reduces reviewer time spent on avoidable issues.
4. Make "whose turn is it" an explicit, tool-tracked state rather than an implicit social convention — this was reported as one of the highest-impact usability additions.
5. Integrate static analysis directly into the review surface (Tricorder-in-Critique) so mechanical issues are caught and even auto-fixed before a human reviewer spends time on them.
6. When your organization can't use the primary in-house tool (e.g., open-source projects outside the monorepo), a standalone tool with a richer configurable model (Gerrit) can serve a different set of tradeoffs — tool choice should match repository/governance model, not be one-size-fits-all.

## Connects To
- **Ch 9 (Code Review)**: this chapter is the tooling counterpart to Ch. 9's process discussion — the book explicitly frames Ch. 9 as "the process," this chapter as "the tool that supports it."
- **Ch 16 (Version Control and Branch Management)**: Critique's tight integration is possible specifically because Piper workspaces live in a cloud-accessible FUSE filesystem, not local-only state.
- **Ch 17 (Code Search)**: cross-reference navigation inside Critique's diff viewer is Kythe-powered, the same backend as Code Search; Code Search is also the canonical way to browse a file's review/commit history.
- **Ch 20 (Static Analysis)**: Tricorder's analyzer findings, fix suggestions, and "Please fix"/"Not useful" feedback loop are surfaced entirely through Critique's UI.
- **Ch 22 (Large-Scale Changes)**: Critique's reviewer-suggestion and dashboard-customization features are specifically noted as important for LSCs, which can touch hundreds or thousands of files atomically.
