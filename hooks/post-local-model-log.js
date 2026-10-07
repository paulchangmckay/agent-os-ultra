#!/usr/bin/env node
// PostToolUse hook (matcher: Bash): deterministic audit log for local-model
// routing (component A). Fires on every Bash call; no-ops unless the
// command matches a direct curl to a local model server or an invocation
// of scripts/local-model-call.sh.
//
// Two different sources of truth depending on call shape: a raw curl
// command's tool_response.output genuinely is the raw JSON body, so it's
// parsed directly. scripts/local-model-call.sh deliberately prints only
// the extracted answer text to stdout (so piping its output gives a clean
// answer, not a JSON blob) — for script invocations this instead reads the
// diagnostic file the script writes on every call
// (.wolf/.local-model-call-last-response.json), which has ground truth for
// model/backend/category/resolved_via/usage/error. See
// docs/superpowers/specs/2026-09-23-model-routing-design.md component A.
//
// SCRIPT_RE is deliberately loose (it also matches a command that merely
// mentions the filename). The diagnostic is what makes that safe: it is
// single-use (deleted once logged) and must be fresh (< 5 minutes old), so a
// mention-only command, or a call that failed before the script started,
// finds no usable diagnostic and logs nothing.
//
// Path anchoring: only the diagnostic file is cwd-relative, because the
// script and this hook must agree on it and the script only knows the
// session cwd. The .jsonl log is written only by this hook, so it anchors to
// CLAUDE_PROJECT_DIR (fallback: cwd).
//
// Known limitations, not bugs: there is ONE diagnostic slot per session cwd,
// so a loop of several script calls inside a single Bash command logs only the
// LAST call, and two Bash calls running truly in parallel can race on the slot.
// A call started with run_in_background is logged late and mis-attributed
// (PostToolUse fires at launch, before the script writes its diagnostic; the
// next matching command within the freshness window then consumes it), and
// freshness counts from script exit, so a real call followed by >5 minutes of
// other work in the same Bash command is dropped.

import { appendFileSync, mkdirSync, readFileSync, statSync, unlinkSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { readStdin } from '../scripts/hook-input.js';

const RAW_CURL_RE = /curl\b[^\n]*localhost:(1234|11434)/;
const SCRIPT_RE = /(^|[\s;&|("'/])local-model-call\.sh\b/;
const MAX_COMMAND_LENGTH = 500;
const DIAG_MAX_AGE_MS = 5 * 60 * 1000;

let input = {};
try {
  input = JSON.parse(readStdin() || '{}');
} catch (_) {
  process.exit(0);
}

const command = input.tool_input && input.tool_input.command;
if (!command) process.exit(0);

const isRawCurl = RAW_CURL_RE.test(command);
const isScriptCall = SCRIPT_RE.test(command);
if (!isRawCurl && !isScriptCall) process.exit(0);

const cwd = input.cwd || process.cwd();
const truncatedCommand = command.length > MAX_COMMAND_LENGTH
  ? `${command.slice(0, MAX_COMMAND_LENGTH)}...[truncated]`
  : command;

let entry;

if (isScriptCall) {
  const diagPath = resolve(cwd, '.wolf/.local-model-call-last-response.json');
  let mtimeMs;
  try {
    mtimeMs = statSync(diagPath).mtimeMs;
  } catch (_) {
    process.exit(0); // no diagnostic: the script never ran
  }
  if (Date.now() - mtimeMs > DIAG_MAX_AGE_MS) {
    try { unlinkSync(diagPath); } catch (_) {}
    process.exit(0); // leftover from an earlier run whose hook never fired
  }
  let diag = {};
  try {
    diag = JSON.parse(readFileSync(diagPath, 'utf8'));
  } catch (_) {
    diag = {};
  }
  try { unlinkSync(diagPath); } catch (_) {}
  entry = {
    timestamp: new Date().toISOString(),
    session_id: input.session_id || null,
    command: truncatedCommand,
    model: diag.model ?? null,
    backend: diag.backend ?? null,
    category: diag.category ?? null,
    resolved_via: diag.resolved_via ?? null,
    usage: diag.usage ?? null,
    error: diag.error ?? true,
    forced: diag.forced ?? false,
  };
} else {
  const portMatch = command.match(RAW_CURL_RE);
  const backend = portMatch ? (portMatch[1] === '1234' ? 'lmstudio' : 'ollama') : null;
  const output = (input.tool_response && input.tool_response.output) || '';

  let model = null;
  let usage = null;
  let error = false;

  try {
    const parsed = JSON.parse(output);
    model = parsed.model ?? null;
    usage = parsed.usage ?? null;
  } catch (_) {
    error = true;
  }

  entry = {
    timestamp: new Date().toISOString(),
    session_id: input.session_id || null,
    command: truncatedCommand,
    model,
    backend,
    category: null,
    resolved_via: 'explicit',
    usage,
    error,
    forced: false,
  };
}

// Anchored to the project dir, not cwd: hooks always run from the main
// checkout, and a cwd-relative log would land in a worktree (deleted with it)
// or in a subdirectory .gitignore doesn't cover. Convention: .wolf/hooks/shared.js.
const logPath = resolve(process.env.CLAUDE_PROJECT_DIR || cwd, '.wolf/local-model-log.jsonl');

try {
  mkdirSync(dirname(logPath), { recursive: true });
  appendFileSync(logPath, `${JSON.stringify(entry)}\n`);
} catch (_) {}

process.exit(0);
