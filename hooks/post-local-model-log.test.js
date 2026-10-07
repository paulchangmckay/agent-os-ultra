// hooks/post-local-model-log.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, utimesSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('./post-local-model-log.js', import.meta.url));

function withTmpDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'post-local-model-log-test-'));
  try {
    fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// spawnSync inherits process.env, and this suite may run inside a Claude
// session where CLAUDE_PROJECT_DIR is the real main checkout. Every run
// overrides it (empty = fall back to the payload cwd) so no test can write
// into a real .wolf/.
function runWithInput(input, projectDir = '') {
  return spawnSync('node', [SCRIPT], {
    encoding: 'utf8',
    input: JSON.stringify(input),
    env: { ...process.env, CLAUDE_PROJECT_DIR: projectDir },
  });
}

function seedDiagnostic(dir, diag) {
  mkdirSync(join(dir, '.wolf'), { recursive: true });
  writeFileSync(join(dir, '.wolf/.local-model-call-last-response.json'), JSON.stringify(diag));
}

test('no-ops and writes nothing when the command does not match anything local-model related', () => {
  withTmpDir((dir) => {
    const { status } = runWithInput({
      session_id: 'sess-1', cwd: dir,
      tool_input: { command: 'ls -la' },
      tool_response: { output: '' },
    });
    assert.equal(status, 0);
    assert.equal(existsSync(join(dir, '.wolf/local-model-log.jsonl')), false);
  });
});

test('a raw curl call parses model/usage directly from tool_response.output', () => {
  withTmpDir((dir) => {
    const responseBody = JSON.stringify({ model: 'llama3.2-3b', usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } });
    const { status } = runWithInput({
      session_id: 'sess-2', cwd: dir,
      tool_input: { command: "curl -s http://localhost:1234/v1/chat/completions -d '{}'" },
      tool_response: { output: responseBody },
    });
    assert.equal(status, 0);
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.equal(entry.model, 'llama3.2-3b');
    assert.equal(entry.backend, 'lmstudio');
    // usage is passed through unmodified (not reshaped down to a fixed
    // field set), so total_tokens survives — keeps the log's usage shape
    // consistent with the script-invocation path, which also passes the
    // diagnostic file's usage object through as-is.
    assert.deepEqual(entry.usage, { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 });
    assert.equal(entry.resolved_via, 'explicit');
    assert.equal(entry.error, false);
  });
});

test('a raw curl call to the Ollama port is tagged backend:ollama', () => {
  withTmpDir((dir) => {
    const { status } = runWithInput({
      session_id: 'sess-3', cwd: dir,
      tool_input: { command: "curl -s http://localhost:11434/v1/chat/completions -d '{}'" },
      tool_response: { output: JSON.stringify({ model: 'llama3.2:3b', usage: null }) },
    });
    assert.equal(status, 0);
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.equal(entry.backend, 'ollama');
  });
});

test('a local-model-call.sh invocation reads the diagnostic file, not tool_response.output', () => {
  withTmpDir((dir) => {
    seedDiagnostic(dir, {
      model: 'llama3.2:3b', backend: 'ollama', category: 'triage',
      resolved_via: 'auto', usage: { prompt_tokens: 8, completion_tokens: 4 }, error: false,
    });
    const { status } = runWithInput({
      session_id: 'sess-4', cwd: dir,
      tool_input: { command: 'bash scripts/local-model-call.sh --auto triage prompt.txt' },
      tool_response: { output: 'mock answer' }, // deliberately NOT JSON — proves this path ignores it
    });
    assert.equal(status, 0);
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.equal(entry.model, 'llama3.2:3b');
    assert.equal(entry.backend, 'ollama');
    assert.equal(entry.category, 'triage');
    assert.equal(entry.resolved_via, 'auto');
    assert.deepEqual(entry.usage, { prompt_tokens: 8, completion_tokens: 4 });
  });
});

test('a local-model-call.sh invocation with no diagnostic file logs nothing (the script never ran)', () => {
  withTmpDir((dir) => {
    const { status } = runWithInput({
      session_id: 'sess-5', cwd: dir,
      tool_input: { command: 'bash scripts/local-model-call.sh llama3.2-3b prompt.txt' },
      tool_response: { output: 'mock answer' },
    });
    assert.equal(status, 0);
    assert.equal(existsSync(join(dir, '.wolf/local-model-log.jsonl')), false);
  });
});

const SUCCESS_DIAG = {
  model: 'llama3.2-3b', backend: 'lmstudio', category: 'triage',
  resolved_via: 'auto', usage: { prompt_tokens: 3, completion_tokens: 2 }, error: false,
};

const DIAG_REL = '.wolf/.local-model-call-last-response.json';

const MENTION_ONLY_COMMANDS = [
  'git add scripts/local-model-call.sh',
  'cat scripts/local-model-call.sh | head',
  'shellcheck scripts/local-model-call.sh',
  'echo "see scripts/local-model-call.sh"',
];

for (const command of MENTION_ONLY_COMMANDS) {
  test(`mention-only command with no diagnostic logs nothing: ${command}`, () => {
    withTmpDir((dir) => {
      const { status } = runWithInput({
        session_id: 'sess-m', cwd: dir,
        tool_input: { command },
        tool_response: { output: '' },
      });
      assert.equal(status, 0);
      assert.equal(existsSync(join(dir, '.wolf/local-model-log.jsonl')), false);
    });
  });

  test(`mention-only command with a 10-minute-old diagnostic logs nothing and deletes it: ${command}`, () => {
    withTmpDir((dir) => {
      seedDiagnostic(dir, SUCCESS_DIAG);
      const old = new Date(Date.now() - 10 * 60 * 1000);
      utimesSync(join(dir, DIAG_REL), old, old);
      const { status } = runWithInput({
        session_id: 'sess-m', cwd: dir,
        tool_input: { command },
        tool_response: { output: '' },
      });
      assert.equal(status, 0);
      assert.equal(existsSync(join(dir, '.wolf/local-model-log.jsonl')), false);
      assert.equal(existsSync(join(dir, DIAG_REL)), false);
    });
  });
}

test('a stale (10-minute-old) diagnostic is not logged for a real invocation either, and is deleted', () => {
  withTmpDir((dir) => {
    seedDiagnostic(dir, SUCCESS_DIAG);
    const old = new Date(Date.now() - 10 * 60 * 1000);
    utimesSync(join(dir, DIAG_REL), old, old);
    runWithInput({
      session_id: 'sess-stale', cwd: dir,
      tool_input: { command: 'cd nope && bash scripts/local-model-call.sh --auto triage p.txt' },
      tool_response: { output: '' },
    });
    assert.equal(existsSync(join(dir, '.wolf/local-model-log.jsonl')), false);
    assert.equal(existsSync(join(dir, DIAG_REL)), false);
  });
});

test('the diagnostic is single-use: two runs of the hook with one fresh diagnostic log exactly one line', () => {
  withTmpDir((dir) => {
    seedDiagnostic(dir, SUCCESS_DIAG);
    const payload = {
      session_id: 'sess-once', cwd: dir,
      tool_input: { command: 'bash scripts/local-model-call.sh --auto triage p.txt' },
      tool_response: { output: 'mock answer' },
    };
    runWithInput(payload);
    assert.equal(existsSync(join(dir, DIAG_REL)), false);
    runWithInput(payload);
    const lines = readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim().split('\n');
    assert.equal(lines.length, 1);
  });
});

test('a malformed fresh diagnostic logs an error:true entry with null fields, then is deleted', () => {
  withTmpDir((dir) => {
    mkdirSync(join(dir, '.wolf'), { recursive: true });
    writeFileSync(join(dir, DIAG_REL), '{not json');
    runWithInput({
      session_id: 'sess-bad', cwd: dir,
      tool_input: { command: 'bash scripts/local-model-call.sh --auto triage p.txt' },
      tool_response: { output: '' },
    });
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.equal(entry.error, true);
    assert.equal(entry.model, null);
    assert.equal(existsSync(join(dir, DIAG_REL)), false);
  });
});

for (const command of [
  'bash scripts/local-model-call.sh --auto triage p.txt',
  './scripts/local-model-call.sh llama3.2-3b p.txt',
  'cd x && bash scripts/local-model-call.sh --auto triage p.txt',
  'LOCAL_MODEL_LMSTUDIO_URL=http://x bash scripts/local-model-call.sh --auto triage p.txt',
  'for f in a b; do bash scripts/local-model-call.sh --auto triage $f; done',
  'if bash scripts/local-model-call.sh --auto triage p.txt; then echo ok; fi',
  'time bash scripts/local-model-call.sh --auto triage p.txt',
  'timeout 60 bash scripts/local-model-call.sh --auto triage p.txt',
  'env X=1 bash scripts/local-model-call.sh --auto triage p.txt',
  'bash -x scripts/local-model-call.sh --auto triage p.txt',
  'bash "scripts/local-model-call.sh" --auto triage p.txt',
  '"$HOME/.claude/scripts/local-model-call.sh" --auto triage p.txt',
]) {
  test(`logs a real invocation: ${command}`, () => {
    withTmpDir((dir) => {
      seedDiagnostic(dir, SUCCESS_DIAG);
      const { status } = runWithInput({
        session_id: 'sess-i', cwd: dir,
        tool_input: { command },
        tool_response: { output: 'mock answer' },
      });
      assert.equal(status, 0);
      const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
      assert.equal(entry.model, 'llama3.2-3b');
    });
  });
}

test('the diagnostic forced flag passes through to the log entry; raw curl entries log forced:false', () => {
  withTmpDir((dir) => {
    seedDiagnostic(dir, { ...SUCCESS_DIAG, resolved_via: 'explicit', forced: true });
    runWithInput({
      session_id: 'sess-forced', cwd: dir,
      tool_input: { command: 'bash scripts/local-model-call.sh qwen3-14b-mlx p.txt --force' },
      tool_response: { output: '' },
    });
    runWithInput({
      session_id: 'sess-forced', cwd: dir,
      tool_input: { command: "curl -s http://localhost:1234/v1/chat/completions -d '{}'" },
      tool_response: { output: '' },
    });
    const [scriptEntry, curlEntry] = readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8')
      .trim().split('\n').map((l) => JSON.parse(l));
    assert.equal(scriptEntry.forced, true);
    assert.equal(curlEntry.forced, false);
  });
});

test('a script entry whose diagnostic has no forced field logs forced:false', () => {
  withTmpDir((dir) => {
    seedDiagnostic(dir, SUCCESS_DIAG);
    runWithInput({
      session_id: 'sess-noforce', cwd: dir,
      tool_input: { command: 'bash scripts/local-model-call.sh --auto triage p.txt' },
      tool_response: { output: '' },
    });
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.equal(entry.forced, false);
  });
});

test('a failed/unparseable raw curl response logs error:true with null model/usage', () => {
  withTmpDir((dir) => {
    const { status } = runWithInput({
      session_id: 'sess-6', cwd: dir,
      tool_input: { command: "curl -s -m 30 http://localhost:1234/v1/chat/completions -d '{}'" },
      tool_response: { output: '' },
    });
    assert.equal(status, 0);
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.equal(entry.error, true);
    assert.equal(entry.model, null);
    assert.equal(entry.usage, null);
  });
});

test('truncates a very long command string in the logged entry', () => {
  withTmpDir((dir) => {
    const longCommand = `curl -s http://localhost:1234/v1/chat/completions -d '${'x'.repeat(600)}'`;
    runWithInput({
      session_id: 'sess-7', cwd: dir,
      tool_input: { command: longCommand },
      tool_response: { output: '' },
    });
    const entry = JSON.parse(readFileSync(join(dir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
    assert.ok(entry.command.length <= 520);
    assert.match(entry.command, /\.\.\.\[truncated\]$/);
  });
});

test('does not crash on malformed JSON stdin', () => {
  const result = spawnSync('node', [SCRIPT], {
    input: '{not valid json', encoding: 'utf8',
    env: { ...process.env, CLAUDE_PROJECT_DIR: '' },
  });
  assert.equal(result.status, 0);
});

test('the .jsonl log lands in CLAUDE_PROJECT_DIR, not cwd; the diagnostic is still read from cwd', () => {
  withTmpDir((projectDir) => {
    withTmpDir((cwd) => {
      seedDiagnostic(cwd, SUCCESS_DIAG);
      runWithInput({
        session_id: 'sess-anchor', cwd,
        tool_input: { command: 'bash scripts/local-model-call.sh --auto triage p.txt' },
        tool_response: { output: '' },
      }, projectDir);
      const entry = JSON.parse(readFileSync(join(projectDir, '.wolf/local-model-log.jsonl'), 'utf8').trim());
      assert.equal(entry.model, 'llama3.2-3b');
      assert.equal(existsSync(join(cwd, '.wolf/local-model-log.jsonl')), false);
      assert.equal(existsSync(join(cwd, DIAG_REL)), false); // consumed from cwd
    });
  });
});

test('a raw curl entry also lands in CLAUDE_PROJECT_DIR, not cwd', () => {
  withTmpDir((projectDir) => {
    withTmpDir((cwd) => {
      runWithInput({
        session_id: 'sess-anchor2', cwd,
        tool_input: { command: "curl -s http://localhost:1234/v1/chat/completions -d '{}'" },
        tool_response: { output: '' },
      }, projectDir);
      assert.equal(existsSync(join(projectDir, '.wolf/local-model-log.jsonl')), true);
      assert.equal(existsSync(join(cwd, '.wolf/local-model-log.jsonl')), false);
    });
  });
});
