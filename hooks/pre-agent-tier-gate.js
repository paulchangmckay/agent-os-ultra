#!/usr/bin/env node
// PreToolUse hook (matcher: Agent): hard-blocks a subagent dispatch when its
// requested model tier exceeds the max_tier declared for its subagent_type
// in config/claude-tier-limits.json. Only the two structurally-provable
// cases are capped (Explore, statusline-setup) — every other subagent_type
// is logged only, never blocked. See
// docs/superpowers/specs/2026-09-23-model-routing-design.md component B.
//
// Blocks via {decision:"block",reason} + exit 0, matching this repo's
// proven PreToolUse convention (hooks/pre-skill-gate.js) rather than the
// generic exit-code-2 mechanism — confirmed by reading the actual working
// sibling hook, not by trusting Claude Code's generic docs.

import { readFileSync, appendFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readStdin } from '../scripts/hook-input.js';

const TIER_ORDER = ['haiku', 'sonnet', 'opus', 'fable'];

let input = {};
try {
  input = JSON.parse(readStdin() || '{}');
} catch (_) {
  process.exit(0);
}

const cwd = input.cwd || process.cwd();
const subagentType = input.tool_input && input.tool_input.subagent_type;
const model = input.tool_input && input.tool_input.model;

// `model` is optional on the Agent tool. A dispatch that omits it inherits the
// agent's own default: we can't evaluate what we weren't told, so it is logged
// (model: null) but never blocked — blocking would break ordinary dispatches.
if (!subagentType) {
  process.exit(0);
}

// Limits ship next to this hook, not in the session cwd: a cwd that isn't a
// checkout root (e.g. after `cd` into a subdirectory) must not make the
// safety gate fail open. The usage log below anchors to CLAUDE_PROJECT_DIR
// (fallback cwd; convention: .wolf/hooks/shared.js) so a worktree session's
// records aren't deleted with the worktree nor scattered into subdirectories.
const limitsPath = process.env.CLAUDE_TIER_LIMITS_PATH
  || fileURLToPath(new URL('../config/claude-tier-limits.json', import.meta.url));

let limits = {};
try {
  limits = JSON.parse(readFileSync(limitsPath, 'utf8'));
} catch (_) {
  limits = {};
}

const cap = limits[subagentType];
let capped = false;
let blockReason = '';

if (cap && cap.max_tier && model) {
  const modelRank = TIER_ORDER.indexOf(model);
  const capRank = TIER_ORDER.indexOf(cap.max_tier);
  if (capRank === -1) {
    // A typo'd cap must not silently disable itself: fail closed.
    capped = true;
    blockReason = `[Claude-tier gate] config/claude-tier-limits.json has an invalid max_tier "${cap.max_tier}" for "${subagentType}" (expected one of ${TIER_ORDER.join(', ')}) — fix the config.`;
  } else if (modelRank !== -1 && modelRank > capRank) {
    capped = true;
    blockReason = `[Claude-tier gate] subagent_type "${subagentType}" is capped at "${cap.max_tier}" in config/claude-tier-limits.json, but this dispatch requested "${model}". Edit that file if the cap is wrong, or dispatch at a tier within the cap.`;
  }
}

const logPath = resolve(process.env.CLAUDE_PROJECT_DIR || cwd, '.wolf/claude-model-usage.jsonl');
const entry = {
  timestamp: new Date().toISOString(),
  session_id: input.session_id || null,
  subagent_type: subagentType,
  model: model ?? null,
  capped,
};

try {
  mkdirSync(dirname(logPath), { recursive: true });
  appendFileSync(logPath, `${JSON.stringify(entry)}\n`);
} catch (_) {}

if (capped) {
  process.stdout.write(JSON.stringify({
    decision: 'block',
    reason: blockReason,
  }) + '\n');
}

process.exit(0);
