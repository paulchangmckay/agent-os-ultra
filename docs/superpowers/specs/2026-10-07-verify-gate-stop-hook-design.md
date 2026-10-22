# verify-gate: Stop hook that blocks session end until verification passes

**Status:** Approved
**Date:** 2026-10-07

## Context

`skills/verification-before-completion/SKILL.md` already states the rule —
no completion claims without fresh verification evidence — but it is purely
a prose/trust-based skill. The model is supposed to self-invoke it before
claiming a task is done. Nothing mechanically enforces this.

A survey of `hooks/` (Explore agent, this session) confirmed no existing
Stop hook blocks anything. All four current entries in `settings.json`'s
`Stop` array are notify/log/reflect only:

- `langsmith-plugin/bundle/stop.js` — tracing
- an `osascript` notification (async)
- a worktree-cleanup reminder (async)
- `hooks/openwolf-cron-gate.js cerebrum-reflection` — periodic reflection

This spec adds a fifth: a Stop hook that can actually refuse to let a
session end when a project-declared verification command is failing.

This was scoped out of a broader review of
[garrytan/gstack](https://github.com/garrytan/gstack), which ships an
equivalent (`gstack-verify-gate`) as one of five patterns judged worth
porting. The other four — issue-text trust envelope, egress ledger,
content-fingerprint-bound review evidence, and gbrain code-indexing — are
separate specs, built in that order.

Reusable patterns found in this repo and adopted here:

- `hooks/lib/gate-marker.js` — lock/stale-marker helpers (modeled, not
  reused directly, since this hook's state is keyed by repo path, not
  session + skill name).
- `hooks/pre-skill-gate.js` — the `{"decision":"block","reason":...}`
  stdout contract for actually halting an event.
- `hooks/openwolf-cron-gate.js` — `spawnSync`-based command execution with
  a bounded timeout.

Reading a verify command out of a CLAUDE.md marker comment has no prior art
in this repo — confirmed novel during the same survey.

## Design

### Marker convention

A single line in a project's `CLAUDE.md`:

```
<!-- claude-verify: <shell command> -->
```

One marker per repo, first match wins. No multi-line commands, no shell
metacharacter restrictions beyond what `spawnSync` with `shell: true`
already allows — this is intentionally the same trust surface as any other
command a user puts in their own CLAUDE.md.

For this repo, the marker is:

```
<!-- claude-verify: node --test hooks/ -->
```

`node --test hooks/` is already the de facto way these hooks are tested
(confirmed by running it directly: 7/7 pass on `pre-skill-gate.test.js`).
As part of this work, add a `"test": "node --test hooks/"` script to
`package.json` for convenience — no behavior change, just a documented
entry point.

### Trust model

Hooks bypass the permission system entirely, so a command declared in
CLAUDE.md must not run on sight. New CLI mode on the hook script itself:

```
node hooks/stop-verify-gate.js --trust
```

Run manually, once, inside the repo being opted in. It:

1. Reads the repo's CLAUDE.md, extracts the marker.
2. Computes `sha256(command string)`.
3. Writes `{repoPath, commandHash, trustedAt}` to that repo's state file
   (see below).

On every Stop, the hook re-extracts the marker and recomputes the hash. If
no state file exists, or the hash doesn't match the stored one (including
"the marker text changed since trust was granted"), the hook blocks once
with a message telling the user to run `--trust` (or re-run it after
reviewing the new command). This is a trust gate, not a verify failure —
it does not touch the retry counter.

### State storage

```
~/.claude/state/verify-gate/<sha256(repoPath)>.json
```

```json
{
  "repoPath": "/Users/paulmckay/some-project",
  "commandHash": "...",
  "trustedAt": "2026-10-07T12:00:00Z",
  "retryCount": 0,
  "lastSessionId": "..."
}
```

Keyed by a hash of the repo's absolute path, stored outside any repo. This
makes it work for any project without needing a `.wolf/`-style directory or
a `.gitignore` entry in the target repo. If a repo is moved or deleted, its
state file is simply orphaned — no cleanup needed, no harm done.

### Fail/retry behavior

On every Stop event, in order:

1. **No marker in CLAUDE.md** → exit 0 immediately. No state read or
   written. This is the no-op path for every repo that hasn't opted in.
2. **Marker present, untrusted or hash mismatch** → block once (see Trust
   model above). `retryCount` untouched.
3. **Marker present, trusted** → `spawnSync` the command with a fixed
   120-second timeout.
   - **Exits 0** → reset `retryCount` to 0, exit 0 (session ends normally).
   - **Non-zero exit, or spawn error (command not found, timeout)** →
     increment `retryCount`.
     - If `retryCount < 3`: block Stop, show the command's stdout/stderr
       tail (last ~50 lines) and the exit code.
     - If `retryCount >= 3`: let Stop through anyway, print a loud
       `STILL RED — verify command has failed 3 times, yielding` warning,
       reset `retryCount` to 0.

`retryCount` is scoped per `lastSessionId`: if the incoming `session_id`
differs from the stored one, treat it as a fresh count (0) before applying
the increment — so a new session doesn't inherit a previous session's
near-yield state, but repeated Stop attempts within one stuck session do
progress toward the yield.

### Error handling

- Malformed or unparseable marker text → treated as absent. Never blocks,
  never crashes Stop.
- Any hook-internal error (state file read/parse failure, missing
  CLAUDE.md, etc.) → fail open, exit 0. The hook must never be the reason a
  session can't end due to a bug in the hook itself — only the declared
  verify command's own failure should ever cause a block.
- `spawnSync` errors (ENOENT, timeout) are treated identically to a
  non-zero exit code for retry-counting purposes, with the error message
  shown in place of stderr.

### Registration

This session cannot edit `settings.json` directly (blocked by the user's
auto-mode classifier, confirmed in prior sessions — CLAUDE.md §3). This
spec's implementation ends with handing the user the exact JSON snippet to
paste into the `Stop` array themselves:

```json
{ "hooks": [{ "type": "command", "command": "node $CLAUDE_PROJECT_DIR/hooks/stop-verify-gate.js", "timeout": 125 }] }
```

(125s hook timeout to comfortably exceed the 120s command timeout inside
it.)

## Testing

`hooks/stop-verify-gate.test.js`, `node --test`, mirroring the existing
hook test style:

1. No marker in CLAUDE.md → no-op (exit 0, no state write).
2. Marker present, no state file → block with trust instructions.
3. Marker present, state file has a different `commandHash` (stale trust)
   → block with trust instructions.
4. Trusted, command exits 0 → pass through, `retryCount` reset.
5. Trusted, command exits non-zero → block, `retryCount` incremented to 1.
6. Trusted, command fails for the 3rd consecutive time in the same session
   → yield with the STILL RED warning, `retryCount` reset to 0.
7. Trusted, command fails, but `session_id` differs from `lastSessionId` →
   treated as retry 1, not a continuation of the prior session's count.
8. Malformed marker (e.g. missing closing `-->`) → no-op.
9. Path-traversal-shaped `session_id` or `repoPath` → safe (mirrors the
   existing case in `pre-skill-gate.test.js`), no directory escape when
   building the state file path.
10. `--trust` CLI mode: reads marker, writes state file with correct hash.

## Out of scope

- A configurable timeout per repo (fixed at 120s for v1).
- Multiple markers / multiple verify commands per repo.
- Auto-registration into `settings.json` (handed to the user per
  Registration above).
- Any UI for browsing/clearing state files (manual `rm` under
  `~/.claude/state/verify-gate/` if ever needed).
