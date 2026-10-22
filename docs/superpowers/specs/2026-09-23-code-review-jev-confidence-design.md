# Code-Review Confidence Check via TypeSafe/Jev

**Status:** Grilled, ready for implementation planning. SDK/API path live-verified during grilling (see Verification section).

## Problem

`skills/requesting-code-review` is the live, tracked gate this repo's own process routes every PR and every subagent-driven-development task through (per `CLAUDE.md` §2's hard-gate table). Today, one dispatched subagent (`code-reviewer.md`'s template) does everything in a single prose pass: it finds issues *and* self-labels severity (Critical/Important/Minor) *and* gives a merge verdict. There is no independent check on whether a self-labeled "Critical" is actually warranted — severity is whatever the reviewing LLM asserts, with no calibrated signal behind it.

(A separate, more elaborate confidence-scoring pipeline exists in `plugins/marketplaces/claude-plugins-official/plugins/code-review/commands/code-review.md` — an 8-step recipe that dispatches a Haiku agent per flagged issue against a hand-written 0/25/50/75/100 rubric. That plugin is **not enabled** in `settings.json`'s `enabledPlugins` and never fires. It was the original target for this work; investigation confirmed it's dead code from this repo's perspective, so this spec targets the live gate instead.)

## Goal

Add an independent, calibrated confidence check on top of the existing severity labels for Critical and Important issues, using TypeSafe's Jev `Score` primitive — without changing what the reviewing subagent does or removing the existing self-labeling.

## Non-Goals

- Not replacing the subagent's severity labeling. It keeps doing exactly what it does today.
- Not scoring Minor issues — not worth the extra call.
- Not touching the disabled marketplace plugin at all.
- Not building a shared Python dependency file for this repo — this is the first Python script in `scripts/`, and stays self-contained.
- Not blocking the review pipeline if the Jev call fails — this is an added signal, never a new point of failure for the gate itself.

## Design

### Data flow

1. `code-reviewer` subagent returns its Issues list exactly as today (Critical/Important/Minor, file:line, explanation).
2. Orchestrating session (following `requesting-code-review/SKILL.md`'s new step) filters to Critical + Important issues.
3. For each, it runs `git diff <BASE_SHA>..<HEAD_SHA> -- <file>` scoped to the issue's line range to get the relevant diff snippet.
4. It pipes the issue's stated explanation + that diff snippet into `scripts/jev-score-severity.py`, which calls Jev's `Score` primitive with `criteria` = the same three tier-descriptions already written in `code-reviewer.md`'s Output Format section (Critical/Important/Minor, verbatim — single source of truth, no duplicated rubric).

   The diff snippet's line range comes from the issue's own `File:line` citation — a format `code-reviewer.md`'s template already requires ("For each issue: File:line reference", demonstrated in its example output as `index-conversations:1-31`). Parsed with a simple `<path>:<line>(-<line>)?` regex. If an issue's citation doesn't match that shape, skip the confidence check for that issue only (same "never block the gate" philosophy as an API failure) rather than guessing at a range.

   The "diff snippet" itself is the **post-change file content at HEAD_SHA**, padded ±15 lines (clamped to file bounds) around the cited range — not a parsed diff hunk. Chosen over hunk-parsing during grilling: trivial to extract reliably with plain line numbers (`sed -n 'START,ENDp'` against `git show HEAD_SHA:<file>`), and gives Jev surrounding context a bare hunk might cut off. Trade-off accepted: Jev sees what the code *is*, not what changed — reasonable since severity is a property of the resulting code, not the edit.
5. Helper returns `{score, level, confidence}` as JSON. `level` is derived as `round(score)` mapped through Jev's own `legend` (e.g. `score=1.77` → index `2` → "Bugs, security issues, data loss risks, broken functionality" → Critical) — `score` is a continuous position between level indices, not a discrete tier on its own, confirmed against a live API call during grilling (see Verification below).
6. Compare Jev's `level` to the subagent's self-label:
   - Same tier, or adjacent (e.g. subagent said Important, Jev leans Critical or Minor but close) → no annotation, issue passes through unchanged.
   - Off by more than one tier (e.g. subagent said Critical, Jev scores near Minor) → append a **"Confidence check"** line under that issue: `Jev scored this [level] ([confidence]) — subagent labeled it [level]. Worth a second look.`

### Failure handling

If the Jev call errors (missing/bad `TYPESAFE_API_KEY`, network failure, quota) — skip the confidence check for that issue silently, fall back to the subagent's original label. The review must never block or degrade because this check is unavailable.

### Files touched

| File | Change |
|---|---|
| `scripts/jev-score-severity.py` | **New.** Self-contained PEP 723 script (`#!/usr/bin/env -S uv run --script` + inline `dependencies = ["typesafe_sdk"]`). Takes issue text + diff snippet (stdin or argv), calls `typesafe_sdk`'s `Score`, prints `{score, level, confidence}` JSON to stdout. Reads `TYPESAFE_API_KEY` from env; exits non-zero with a clear message if missing or on API error. |
| `skills/requesting-code-review/SKILL.md` | New step inserted *before* the existing "3. Act on feedback" (becomes step 4): scope to Critical/Important issues, pull the diff snippet, call the helper, append disagreement annotations — so annotations are visible when deciding what to fix, not after. |
| `skills/requesting-code-review/code-reviewer.md` | **Unchanged.** The subagent's prompt and rubric stay exactly as-is. |

### Credentials

`TYPESAFE_API_KEY` lives in the user's shell profile (`~/.zshrc`), not in any tracked repo file — consistent with this repo's existing preference (API keys in shell, not `settings.json`). Already configured as of this spec.

### Verification (done during grilling, 2026-09-23)

Ran the real pipeline end-to-end against the live API, not just docs:
- `uv run --script` against a PEP 723 header with `dependencies = ["typesafe_sdk"]` installs cleanly (version 0.7.1, 13 packages, ~13ms).
- `Score` and `TypeSafeClient` exist with the signatures the docs describe; `TypeSafeClient()` with no explicit `api_key` picks up `TYPESAFE_API_KEY` from the environment automatically.
- A real `system_one` call with a 3-level Critical/Important/Minor-worded `criteria` array (low-to-high order) returned `score=1.77`, `confidence=0.66`, `probabilities={0: 0.01, 1: 0.22, 2: 0.77}`, `legend={0: "...", 1: "...", 2: "..."}` — matching the response shape this spec's `level` derivation assumes.

This de-risks the implementation plan: the SDK/API half is proven, remaining work is the helper script's plumbing (diff extraction, regex parsing, error handling) and the `SKILL.md` step text.

### Testing

Full TDD against the live, paid, networked Jev API isn't realistic per-run. Plan:
- Unit tests (Python `unittest`/`pytest` inline in the script or a sibling `test_jev_score_severity.py`) covering: tier-mismatch detection logic, JSON response parsing, and the "skip silently on error" path — all against a mocked HTTP/SDK response, no real network call.
- One real manual smoke test against the live API once implemented, documented in the PR description rather than run in CI.

