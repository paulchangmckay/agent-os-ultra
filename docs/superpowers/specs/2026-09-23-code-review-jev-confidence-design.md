# Code-Review Confidence Check via TypeSafe/Jev

**Status:** Design approved, pending grilling pass.

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
5. Helper returns `{score, level, confidence}` as JSON.
6. Compare Jev's `level` to the subagent's self-label:
   - Same tier, or adjacent (e.g. subagent said Important, Jev leans Critical or Minor but close) → no annotation, issue passes through unchanged.
   - Off by more than one tier (e.g. subagent said Critical, Jev scores near Minor) → append a **"Confidence check"** line under that issue: `Jev scored this [level] ([confidence]) — subagent labeled it [level]. Worth a second look.`

### Failure handling

If the Jev call errors (missing/bad `TYPESAFE_API_KEY`, network failure, quota) — skip the confidence check for that issue silently, fall back to the subagent's original label. The review must never block or degrade because this check is unavailable.

### Files touched

| File | Change |
|---|---|
| `scripts/jev-score-severity.py` | **New.** Self-contained PEP 723 script (`#!/usr/bin/env -S uv run --script` + inline `dependencies = ["typesafe_sdk"]`). Takes issue text + diff snippet (stdin or argv), calls `typesafe_sdk`'s `Score`, prints `{score, level, confidence}` JSON to stdout. Reads `TYPESAFE_API_KEY` from env; exits non-zero with a clear message if missing or on API error. |
| `skills/requesting-code-review/SKILL.md` | New step after "3. Act on feedback": scope to Critical/Important issues, pull the diff snippet, call the helper, append disagreement annotations. |
| `skills/requesting-code-review/code-reviewer.md` | **Unchanged.** The subagent's prompt and rubric stay exactly as-is. |

### Credentials

`TYPESAFE_API_KEY` lives in the user's shell profile (`~/.zshrc`), not in any tracked repo file — consistent with this repo's existing preference (API keys in shell, not `settings.json`). Already configured as of this spec.

### Testing

Full TDD against the live, paid, networked Jev API isn't realistic per-run. Plan:
- Unit tests (Python `unittest`/`pytest` inline in the script or a sibling `test_jev_score_severity.py`) covering: tier-mismatch detection logic, JSON response parsing, and the "skip silently on error" path — all against a mocked HTTP/SDK response, no real network call.
- One real manual smoke test against the live API once implemented, documented in the PR description rather than run in CI.

