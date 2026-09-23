# Model Routing: Local Free-Model Dispatch + Claude-Tier Enforcement

**Status:** Grilled, ready for implementation planning
**Supersedes:** `2026-09-08-local-model-routing-enforcement-design.md`'s non-goals around hard-blocking and multi-backend support. That spec's Task 1 (`scripts/local-model-call.sh`, committed on branch `worktree-feature+86-local-model-routing-enforcement` as `862b220`) is kept and extended, not discarded. Its Tasks 2-4 (audit hook, miss-tracking convention, Claude-tier usage tracking) are absorbed into this spec's component list below.

## Problem

Two related gaps, both confirmed by direct investigation on 2026-09-22/23:

1. **Local free-model routing has no model-selection logic.** `scripts/local-model-call.sh` blind-calls one hardcoded LM Studio endpoint with a caller-supplied model name. Ollama (also running locally, port 11434) is completely unwired. Nothing decides *which* model is right for a task, and nothing stops a call from loading a model too large for this machine.
2. **Claude-tier model/effort routing is policy-only.** `CLAUDE.md` §3 and `skills/model-routing/SKILL.md` state a Haiku/Sonnet/Opus + effort policy, but no hook, script, or mechanism enforces it — confirmed via full `settings.json` hook audit (no `PreToolUse` matcher exists for `Agent`/`Task`). The policy also omits Fable entirely, despite it being a valid `Agent` `model` value.

**Hardware constraint (drives the local half):** this machine is a 16GB RAM Apple M4. Of the models actually on disk, only two fit a "won't push the laptop to its performance edge" bar:

| Model | Backend | Size | Eligible? |
|---|---|---|---|
| `llama3.2-3b` / `llama3.2:3b` | LM Studio + Ollama | 1.9GB / 3B params | ✅ |
| `nomic-embed-text` | Ollama | 274MB / 137M params (embedding-only) | ✅ |
| `llama3.1` | Ollama | 4.6GB / 8B | ❌ too large |
| `DeepSeek-R1-0528-Qwen3-8B` | LM Studio | 4.3GB / 8B | ❌ too large, and is the exact model that caused a prior unbounded chain-of-thought hang (see Gate 0 incident note in the original script's header comment) |
| `Qwen2.5-VL-7B` (vision) | LM Studio | 5.6GB / 7B | ❌ too large — only vision-capable model on the machine, so vision-ocr has no local coverage |
| `Qwen3.5` | LM Studio + Ollama | 6.1GB / 9.7B | ❌ too large |
| `Qwen2.5-Coder-14B`, `Qwen3-14B` | LM Studio | 7.8GB each / 14B | ❌ too large |

`deepseek-v4-pro:cloud` (present in `ollama list`) is excluded from the eligible pool entirely regardless of size — it's a cloud-passthrough model (`remote_host: https://ollama.com:443`), not actually local or confirmed free.

## Non-Goals

- No support for models above the 3B/small-embedding cutoff. If the user upgrades hardware or wants a specific heavier model enabled later, that's a table edit, not a redesign.
- No mechanical enforcement of Claude "effort" level — no tool parameter exists for a hook to inspect or block on. Stays policy-text-only; flagged as a gap to revisit if the harness ever exposes one.
- No LLM-as-gatekeeper judgment calls (the "local model judges Claude-tier appropriateness" approach considered and rejected — see Approaches below).
- Full semantic Claude-tier enforcement (judging whether *any* task is too complex for its assigned tier) is out of scope — only the two structurally-provable cases are hard-blocked.

## Approaches Considered

1. **Rule-based static enforcement (chosen).** Checked-in capability table for local models; hard-block only the two provable Claude-tier cases (Explore, statusline-setup); everything else audit-only. Deterministic, no added latency, no new failure modes.
2. **Local model as gatekeeper.** A cheap local model judges every `Agent` dispatch's tier-appropriateness at call time. Rejected: adds a real LLM call's latency (confirmed ~22s cold-start on this machine) to every dispatch, and the judge itself is only as reliable as a 3B model's judgment — no better than the static rules for the cases that actually matter.
3. **Static rules everywhere, no audit-only carve-out.** Force every `subagent_type` through an explicit allow-list. Rejected: most agent types (general-purpose, Plan, frontend-design, etc.) have genuinely broad scope: a static rule would false-positive block legitimate work.

## Components

### A. Local free-model routing

**`config/local-model-routing.json`** — checked in, human-edited capability table:
```json
{
  "eligible_models": {
    "llama3.2-3b": { "backends": ["lmstudio"], "size_gb": 1.9 },
    "llama3.2:3b": { "backends": ["ollama"], "size_gb": 1.9 },
    "nomic-embed-text": { "backends": ["ollama"], "size_gb": 0.27 }
  },
  "categories": {
    "triage": ["llama3.2-3b", "llama3.2:3b"],
    "boilerplate-draft": ["llama3.2-3b", "llama3.2:3b"],
    "pre-summarize": ["llama3.2-3b", "llama3.2:3b"],
    "vision-ocr": [],
    "retrieval": ["nomic-embed-text"],
    "reasoning-check": ["llama3.2-3b", "llama3.2:3b"]
  }
}
```
`vision-ocr` is intentionally empty — no eligible model covers it, so it always hard-blocks and falls back to Claude. `reasoning-check` mapping to a 3B model was grilled and kept: the category's job is catching obvious errors before they cost a Claude turn, not deep judgment — low downside if it misses something subtle, since that just surfaces one step later at Claude.

**`scripts/local-model-call.sh`** — extend with `--auto <category>`:
1. Query both `http://localhost:1234/v1/models` (LM Studio) and `http://localhost:11434/api/tags` (Ollama).
2. Filter out any Ollama entry carrying a `remote_host` field (cloud-backed, excluded regardless of table membership).
3. Intersect live models against `config/local-model-routing.json`'s list for the given category, in table order.
4. First live match wins. If the same model name is available on both backends simultaneously (e.g. `llama3.2-3b`/`llama3.2:3b`), race a short health-check (list-endpoint ping, ~3s timeout) against both and use whichever backend answers first — not a fixed preference, since either app may or may not be running on a given day. Route the call to whichever backend wins — both share the same OpenAI-compatible `/v1/chat/completions` shape (confirmed directly against Ollama), so one request-building code path serves both; only the base URL differs.
5. No match → exit 1, print the category, the table's expected list, and what's actually loaded right now. Caller can edit the table or pass an explicit `<model> <prompt-file>` to override — never silently substitutes a different (possibly oversized) model.
6. Keep existing explicit-invocation mode (`<model> <prompt-file>`) unchanged — `--auto` is additive.

**`hooks/post-local-model-log.js`** — PostToolUse/Bash, regex-matches `local-model-call.sh` invocations (pattern from the original spec), appends one line per call to `.wolf/local-model-log.jsonl`: `{timestamp, session_id, command, category, resolved_via: "auto"|"explicit", model, backend, usage, error}`. Plain `O_APPEND`, no file lock — unlike `observations.md`'s read-modify-write pattern (which needs `withLock`), this only ever appends one atomic single-line JSON write, so there's nothing to race on even under concurrent sessions.

### B. Claude-tier hard-block

**`config/claude-tier-limits.json`**:
```json
{
  "Explore": { "max_tier": "sonnet" },
  "statusline-setup": { "max_tier": "haiku" }
}
```
Tier order for comparison: `haiku < sonnet < opus < fable` (confirmed via Anthropic's official model docs, see §C — Fable 5.1 is the tier above Opus, not a sibling). A cap applies to Fable exactly like Opus: `Explore`/`statusline-setup` block both.

**`hooks/pre-agent-tier-gate.js`** — PreToolUse, matcher `Agent`. Reads `subagent_type` and `model` from the tool call. If `subagent_type` is a key in the limits file and `model` exceeds `max_tier`: deny via `{decision:"block",reason}` on stdout + exit 0 — matching this repo's proven working convention (`hooks/pre-skill-gate.js`, the hook that gates `writing-plans` behind `grilling`), not the generic exit-code-2 mechanism from Claude Code's docs. Message names the cap and the config file to edit if it's wrong. Otherwise: allow, and append to `.wolf/claude-model-usage.jsonl`: `{timestamp, session_id, subagent_type, model, capped: bool}` (plain `O_APPEND`, no lock — same reasoning as the local-model log).

**Verification gate (mechanically unverified as of this spec):** `Agent` as a `PreToolUse` matcher, `tool_input.subagent_type`/`tool_input.model`, and exit-code-2 blocking are all confirmed via Anthropic's official Claude Code docs (`code.claude.com/docs/en/sub-agents.md`), not by a live test in this session — a mid-session `settings.local.json` edit registering this exact hook did not fire, because hook config only loads at session start, which made an in-session empirical test impossible. **The first implementation task must be an end-to-end live verification**: wire the real hook into `settings.json`, start a fresh session, dispatch a real `Explore` + `opus` call, and confirm the block actually fires — before building anything else in component B on top of it.

### C. Policy text fixes

`CLAUDE.md` §3 and `skills/model-routing/SKILL.md`:
- Add a Fable row: **Fable 5.1 is the escalation tier above Opus** (confirmed via `platform.claude.com/docs/en/models/fable-5-1/overview`, 2026-09-01 release) — $10/$50 per MTok vs. Opus 5.5's $4/$20, default effort `high`, slower, 1M context. Anthropic's own guidance: start with Opus 5 for most workloads; use Fable for demanding reasoning and long-horizon agentic work, or when Opus at higher effort still falls short. Tier order: `haiku < sonnet < opus < fable`. Route to Fable only when a task has already been tried (or is clearly known to need more) than Opus at high effort — not a default, not for routine multi-file work that Opus already handles.
- Document the hard-block hook, what it catches, and how to adjust `config/claude-tier-limits.json`.
- Point to `config/local-model-routing.json` as the source of truth for which local models are in play, replacing the current vague "route via a Bash helper" language.
- Note effort-level enforcement is policy-only: the Claude API has a real `effort` parameter (confirmed in Fable 5.1's docs, including a per-message override beta), but the `Agent` tool in this harness doesn't expose it — nothing to hook into today. Revisit if that changes.

### D. Miss-tracking convention (carried forward from the 2026-09-08 spec's Task 3)

No new code. `.wolf/claude-model-usage.jsonl` only has teeth if something actually looks at it. Convention: when a session notices (in its own work or reviewing another's) a Claude-tier dispatch that looks miscategorized despite not being hard-blocked, self-report it to `.wolf/observations.md` via `scripts/wolf-observation-log.js append` (type `skill-improvement`, skill `model-routing`) the same way the Fable-guess finding from this grilling pass was logged (Observation 29). `session-reflect`'s existing Phase 3 periodic sweep is extended to also skim `.wolf/claude-model-usage.jsonl` for patterns (e.g. repeated `opus`/`fable` dispatches for a subagent_type never capped) worth raising as a new observation, on the same 7-day-fallback cadence it already uses for the skill-observation log.

## Error Handling

- Local: no covering model loaded → exit 1 with actionable detail (never falls back to an oversized or wrong model).
- Local: Ollama cold-start latency (~22s confirmed on this machine for an unloaded model) → keep the existing 120s curl timeout as-is, comment explains why.
- Claude-tier: block message always names the cap and the file to edit — never a silent denial.

## Testing

Order matters: the empirical verification gate (§B) runs first, before any other component B work, since everything else in component B depends on the `Agent`/`PreToolUse` mechanism actually working as documented.

TDD per standard flow (after the verification gate):
- `scripts/local-model-call.sh --auto`: unit tests mocking both backends' list endpoints — covers match-found, no-match (hard block), remote-backed-model exclusion, and backend-selection-when-both-serve-the-same-model-name.
- `hooks/pre-agent-tier-gate.js`: tests for capped-and-under-limit (allow), capped-and-over-limit (block), uncapped subagent_type (always allow + log).
- `hooks/post-local-model-log.js`: reuse the fixture/mock pattern already scaffolded in `docs/superpowers/plans/2026-09-08-local-model-routing-enforcement.md` for its equivalent hook.
