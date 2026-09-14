# Local-Model Routing Enforcement — Design Spec

**Date:** 2026-09-08
**Status:** Draft, pending grilling pass

## Problem

`model-routing` skill's Gate 0 (added 2026-09-08, PR #85) tells Claude to route certain task categories to a local LLM server before Claude-tier routing applies. Gate 0 is currently pure prompt policy — nothing verifies it fires, nothing records when it doesn't, and there is no visibility into how much usage (tokens, call volume) each model — local or Claude-tier — actually handles or what it's used for.

A same-day spot-check of Gate 0 (three tasks: log-line triage, boilerplate code draft, reasoning sanity-check) found:
- Triage and code-draft routes work for real tasks.
- The reasoning-check route (`deepseek-r1-0528-qwen3-8b`) failed twice, timing out at 90s then 180s with zero response. Root cause, isolated with a `max_tokens: 5` probe: the model loads in ~1.2s but generates unbounded chain-of-thought with no token cap, never reaching a final answer within either timeout.
- A quantized model (`llama3.2-3b`) didn't follow a requested strict output format (asked for ERROR/OK, returned "WARN" for one line) — confirms the model-routing skill's own quantization caveat.

## Goals

1. Fix the workflow gap that caused the R1 failure (no `max_tokens` cap, hand-written JSON payloads per call).
2. Build a deterministic, enforcement-independent audit trail of every local-model call that actually happens.
3. Give Claude a way to self-report when a Gate-0-eligible task was *not* routed locally, plus a periodic backstop sweep for what wasn't caught live.
4. Track token usage broken down by model — both local and Claude-tier — so usage volume and purpose are visible on demand.

## Non-goals

- No hard-blocking enforcement (a false-positive block on legitimate Claude-tier work is worse than an unenforced miss going unnoticed for a cycle).
- No changes to `token-ledger.json` or the `generate_token_report` cron action — both are scoped to Claude's own file-I/O token estimation, unrelated to per-model usage, and daemon-owned/not extensible with custom logic.
- No changes to `langsmith-plugin` (a third-party submodule) — its `Stop`/`SubagentStop` hooks are a working precedent to model after, not something to modify.
- No standing periodic usage report for now — on-demand only.

## Architecture

Four independent components:

### 1. Local-model helper script (`scripts/local-model-call.sh`)

Replaces hand-written curl + JSON-payload-file calls (the workflow used during today's spot-check) with a single reusable command.

- **Interface:** `scripts/local-model-call.sh <model> <prompt-file> [--max-tokens N] [--temperature N] [--category TAG]`. Prompt is read from a file, not a shell argument — avoids all quoting/escaping hazards for multi-line or quote-containing prompts (the exact problem hand-written `-d '{"...}'` calls have). `--category` is optional, validated against a fixed enum matching the `model-routing` skill's Gate 0 categories (`triage`, `boilerplate-draft`, `pre-summarize`, `vision-ocr`, `retrieval`, `reasoning-check`) — an unrecognized value is rejected with a clear error, same discipline as the existing `SAFE_NAME` validation pattern in `hooks/`. Fixed enum chosen over freeform to keep the usage report's per-category counts meaningful (freeform text would fragment "triage" / "log triage" / "log-triage" into separate buckets). Passed through verbatim into the command line so the Gate 0 hook (component 2) can parse it back out for tagging.
- **JSON construction:** via `jq -n --arg` to safely embed the prompt content — never manual string interpolation into JSON.
- **Defaults:** `max_tokens` defaults to 512 unless overridden. This directly fixes the R1 failure mode found today — an uncapped call can no longer hang indefinitely.
- **Timeout:** a `curl -m` cap (default 120s, overridable) so a hung call fails fast with a clear error instead of blocking the Bash tool call.
- **Output:** extracts `.choices[0].message.content` via `jq` on success; on failure (non-2xx, timeout, invalid JSON) prints the raw response/error to stderr and exits non-zero.
- **Scope:** chat completions only (`/v1/chat/completions`) — covers triage, boilerplate-draft, pre-summarize, vision/OCR, reasoning-check. Verified mechanically that embeddings (`/v1/embeddings`) returns a different shape (`data[]` instead of `choices[]`, no `completion_tokens`); image generation almost certainly differs further. Both remain manual/hand-written calls, out of scope for this helper — they need fundamentally different output extraction (a vector, an image) that doesn't fit a generic "print text content" script.
- **Testing:** `shellcheck` (existing pre-commit gate) plus a live run confirming the `max_tokens` cap prevents the R1 hang.

### 2. Gate 0 audit-log hook (`hooks/post-local-model-log.js`)

A deterministic, always-on record of every local-model call that actually happens — independent of whether it went through the helper script or a raw `curl`, so it can't be silently bypassed by forgetting to use the helper.

- **Wiring:** `PostToolUse`, `matcher: "Bash"` (broad, cheap match — filtering happens in-script, same pattern as `pre-skill-gate.js`'s `Skill` matcher).
- **Match logic:** regex test against `tool_input.command` for either a direct `curl ... localhost:1234` pattern or an invocation of `local-model-call.sh`. No match → no-op, exits immediately.
- **On match:** parses `tool_response.output` as JSON (the API response body) to extract `model`, `usage.prompt_tokens`, `usage.completion_tokens`. Both fields verified top-level across every local endpoint shape checked (chat completions and embeddings alike), so this hook logs any local-model call — including embeddings/image-gen calls made manually outside the helper script's scope — without needing endpoint-specific parsing. Parses `--category <value>`-style tagging from the command string if present (the helper script should support an optional `--category` flag for this).
- **Failure case:** if the response isn't valid JSON (failed/timed-out call), still append an entry with `usage: null, error: true` — a failed call is itself useful audit data (see the R1 finding above), not something to drop.
- **Log:** appends one JSON line per match to `.wolf/local-model-log.jsonl`: `{timestamp, session_id, command, model, category, usage, error}`.
- **Testing:** one matching Bash call confirmed to produce a log line; one non-matching call confirmed to produce none.

### 3. Miss-tracking convention (no new code)

Detecting a *miss* — a Gate-0-eligible task that didn't route locally — requires judgment a hook can't make. Two complementary paths, both feeding the existing `.wolf/observations.md` log via `scripts/wolf-observation-log.js` (no schema change needed — the existing `skill-improvement` type's `skill`/`issue`/`improvement` fields map directly onto this):

- **Self-report in the moment:** when Claude completes a Gate-0-eligible task without routing it locally, it logs an observation immediately: `type: 'skill-improvement'`, `skill: 'model-routing'`, `issue: <what happened>`, `improvement: <proposed fix>`. Added as an explicit instruction in the `model-routing` skill.
- **Periodic sweep backstop:** `session-reflect` Phase 3 gets one added instruction — cross-check `.wolf/local-model-log.jsonl` entries from the session against what the session actually did, and log anything not already self-reported.

### 4. Claude-tier usage tracking (`hooks/post-stop-usage-log.js`, `hooks/post-subagent-stop-usage-log.js`)

Modeled on `langsmith-plugin`'s existing `Stop`/`SubagentStop` transcript-reading pattern (verified working precedent — reads `transcript_path` from hook stdin, not from the hook payload directly, since payloads don't carry usage inline).

- **Wiring:** `Stop` (sync, `timeout: 120`) and `SubagentStop` (`async: true`, `timeout: 60`) hooks — matching `langsmith-plugin`'s existing sibling hooks on these same two events exactly, the house convention for this event pair. Our parse is far cheaper (69ms measured) than langsmith's turn-merging logic, so these are generous headroom, not a tight budget.
- **Stop hook:** reads the session transcript at `transcript_path`, extracts `message.model`/`message.usage` for every turn, and **recomputes and overwrites** one session-keyed entry with fresh per-model totals — no cursor/checkpoint file. Verified mechanically: parsing a real 890-line transcript took 69ms, negligible even repeated after every turn. Trades away turn-by-turn history (only latest per-session totals are kept) for removing an entire failure mode (corrupt/missing cursor state) — acceptable since the goal is usage-by-model, not usage-by-turn.
- **SubagentStop hook:** reads the subagent's transcript plus its sibling `.meta.json` (which carries `agentType` and the dispatch `description` — the subagent's actual purpose, already written by Claude at dispatch time, no extra tagging needed).
- **Log:** both append to `.wolf/claude-model-usage.jsonl`: `{timestamp, session_id, model, tokens: {input, output}, agentType?, description?}`. Main-thread turns have no `agentType`/`description` — a raw conversation turn doesn't carry a task category the way a dispatched subagent does; main-thread usage rolls up to session totals only, not per-purpose.
- **Testing:** trigger a real turn and a real subagent dispatch, confirm correct entries land in the log.

### Unified report (`scripts/model-usage-report.js`)

Reads both `.wolf/local-model-log.jsonl` and `.wolf/claude-model-usage.jsonl`, aggregates by model, and prints call count / total tokens / sample purposes across local and Claude tiers in one on-demand view. No scheduling — run manually when wanted.

## Resolved during grilling

- **Stop hook mechanism:** recompute-and-overwrite per-session totals on every firing, not an append-only cursor-marker file. Verified mechanically (69ms to parse a real 890-line transcript) that the performance concern the cursor was solving doesn't exist at realistic scale — dropping it removes an entire failure mode (corrupt/missing cursor) for free. Trade-off accepted: only latest per-session totals are kept, not turn-by-turn history, which matches the stated goal (usage-by-model, not usage-by-turn).
- **Helper script scope:** chat completions only. Verified mechanically that `/v1/embeddings` returns a different response shape (`data[]`, no `completion_tokens`) than chat completions (`choices[]`); image generation almost certainly differs further. Embeddings/image-gen calls stay manual, out of scope for this helper. The Gate 0 audit hook is unaffected by this boundary — verified `model`/`usage.prompt_tokens` are top-level in both shapes checked, so it logs any local-model call regardless of which endpoint it hit.
- **`--category` tagging:** fixed enum matching the `model-routing` skill's Gate 0 categories (`triage`, `boilerplate-draft`, `pre-summarize`, `vision-ocr`, `retrieval`, `reasoning-check`), rejecting anything else. Freeform text would fragment the usage report's per-category counts.
- **Stop/SubagentStop hook timing:** `Stop` sync with `timeout: 120`; `SubagentStop` `async: true` with `timeout: 60` — matches `langsmith-plugin`'s existing sibling hooks on these same two events exactly (the house convention for this event pair), with generous headroom given the 69ms measured parse cost.
- **Log rotation:** none in v1. Lightweight JSONL append logs at realistic call volumes don't warrant rotation infrastructure before the problem actually exists.

No open items remain; ready for `writing-plans`.
