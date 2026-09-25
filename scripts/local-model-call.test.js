// scripts/local-model-call.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('./local-model-call.sh', import.meta.url));
const ROUTING_CONFIG = {
  eligible_models: {
    'llama3.2-3b': { backends: ['lmstudio'], size_gb: 1.9 },
    'llama3.2:3b': { backends: ['ollama'], size_gb: 1.9 },
    'nomic-embed-text': { backends: ['ollama'], size_gb: 0.27 },
  },
  categories: {
    triage: ['llama3.2-3b', 'llama3.2:3b'],
    'boilerplate-draft': ['llama3.2-3b', 'llama3.2:3b'],
    'pre-summarize': ['llama3.2-3b', 'llama3.2:3b'],
    'vision-ocr': [],
    retrieval: ['nomic-embed-text'],
    'reasoning-check': ['llama3.2-3b', 'llama3.2:3b'],
  },
};

// modelsList: array of {id} for /v1/models (LM Studio shape) or
// {name, remote_host?} for /api/tags (Ollama shape, passed as `.models`).
// chatDelayMs lets a test simulate a slower backend for the race test.
// chatStatus lets a test make the chat endpoint fail (detects a mis-route).
function startMockServer({ kind, modelsList, chatDelayMs = 0, chatModel = 'mock-model', listDelayMs = 0, chatStatus = 200 }) {
  const server = createServer((req, res) => {
    if (req.method === 'GET' && kind === 'lmstudio' && req.url === '/v1/models') {
      setTimeout(() => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ data: modelsList }));
      }, listDelayMs);
      return;
    }
    if (req.method === 'GET' && kind === 'ollama' && req.url === '/api/tags') {
      setTimeout(() => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ models: modelsList }));
      }, listDelayMs);
      return;
    }
    if (req.method === 'POST' && req.url === '/v1/chat/completions') {
      setTimeout(() => {
        res.writeHead(chatStatus, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          model: chatModel,
          choices: [{ message: { content: 'mock answer' } }],
          usage: { prompt_tokens: 3, completion_tokens: 2 },
        }));
      }, chatDelayMs);
      return;
    }
    res.writeHead(404);
    res.end();
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

// spawnSync would block the whole Node event loop, starving the in-process
// mock HTTP servers above of the I/O processing they need to answer the
// script's curl requests (verified: every request stalls to its curl
// timeout and errors as unreachable). Use async spawn + a Promise instead.
function runScript(args, cwd, env) {
  return new Promise((resolve, reject) => {
    // Point at the tmp cwd's seeded config by default so tests never read the
    // real one; a test passes `LOCAL_MODEL_ROUTING_CONFIG: null` to leave it unset.
    const merged = {
      ...process.env,
      LOCAL_MODEL_ROUTING_CONFIG: join(cwd, 'config/local-model-routing.json'),
      ...env,
    };
    if (merged.LOCAL_MODEL_ROUTING_CONFIG === null) delete merged.LOCAL_MODEL_ROUTING_CONFIG;
    const child = spawn('bash', [SCRIPT, ...args], { cwd, env: merged });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('error', reject);
    child.on('close', (status) => resolve({ status, stdout, stderr }));
  });
}

function runAuto(cwd, category, env) {
  return runScript(['--auto', category, join(cwd, 'prompt.txt')], cwd, env);
}

test('--auto resolves to the only live candidate and calls it', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }] });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [] });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runAuto(cwd, 'triage', {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
        LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), 'mock answer');
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.model, 'llama3.2-3b');
      assert.equal(diag.backend, 'lmstudio');
      assert.equal(diag.category, 'triage');
      assert.equal(diag.resolved_via, 'auto');
      assert.deepEqual(diag.usage, { prompt_tokens: 3, completion_tokens: 2 });
      assert.equal(diag.error, false);
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

test('--auto hard-blocks with no live model and never falls back to an unlisted one', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'qwen3-14b-mlx' }] });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [] });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runAuto(cwd, 'triage', {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
        LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
      });
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /no eligible model.*currently available/i);
      assert.doesNotMatch(result.stderr, /explicit model/i);
      assert.match(result.stderr, /qwen3-14b-mlx/); // shows what IS loaded
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

test('--auto on an empty category (vision-ocr) always hard-blocks', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }] });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [] });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runAuto(cwd, 'vision-ocr', {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
        LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
      });
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /no eligible local model covers category/i);
      assert.doesNotMatch(result.stderr, /explicit model/i);
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

test('--auto excludes a remote-backed Ollama model even if its name matches', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [] });
  const ollama = await startMockServer({
    kind: 'ollama',
    modelsList: [{ name: 'llama3.2:3b', remote_host: 'https://ollama.com:443' }],
  });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runAuto(cwd, 'triage', {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
        LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
      });
      assert.notEqual(result.status, 0, 'a remote-backed entry must not satisfy the category');
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

// listDelayMs on each mock stays well under the script's 3s curl timeout
// (so the initial live-detection pass for both backends still succeeds),
// but the gap between them (0ms vs 400ms) is large relative to the race
// loop's 100ms poll interval — deterministic enough that the winner
// reliably matches whichever backend was told to answer faster, not a
// coin flip. Both directions are tested so the assertion can't trivially
// pass regardless of which backend actually won.

test('--auto race: when Ollama answers faster, it wins and llama3.2:3b is used', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }], listDelayMs: 400 });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [{ name: 'llama3.2:3b' }], listDelayMs: 0 });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runAuto(cwd, 'triage', {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
        LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
      });
      assert.equal(result.status, 0, result.stderr);
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.backend, 'ollama');
      assert.equal(diag.model, 'llama3.2:3b');
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

test('--auto race: when LM Studio answers faster, it wins and llama3.2-3b is used', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }], listDelayMs: 0 });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [{ name: 'llama3.2:3b' }], listDelayMs: 400 });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runAuto(cwd, 'triage', {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
        LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
      });
      assert.equal(result.status, 0, result.stderr);
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.backend, 'lmstudio');
      assert.equal(diag.model, 'llama3.2-3b');
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

test('explicit mode: an ineligible model is refused, without advertising --force, and the attempt is recorded', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'qwen3-14b-mlx' }] });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runScript(['qwen3-14b-mlx', join(cwd, 'prompt.txt'), '--category', 'triage'], cwd, {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
      });
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /not in eligible_models/);
      assert.doesNotMatch(result.stderr, /--force/);
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.error, true);
      assert.equal(diag.resolved_via, 'explicit');
      assert.equal(diag.model, 'qwen3-14b-mlx');
    });
  } finally {
    lmstudio.close();
  }
});

test('explicit mode: --force skips the eligibility check and calls LM Studio', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'qwen3-14b-mlx' }], chatModel: 'qwen3-14b-mlx' });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runScript(['qwen3-14b-mlx', join(cwd, 'prompt.txt'), '--force'], cwd, {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), 'mock answer');
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.backend, 'lmstudio');
      assert.equal(diag.error, false);
    });
  } finally {
    lmstudio.close();
  }
});

test('explicit mode: an eligible Ollama-named model is routed to its declared backend (Ollama)', async () => {
  // LM Studio's chat endpoint fails, so a mis-route to LM Studio fails the test.
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [], chatStatus: 500 });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [{ name: 'llama3.2:3b' }], chatModel: 'llama3.2:3b' });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runScript(['llama3.2:3b', join(cwd, 'prompt.txt'), '--category', 'triage'], cwd, bothUrls(lmstudio, ollama));
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), 'mock answer');
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.backend, 'ollama');
      assert.equal(diag.model, 'llama3.2:3b');
      assert.equal(diag.resolved_via, 'explicit');
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

test('explicit mode: eligible LM Studio model still works and only calls LM Studio', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [], chatModel: 'llama3.2-3b' });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const result = await runScript(['llama3.2-3b', join(cwd, 'prompt.txt'), '--category', 'triage'], cwd, {
        LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stdout.trim(), 'mock answer');
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.resolved_via, 'explicit');
      assert.equal(diag.backend, 'lmstudio');
    });
  } finally {
    lmstudio.close();
  }
});

// Creates a tmp cwd seeded with the routing config + a prompt file, and
// guarantees cleanup around an async fn.
async function withTmpCwdAsync(fn) {
  const cwd = mkdtempSync(join(tmpdir(), 'local-model-call-test-'));
  mkdirSync(join(cwd, 'config'), { recursive: true });
  writeFileSync(join(cwd, 'config/local-model-routing.json'), JSON.stringify(ROUTING_CONFIG));
  writeFileSync(join(cwd, 'prompt.txt'), 'hello');
  try {
    await fn(cwd);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
}

function bothUrls(lmstudio, ollama) {
  return {
    LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}`,
    LOCAL_MODEL_OLLAMA_URL: `http://127.0.0.1:${ollama.address().port}`,
  };
}

test('--auto finds the routing config next to the script when cwd has none and the env override is unset', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }] });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [] });
  const cwd = mkdtempSync(join(tmpdir(), 'local-model-call-empty-cwd-'));
  try {
    writeFileSync(join(cwd, 'prompt.txt'), 'hello');
    const result = await runAuto(cwd, 'triage', { ...bothUrls(lmstudio, ollama), LOCAL_MODEL_ROUTING_CONFIG: null });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.trim(), 'mock answer');
  } finally {
    rmSync(cwd, { recursive: true, force: true });
    lmstudio.close();
    ollama.close();
  }
});

test('a blocked --auto call after a success overwrites the diagnostic with an honest error record', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }] });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [] });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const env = bothUrls(lmstudio, ollama);
      const ok = await runAuto(cwd, 'triage', env);
      assert.equal(ok.status, 0, ok.stderr);
      const blocked = await runAuto(cwd, 'vision-ocr', env);
      assert.notEqual(blocked.status, 0);
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.error, true);
      assert.equal(diag.category, 'vision-ocr');
      assert.equal(diag.resolved_via, 'auto');
      assert.equal(diag.model, null);
      assert.equal(diag.usage, null);
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});

const DIAG_FILE = '.wolf/.local-model-call-last-response.json';

test('--auto with an invalid category records category:null (a bogus value is never logged)', async () => {
  await withTmpCwdAsync(async (cwd) => {
    const result = await runAuto(cwd, 'bogus', {});
    assert.equal(result.status, 1);
    const diag = JSON.parse(readFileSync(join(cwd, DIAG_FILE), 'utf8'));
    assert.equal(diag.category, null);
    assert.equal(diag.error, true);
  });
});

test('explicit mode with an invalid --category records category:null', async () => {
  await withTmpCwdAsync(async (cwd) => {
    const result = await runScript(['llama3.2-3b', join(cwd, 'prompt.txt'), '--category', 'bogus'], cwd, {});
    assert.equal(result.status, 1);
    const diag = JSON.parse(readFileSync(join(cwd, DIAG_FILE), 'utf8'));
    assert.equal(diag.category, null);
  });
});

test('a --force call records forced:true; a normal call records forced:false', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [], chatModel: 'qwen3-14b-mlx' });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const env = { LOCAL_MODEL_LMSTUDIO_URL: `http://127.0.0.1:${lmstudio.address().port}` };
      const forced = await runScript(['qwen3-14b-mlx', join(cwd, 'prompt.txt'), '--force'], cwd, env);
      assert.equal(forced.status, 0, forced.stderr);
      assert.equal(JSON.parse(readFileSync(join(cwd, DIAG_FILE), 'utf8')).forced, true);

      const normal = await runScript(['llama3.2-3b', join(cwd, 'prompt.txt'), '--category', 'triage'], cwd, env);
      assert.equal(normal.status, 0, normal.stderr);
      assert.equal(JSON.parse(readFileSync(join(cwd, DIAG_FILE), 'utf8')).forced, false);
    });
  } finally {
    lmstudio.close();
  }
});

test('explicit mode: a routing config that is not valid JSON is reported as such, not as "not eligible"', async () => {
  await withTmpCwdAsync(async (cwd) => {
    writeFileSync(join(cwd, 'config/local-model-routing.json'), '{not json');
    const result = await runScript(['llama3.2-3b', join(cwd, 'prompt.txt')], cwd, {});
    assert.equal(result.status, 1);
    assert.match(result.stderr, /routing config is not valid JSON/);
    assert.doesNotMatch(result.stderr, /not in eligible_models/);
  });
});

test('a usage error after a success leaves an error diagnostic, not the stale success', async () => {
  const lmstudio = await startMockServer({ kind: 'lmstudio', modelsList: [{ id: 'llama3.2-3b' }] });
  const ollama = await startMockServer({ kind: 'ollama', modelsList: [] });
  try {
    await withTmpCwdAsync(async (cwd) => {
      const env = bothUrls(lmstudio, ollama);
      const ok = await runAuto(cwd, 'triage', env);
      assert.equal(ok.status, 0, ok.stderr);
      const bad = await runScript(['--auto', 'triage'], cwd, env);
      assert.equal(bad.status, 1);
      const diag = JSON.parse(readFileSync(join(cwd, '.wolf/.local-model-call-last-response.json'), 'utf8'));
      assert.equal(diag.error, true);
      assert.equal(diag.model, null);
      assert.notEqual(diag.category, 'triage');
    });
  } finally {
    lmstudio.close();
    ollama.close();
  }
});
