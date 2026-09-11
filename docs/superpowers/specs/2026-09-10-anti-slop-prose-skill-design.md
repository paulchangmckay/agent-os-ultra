# Anti-Slop Prose Skill — Design Spec

Date: 2026-09-10
Status: Approved, pending grilling

## Purpose

Port the editorial-fidelity discipline from [udaysharmadev/Not-Ai](https://github.com/udaysharmadev/Not-Ai) (MIT licensed) into a new global skill, `anti-slop-prose`, that edits AI-drafted prose for purpose, specificity, and voice while treating the source material as a hard constraint rather than raw material to embellish. Scope: prose only (email, Slack/notification text, essays, LinkedIn/social posts, business-analysis docs). UI/visual anti-slop guidance stays where it already lives.

The user's goal: close a real, verified gap. A full grep of `~/.claude` plus `~/brain` (gbrain) found exactly one existing anti-slop mechanism — [shared-references/anti-slop-tells.md](../../../skills/shared-references/anti-slop-tells.md), used only by `design-taste-frontend` and `redesign-existing-projects` — and it is scoped entirely to frontend visual design (color, layout, typography, a handful of banned marketing words). Nothing in the current setup does source-ledger fidelity, mechanical-tell detection, or genre-aware editorial review for prose.

## Anti-goals

- Do NOT frame this as a detector-bypass or "make it sound human" tool. Not-Ai explicitly rejects that framing and so does this port: the skill never predicts or optimizes for an AI-detector score, never claims to prove authorship, never adds typos/slang/fake imperfections to simulate a person.
- Do NOT duplicate the AI-vocabulary ban list that already lives in `shared-references/anti-slop-tells.md` — that file stays UI-scoped; this skill gets its own `references/vocabulary.md`, cross-linked rather than merged.
- Do NOT auto-fire on code, code comments, or a plain conversational reply to the user — only on prose with an audience outside the current conversation.
- Do NOT build a corpus/benchmark harness in this pass (Phase 2 is diagnostics-only, confirmed with the user) — no `.wolf/` directory changes, no fixture corpus, no results tracking.
- Do NOT add a `voice-match` mode or any other capability outside what Phase 1 scoped (source ledger, genericity counterfactual, vocabulary-tier flags, mechanical-pattern checks, em-dash rule, all 9 genre profiles). YAGNI — add voice-match later if actually needed.

## File layout

```
skills/anti-slop-prose/
  SKILL.md                          # editorial contract, modes, quality gate
  scripts/
    policy.py                       # 9 genre profiles, ported from Not-Ai's policy.py
    gate.py                         # deterministic pre-output checker, ported from Not-Ai's gate.py
    metrics.py                      # Phase 2: read-only density/readability diagnostics
  references/
    vocabulary.md                   # tier-1/tier-2 AI-vocabulary review guidance
    mechanical-tells.md             # template transitions, empty framing, participial openers
    why-word-swapping-fails.md      # genericity counterfactual, correct editing order
```

`scripts/` and `references/` are bundled inside the skill folder (confirmed with the user) rather than at the repo-root `scripts/` directory that `debt-ledger` uses — this skill is self-contained and Python (stdlib-only, zero dependencies), unlike `debt-ledger`'s project-local Node.js script, so bundling keeps it a single portable unit and easy to diff against upstream Not-Ai for future updates.

Every ported file carries a one-line attribution comment: `# Adapted from udaysharmadev/Not-Ai (MIT license), https://github.com/udaysharmadev/Not-Ai`.

## SKILL.md contract

Ported near-verbatim from Not-Ai's `SKILL.md`, adjusted only to drop voice-match and to fit this repo's existing frontmatter convention (single-line `name`, `description` using YAML `>` folding, matching `debt-ledger`'s style):

- **Non-negotiable rules:** preserve facts/names/numbers/citations/the author's actual position; never invent an experience, opinion, quote, source, or sensory detail; never add mistakes/slang/filler/fake emotion to simulate a person; never optimize against or predict an AI-detector score; don't force a rewrite if the passage is already strong; keep code/equations/quotations/table data intact; bracket a missing detail instead of inventing it; never add em dashes to newly authored prose.
- **Modes:** `rewrite` (full rewrite preserving meaning), `preserve` (fewest edits needed), `diagnose` (report only, no rewrite), `from-notes` (draft from supplied facts only).
- **Writing contract, established before editing:** purpose, audience, genre (one of the 9 profiles below), register evidence, protected content — inferred silently when obvious, not interrogated out of the user.
- **Source ledger:** a four-column private ledger (fact / claim / voice / structure) separating what must survive editing from what can change, with unsupported gaps marked as bracketed prompts rather than filled in.
- **Editorial pass, worked paragraph by paragraph, not by global synonym replacement:**
  1. Find the paragraph's job (claim, event, mechanism, evidence, qualification, request) — cut or merge if it has none.
  2. Put the useful information first.
  3. Replace abstraction with supported detail, using the genericity counterfactual: could this sentence survive unchanged if the names/setting/subject were swapped? If yes, inspect it.
  4. Make agency clear — name who decided/built/observed when the source supports it.
  5. Remove empty framing ("it is worth noting that," "plays a crucial role in," etc.) without banning individual words.
  6. Repair rhythm by ear — split unrelated jobs, join choppy runs, never manufacture length variation to hit a numeric target.
  7. Keep transitions that name a real relationship; cut decorative ones.
  8. Preserve genuine uncertainty; don't inflate hedges into claims or vice versa.
  9. End on substance, not a repeated summary.
- **Genre profiles (all 9, ported as-is):** LinkedIn/social, personal essay, professional email, student project report, formal academic writing, technical documentation/README, fiction. Each carries its own register and fidelity notes from Not-Ai's `SKILL.md`; genre detection runs first, every profile still obeys the same no-invention rules.
- **Quality gate (11-point checklist):** fidelity, no invention, purpose, specificity, voice, logic, restraint, register, protected content, mechanics, em dashes — ending with a run of `scripts/gate.py` as the deterministic final check.
- **Output:** return the revised text without a long preamble; add a short disclosure note only for an assumed genre, a bracketed fact the author must supply, a material ambiguity, or a fidelity concern.

## Deterministic gate (`scripts/gate.py` + `scripts/policy.py`)

Ported as-is from Not-Ai's `plugins/not-ai/tools/not_ai_core/{gate.py,policy.py}` — dependency-free, stdlib-only Python. Behavior:

- **Hard failures (2 only):** empty output; an explicitly required `--protect` literal missing from the deliverable.
- **Review findings (everything else, never blocks delivery):** em/en dashes and curly quotes (error-severity only under an opt-in `--ascii-punctuation` flag), tier-1/tier-2 AI-vocabulary hits, mechanical transition patterns (`furthermore`, `moreover`, `in conclusion`), participial openers, repeated sentence openings, uniform sentence-length rhythm, runs of very short sentences in non-fragment-friendly genres.
- **9 genre policies** (`linkedin`, `personal`, `email`, `social`, `fiction`, `readme`, `technical`, `student`, `academic`) control which checks apply — e.g. `technical` and `academic` don't flag missing contractions or short-sentence runs the way `linkedin` does.

Invocation, run as the final step before delivering a prose deliverable:

```bash
python3 skills/anti-slop-prose/scripts/gate.py draft.txt --genre linkedin
python3 skills/anti-slop-prose/scripts/gate.py draft.txt --genre email --protect "Q3 renewal date"
```

## Trigger scope

Fires on: **any prose content that will be read by someone other than the current user in this conversation**, whether or not it is saved to a file — email drafts, Slack/notification text, essays, business-analysis docs, LinkedIn/social posts. This is confirmed as deliberately broader than `agent-stylebooks`' "must be an actual saved document" scope boundary (§2a of CLAUDE.md) — that divergence gets stated explicitly in the CLAUDE.md entry below so a future session doesn't read it as an inconsistency.

Does NOT fire on: code, code comments, or a plain conversational reply addressed to the user themself (an explanation, a status update, this spec document).

## CLAUDE.md integration

One new row in the §2 Process Layer table:

| When | Invoke |
|------|--------|
| Drafting any non-code prose with an audience outside this conversation (email, Slack/notification text, essay, business-analysis doc, social/LinkedIn post) | `anti-slop-prose` — layers *under* `brand` voice and the `iso-24495` plain-language floor, never over them (same three-layer precedence as `agent-stylebooks`, §2a: floor > voice > this skill's editorial/mechanical pass). Broader trigger scope than `agent-stylebooks`: fires even when the prose isn't saved to a file, as long as it has an audience outside this conversation. Final step: run `scripts/gate.py` before delivering. |

No new lettered subsection (unlike agent-stylebooks' §2a) — this is one self-contained skill with its own internal genre routing, not 16 skills needing a shared tiebreak table.

## Shared-reference boundary

`shared-references/anti-slop-tells.md` stays scoped to frontend visual design, used only by `design-taste-frontend` and `redesign-existing-projects`. Add one line near its top:

> For prose/writing anti-slop guidance (non-UI), see [`skills/anti-slop-prose/references/vocabulary.md`](../anti-slop-prose/references/vocabulary.md).

This keeps one source of truth per domain (UI vocabulary vs. prose vocabulary) while making the sibling reference discoverable from either direction.

## Phase 2 — diagnostics only

`scripts/metrics.py`, ported from Not-Ai's `scripts/metrics.py`: a read-only, stdlib-only measurement script reporting word/sentence/paragraph counts, nominalization density, mechanical-transition count, and Flesch-Kincaid grade for a given text file. Run manually (`python3 skills/anti-slop-prose/scripts/metrics.py draft.txt`) or as an optional extra check alongside `gate.py`. No persisted corpus, no `.wolf/` directory, no results tracking — matches `debt-ledger`'s "read-only unless the user asks to persist" pattern. No benchmark harness in this pass.

## Storage location

Global `~/.claude/skills/anti-slop-prose/` — matching `brand` and the plugin-installed `iso-24495-plain-language`, both general-purpose writing capabilities available across all projects, not scoped to one project.

## Documentation updates

1. **CLAUDE.md §2:** add the routing-table row above.
2. **`shared-references/anti-slop-tells.md`:** add the one-line cross-reference above.
3. No change needed to `brand`, `iso-24495-*`, `design-taste-frontend`, or `redesign-existing-projects` — additive only.

## Out of scope

- Voice-match mode (explicitly dropped from Not-Ai's feature set per the user's Phase-1 scope).
- Any corpus/benchmark harness, `.wolf/prose-benchmarks/` directory, or fixture pairs (Phase 2 is diagnostics-only per the user's confirmed answer).
- Modifying `shared-references/anti-slop-tells.md`'s existing UI content.
- Rewriting the gate/policy/metrics scripts in Node.js (Python stdlib-only was confirmed as the chosen language/location).
- Retrofitting past prose deliverables to the new gate.
