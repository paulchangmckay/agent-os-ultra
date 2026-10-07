import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('./pre-agent-tier-gate.js', import.meta.url));

// CLAUDE_TIER_LIMITS_PATH is set explicitly on every run (spawnSync inherits
// process.env, so nothing may accidentally read the real config). Defaults to
// the tmp cwd's seeded file; pass a path to override, or null to leave it
// unset and exercise the hook's default lookup.
// CLAUDE_PROJECT_DIR is likewise pinned (empty = log next to payload.cwd) so a
// run inside a real Claude session never writes into the real .wolf/.
function run(payload, limitsPath, projectDir = '') {
  const env = { ...process.env, CLAUDE_PROJECT_DIR: projectDir };
  const resolved = limitsPath === undefined
    ? join(payload.cwd || tmpdir(), 'config/claude-tier-limits.json')
    : limitsPath;
  if (resolved === null) delete env.CLAUDE_TIER_LIMITS_PATH;
  else env.CLAUDE_TIER_LIMITS_PATH = resolved;
  return spawnSync('node', [SCRIPT], { input: JSON.stringify(payload), encoding: 'utf8', env });
}

function withTmpCwd(fn) {
  const cwd = mkdtempSync(join(tmpdir(), 'agent-tier-gate-test-'));
  try {
    fn(cwd);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
}

function seedConfig(cwd, config) {
  mkdirSync(join(cwd, 'config'), { recursive: true });
  writeFileSync(join(cwd, 'config/claude-tier-limits.json'), JSON.stringify(config));
}

const DEFAULT_LIMITS = {
  Explore: { max_tier: 'sonnet' },
  'statusline-setup': { max_tier: 'haiku' },
};

test('blocks Explore dispatched at opus (exceeds sonnet cap)', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const result = run({
      session_id: 'sess-1', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore', model: 'opus' },
    });
    assert.equal(result.status, 0);
    const out = JSON.parse(result.stdout);
    assert.equal(out.decision, 'block');
    assert.match(out.reason, /Explore/);
    assert.match(out.reason, /claude-tier-limits\.json/);
  });
});

test('blocks Explore dispatched at fable (fable ranks above opus, also exceeds sonnet cap)', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const result = run({
      session_id: 'sess-2', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore', model: 'fable' },
    });
    assert.equal(result.status, 0);
    const out = JSON.parse(result.stdout);
    assert.equal(out.decision, 'block');
  });
});

test('allows Explore dispatched at exactly its cap (sonnet)', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const result = run({
      session_id: 'sess-3', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore', model: 'sonnet' },
    });
    assert.equal(result.status, 0);
    assert.equal(result.stdout.trim(), '');
  });
});

test('allows statusline-setup at haiku, blocks it at sonnet', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const allowed = run({
      session_id: 'sess-4', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'statusline-setup', model: 'haiku' },
    });
    assert.equal(allowed.stdout.trim(), '');

    const blocked = run({
      session_id: 'sess-4', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'statusline-setup', model: 'sonnet' },
    });
    const out = JSON.parse(blocked.stdout);
    assert.equal(out.decision, 'block');
  });
});

test('never blocks an uncapped subagent_type, even at fable', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const result = run({
      session_id: 'sess-5', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'general-purpose', model: 'fable' },
    });
    assert.equal(result.status, 0);
    assert.equal(result.stdout.trim(), '');
  });
});

test('logs every allowed and blocked call to .wolf/claude-model-usage.jsonl', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    run({ session_id: 'sess-6', cwd, tool_name: 'Agent', tool_input: { subagent_type: 'Explore', model: 'opus' } });
    run({ session_id: 'sess-6', cwd, tool_name: 'Agent', tool_input: { subagent_type: 'general-purpose', model: 'fable' } });

    const logPath = join(cwd, '.wolf/claude-model-usage.jsonl');
    assert.equal(existsSync(logPath), true);
    const lines = readFileSync(logPath, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
    assert.equal(lines.length, 2);
    assert.equal(lines[0].subagent_type, 'Explore');
    assert.equal(lines[0].capped, true);
    assert.equal(lines[1].subagent_type, 'general-purpose');
    assert.equal(lines[1].capped, false);
  });
});

test('does not crash when config/claude-tier-limits.json is missing — defaults to uncapped but still logs', () => {
  withTmpCwd((cwd) => {
    const result = run({
      session_id: 'sess-7', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore', model: 'opus' },
    }, join(cwd, 'does-not-exist.json'));
    assert.equal(result.status, 0);
    assert.equal(result.stdout.trim(), '');
    const logPath = join(cwd, '.wolf/claude-model-usage.jsonl');
    const entry = JSON.parse(readFileSync(logPath, 'utf8').trim());
    assert.equal(entry.capped, false);
  });
});

test('finds the checked-in limits next to the hook when cwd has no config and no env override is set', () => {
  withTmpCwd((cwd) => {
    const result = run({
      session_id: 'sess-9', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore', model: 'opus' },
    }, null);
    assert.equal(result.status, 0);
    const out = JSON.parse(result.stdout);
    assert.equal(out.decision, 'block');
  });
});

test('does not block or crash on malformed JSON stdin', () => {
  const result = spawnSync('node', [SCRIPT], {
    input: '{not valid json', encoding: 'utf8',
    env: { ...process.env, CLAUDE_PROJECT_DIR: '' },
  });
  assert.equal(result.status, 0);
  assert.equal(result.stdout.trim(), '');
});

test('the usage log lands in CLAUDE_PROJECT_DIR, not the session cwd', () => {
  withTmpCwd((projectDir) => {
    withTmpCwd((cwd) => {
      seedConfig(cwd, DEFAULT_LIMITS);
      run({
        session_id: 'sess-anchor', cwd,
        tool_name: 'Agent',
        tool_input: { subagent_type: 'general-purpose', model: 'opus' },
      }, undefined, projectDir);
      const entry = JSON.parse(readFileSync(join(projectDir, '.wolf/claude-model-usage.jsonl'), 'utf8').trim());
      assert.equal(entry.subagent_type, 'general-purpose');
      assert.equal(existsSync(join(cwd, '.wolf/claude-model-usage.jsonl')), false);
    });
  });
});

test('no-ops (no output, no log) when subagent_type is missing from tool_input', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const result = run({ session_id: 'sess-8', cwd, tool_name: 'Agent', tool_input: {} });
    assert.equal(result.status, 0);
    assert.equal(result.stdout.trim(), '');
    assert.equal(existsSync(join(cwd, '.wolf/claude-model-usage.jsonl')), false);
  });
});

test('a cap with an invalid max_tier (typo) fails closed with a clear reason, and is logged capped:true', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, { Explore: { max_tier: 'Sonnet' } });
    const result = run({
      session_id: 'sess-typo', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore', model: 'haiku' },
    });
    assert.equal(result.status, 0);
    const out = JSON.parse(result.stdout);
    assert.equal(out.decision, 'block');
    assert.equal(
      out.reason,
      '[Claude-tier gate] config/claude-tier-limits.json has an invalid max_tier "Sonnet" for "Explore" (expected one of haiku, sonnet, opus, fable) — fix the config.',
    );
    const entry = JSON.parse(readFileSync(join(cwd, '.wolf/claude-model-usage.jsonl'), 'utf8').trim());
    assert.equal(entry.capped, true);
  });
});

test('a cap with an invalid max_tier does not block a dispatch that omits model', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, { Explore: { max_tier: 'Sonnet' } });
    const result = run({
      session_id: 'sess-typo2', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore' },
    });
    assert.equal(result.stdout.trim(), '');
  });
});

test('a dispatch that omits model is not blocked but is logged with model:null and capped:false', () => {
  withTmpCwd((cwd) => {
    seedConfig(cwd, DEFAULT_LIMITS);
    const result = run({
      session_id: 'sess-10', cwd,
      tool_name: 'Agent',
      tool_input: { subagent_type: 'Explore' },
    });
    assert.equal(result.status, 0);
    assert.equal(result.stdout.trim(), '');
    const entry = JSON.parse(readFileSync(join(cwd, '.wolf/claude-model-usage.jsonl'), 'utf8').trim());
    assert.equal(entry.subagent_type, 'Explore');
    assert.equal(entry.model, null);
    assert.equal(entry.capped, false);
  });
});
