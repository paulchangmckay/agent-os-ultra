---
name: model-routing
description: Use when deciding which model to route an Agent/subagent task to, whether a local model should handle it first, or when deciding whether to cap reasoning/thinking effort for a task. Elaborates on the compressed model-routing rule in CLAUDE.md Section 3.
---

# Model Routing

The `Agent` tool supports a `model` override (`sonnet`, `opus`, `haiku`, `fable`). CLAUDE.md Section 3 carries the compressed policy inline (visible every session, since dispatch decisions happen fast and mid-flow); this skill holds the reasoning and edge cases behind it.

## Gate 0: local model first

Before the Haiku/Sonnet/Opus table applies, check whether a local model (LM Studio or similar, served over an OpenAI-compatible endpoint) should handle the task instead of Claude at all.

**Route local when the task is:**
- Boilerplate drafting (code, prose, docstrings, test stubs) — local model writes the first pass, Claude reviews and edits only what's wrong
- High-volume, low-stakes classification (log-line triage, yes/no filters, field extraction) — cheap enough to run per-item without a token budget concern
- Pre-summarizing an oversized input (a large log file, PDF, or codebase dump) before it enters Claude's context
- Vision/OCR on a screenshot or scanned document — Claude receives extracted text, not the raw image, unless a judgment call is needed. Depends entirely on `config/local-model-routing.json` having an eligible model for the `vision-ocr` category — on a hardware-constrained machine this can be empty (no coverage), in which case it always falls back to Claude. Check the config before assuming this category is actually available.
- Local semantic search (embedding + retrieval) — Claude sees only the top-matching chunks, not the full corpus
- A reasoning sanity-check on a plan or math step before it reaches Claude, to catch an error before it costs a Claude turn

**Never route local — stays with Claude regardless of token cost:**
- Architecture decisions, security review, anything shipped to a user
- Ambiguous judgment calls where a wrong answer is expensive to catch later

**Mechanism:** the `Agent` tool has no path to a local endpoint — it only dispatches Claude models. Local routing means calling `scripts/local-model-call.sh --auto <category> <prompt-file>` directly, not an `Agent` dispatch — it resolves the actual model from `config/local-model-routing.json` against whichever of LM Studio/Ollama is reachable, and hard-blocks (never silently substitutes) if no eligible model for that category is available. The helper's output — not the raw input — is what enters Claude's context. Explicit `<model>` invocations are checked against `eligible_models` too. `--force` skips that check and exists only for a human deliberately overriding it — never use or suggest it without asking the user first. Run the script in the foreground, one call per Bash command: a call started with `run_in_background`, or several calls inside one command (a loop), is logged incorrectly or only in part (see the spec's diagnostic-lifecycle note).

**Before trusting a specific local model name:** query the server's own model-list endpoint rather than assuming a name from a prior session is still loaded or means what it sounds like — locally-served models get swapped, renamed, or mislabeled, and quantization measurably weakens instruction-following versus the full-precision model. Don't route real work to an unverified model.

Only work that fails this gate — or that the local model can't do reliably — proceeds to the table below.

## Quick Reference

| Model | Use for |
|---|---|
| Haiku | Mechanical subagent work: log/output inspection, single-file lookups, grep-and-report tasks, anything where the "thinking" is really just retrieval |
| Sonnet | Default — most subagent dispatches and all inline work unless one of the other rows clearly applies |
| Opus | Complex multi-file architecture or reasoning tasks: cross-cutting refactors, ambiguous root-cause debugging, design tradeoff analysis |
| Fable | Escalation above Opus for demanding reasoning and long-horizon agentic work, or when Opus at high effort has already fallen short. Not a default — $10/$50 per MTok vs. Opus 5.5's $4/$20, default effort `high`, slower. Confirmed via Anthropic's official model docs (`platform.claude.com/docs/en/models/fable-5-1/overview`), not name-based guessing — an earlier draft of this table wrongly assumed Fable was a creative-writing model. |

## Why this split

Haiku is meaningfully cheaper and faster for tasks that don't need reasoning depth — a subagent reading a build log for an error string doesn't benefit from Opus-level reasoning, it benefits from finishing fast. Reserving Opus for genuinely complex work means the cost only shows up where the extra reasoning quality actually changes the outcome.

## Effort / thinking-budget capping

Default effort for routine work. Only reach for extended/deeper thinking when a task has real branching complexity — an architectural tradeoff, a subtle bug with multiple plausible causes, a design with several interacting constraints. Reflexively invoking maximum effort on mechanical tasks (a rename, a straightforward CRUD addition, a config edit) burns thinking tokens without changing the output quality.

**Edge case:** when in doubt between Sonnet and Opus for a subagent task, default to Sonnet — it's easy to re-dispatch a single failed/unsatisfying subagent result at a higher tier than to have over-spent on every dispatch by default.

No tool-level `effort` parameter is exposed on the `Agent` tool in this harness today (the underlying Claude API has one, including a per-message override) — this section stays a judgment call, not something a hook can enforce, until that changes.
