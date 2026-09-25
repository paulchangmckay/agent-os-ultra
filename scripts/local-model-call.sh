#!/usr/bin/env bash
# Calls a local LM Studio or Ollama server's OpenAI-compatible
# chat-completions endpoint and prints the response text. Reads the prompt
# from a file, not a shell argument, to avoid quoting/escaping hazards for
# multi-line or quote-containing prompts. See
# docs/superpowers/specs/2026-09-23-model-routing-design.md component A.
# max_tokens defaults to 512 to prevent the uncapped-hang failure mode found
# in the 2026-09-08 Gate 0 spot-check (deepseek-r1 generated unbounded
# chain-of-thought and never returned within 180s).
#
# --auto <category> resolves the model automatically from
# config/local-model-routing.json against whichever of LM Studio/Ollama is
# actually reachable right now (hard-blocks if no eligible model is loaded
# for that category — never silently substitutes a different one).
#
# Explicit mode (<model> <prompt-file>) is also checked against
# eligible_models and routed to the model's declared backend. --force is a
# human override that skips that check (then targets LM Studio); it is not for
# agents to use or suggest.
#
# wolf-debt: the dual-backend race below is hardcoded to the
# llama3.2-3b/llama3.2:3b pair (the only dual-backend entry in the current
# eligible_models table), not derived generically from the config. Upgrade
# trigger: a second model gets added to eligible_models with backends on
# both lmstudio and ollama.
set -euo pipefail

LMSTUDIO_BASE_URL="${LOCAL_MODEL_LMSTUDIO_URL:-http://localhost:1234}"
OLLAMA_BASE_URL="${LOCAL_MODEL_OLLAMA_URL:-http://localhost:11434}"
ROUTING_CONFIG="${LOCAL_MODEL_ROUTING_CONFIG:-$(unset CDPATH; cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/local-model-routing.json}"
VALID_CATEGORIES="triage boilerplate-draft pre-summarize vision-ocr retrieval reasoning-check"
# Deliberately cwd-relative (not anchored to this script's location): the
# post-local-model-log.js hook always runs from the main checkout's copy but
# shares the session's cwd, so cwd is the one location both agree on. Only this
# diagnostic needs that agreement; the hook's two .jsonl logs are written by the
# hook alone and anchor to CLAUDE_PROJECT_DIR instead.
DIAG_PATH=".wolf/.local-model-call-last-response.json"
DIAG_WRITTEN=0
DIAG_MODEL=""
DIAG_BACKEND=""
DIAG_CATEGORY=""
DIAG_MODE=""
DIAG_FORCED="false"

write_diagnostic() {
  # $1=model $2=backend $3=category $4=resolved_via $5=usage_json_or_null $6=error(true/false)
  # Empty strings are recorded as JSON null (unknown, e.g. a blocked call).
  DIAG_WRITTEN=1
  mkdir -p "$(dirname "$DIAG_PATH")" 2>/dev/null || true
  jq -n \
    --arg model "$1" \
    --arg backend "$2" \
    --arg category "$3" \
    --arg resolved_via "$4" \
    --argjson usage "$5" \
    --argjson error "$6" \
    --arg forced "$DIAG_FORCED" \
    '{model: (if $model == "" then null else $model end), backend: (if $backend == "" then null else $backend end), category: (if $category == "" then null else $category end), resolved_via: (if $resolved_via == "" then null else $resolved_via end), usage: $usage, error: $error, forced: ($forced == "true")}' \
    > "$DIAG_PATH" 2>/dev/null || true
}

# Every exit path must leave a diagnostic for THIS run, never the previous
# run's file: remove any stale one now, and on exit record an error entry if
# call_backend never wrote one. Preserves the original exit code.
rm -f "$DIAG_PATH" 2>/dev/null || true

on_exit() {
  local rc=$?
  if [ "$DIAG_WRITTEN" -ne 1 ]; then
    write_diagnostic "$DIAG_MODEL" "$DIAG_BACKEND" "$DIAG_CATEGORY" "$DIAG_MODE" "null" "true"
  fi
  exit "$rc"
}
trap on_exit EXIT

usage() {
  echo "Usage: $0 <model> <prompt-file> [--max-tokens N] [--temperature N] [--category TAG] [--force]" >&2
  echo "       $0 --auto <category> <prompt-file> [--max-tokens N] [--temperature N]" >&2
  echo "  TAG/category must be one of: $VALID_CATEGORIES" >&2
  echo "  --force: human override — skips the eligible_models check (explicit mode only)" >&2
  exit 1
}

if [ "$#" -lt 2 ]; then
  usage
fi

call_backend() {
  # $1=base_url $2=backend_name $3=model $4=prompt_file $5=max_tokens $6=temperature $7=category $8=resolved_via
  local base="$1" backend_name="$2" model="$3" prompt_file="$4" max_tokens="$5" temperature="$6" category="$7" resolved_via="$8"
  local endpoint="${base}/v1/chat/completions"

  local payload
  payload=$(jq -n \
    --arg model "$model" \
    --rawfile prompt "$prompt_file" \
    --argjson max_tokens "$max_tokens" \
    --argjson temperature "$temperature" \
    '{model: $model, messages: [{role: "user", content: $prompt}], max_tokens: $max_tokens, temperature: $temperature}')

  local response
  if ! response=$(curl -s -m 120 -w '\nHTTP_STATUS:%{http_code}' "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload"); then
    write_diagnostic "$model" "$backend_name" "$category" "$resolved_via" "null" "true"
    echo "Error: curl failed to reach $endpoint" >&2
    exit 1
  fi

  local http_status body
  http_status=$(echo "$response" | grep -o 'HTTP_STATUS:[0-9]*' | cut -d: -f2)
  body=$(echo "$response" | sed '$ d')

  if [ "$http_status" != "200" ]; then
    write_diagnostic "$model" "$backend_name" "$category" "$resolved_via" "null" "true"
    echo "Error: local model server returned HTTP $http_status" >&2
    echo "$body" >&2
    exit 1
  fi

  local content usage_json
  content=$(echo "$body" | jq -r '.choices[0].message.content // empty')
  usage_json=$(echo "$body" | jq -c '.usage // null')

  if [ -z "$content" ]; then
    write_diagnostic "$model" "$backend_name" "$category" "$resolved_via" "$usage_json" "true"
    echo "Error: could not extract response content from server output" >&2
    echo "$body" >&2
    exit 1
  fi

  write_diagnostic "$model" "$backend_name" "$category" "$resolved_via" "$usage_json" "false"
  echo "$content"
}

# ---- --auto mode ----
if [ "$1" = "--auto" ]; then
  if [ "$#" -lt 3 ]; then
    usage
  fi
  CATEGORY="$2"
  DIAG_MODE="auto"
  PROMPT_FILE="$3"
  shift 3

  MAX_TOKENS=512
  TEMPERATURE=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --max-tokens) MAX_TOKENS="$2"; shift 2 ;;
      --temperature) TEMPERATURE="$2"; shift 2 ;;
      *) usage ;;
    esac
  done

  MATCH=0
  for c in $VALID_CATEGORIES; do
    [ "$c" = "$CATEGORY" ] && MATCH=1
  done
  if [ "$MATCH" -eq 0 ]; then
    echo "Error: category must be one of: $VALID_CATEGORIES (got: $CATEGORY)" >&2
    exit 1
  fi
  DIAG_CATEGORY="$CATEGORY"

  if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: prompt file not found: $PROMPT_FILE" >&2
    exit 1
  fi

  if [ ! -f "$ROUTING_CONFIG" ]; then
    echo "Error: routing config not found: $ROUTING_CONFIG" >&2
    exit 1
  fi

  CANDIDATES=$(jq -r --arg cat "$CATEGORY" '.categories[$cat][]? // empty' "$ROUTING_CONFIG")

  if [ -z "$CANDIDATES" ]; then
    echo "Error: no eligible local model covers category '$CATEGORY'." >&2
    echo "config/local-model-routing.json has no models listed for this category — edit the table to add one." >&2
    exit 1
  fi

  LMSTUDIO_LIVE=$(curl -s -m 3 "${LMSTUDIO_BASE_URL}/v1/models" 2>/dev/null | jq -r '.data[]?.id // empty' 2>/dev/null || true)
  OLLAMA_LIVE=$(curl -s -m 3 "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null | jq -r '.models[]? | select(.remote_host == null) | (.name // .model) // empty' 2>/dev/null || true)

  is_live() {
    echo "$2" | grep -Fxq "$1"
  }

  backend_for_model() {
    jq -r --arg m "$1" '.eligible_models[$m].backends[0] // empty' "$ROUTING_CONFIG"
  }

  RESOLVED_MODEL=""
  RESOLVED_BACKEND=""
  FIRST_LIVE=""
  FIRST_LIVE_BACKEND=""

  for candidate in $CANDIDATES; do
    backend=$(backend_for_model "$candidate")
    if [ "$backend" = "lmstudio" ] && is_live "$candidate" "$LMSTUDIO_LIVE"; then
      FIRST_LIVE="$candidate"; FIRST_LIVE_BACKEND="lmstudio"; break
    fi
    if [ "$backend" = "ollama" ] && is_live "$candidate" "$OLLAMA_LIVE"; then
      FIRST_LIVE="$candidate"; FIRST_LIVE_BACKEND="ollama"; break
    fi
  done

  if [ -n "$FIRST_LIVE" ]; then
    SIBLING=""
    if [ "$FIRST_LIVE" = "llama3.2-3b" ] && is_live "llama3.2:3b" "$OLLAMA_LIVE"; then
      SIBLING="llama3.2:3b"
    elif [ "$FIRST_LIVE" = "llama3.2:3b" ] && is_live "llama3.2-3b" "$LMSTUDIO_LIVE"; then
      SIBLING="llama3.2-3b"
    fi

    if [ -n "$SIBLING" ]; then
      RACE_DIR=$(mktemp -d)
      ( curl -s -m 3 -o /dev/null -w '%{http_code}' "${LMSTUDIO_BASE_URL}/v1/models" > "$RACE_DIR/lmstudio_status" 2>/dev/null || true; touch "$RACE_DIR/lmstudio_done" ) &
      ( curl -s -m 3 -o /dev/null -w '%{http_code}' "${OLLAMA_BASE_URL}/api/tags" > "$RACE_DIR/ollama_status" 2>/dev/null || true; touch "$RACE_DIR/ollama_done" ) &
      WAITED=0
      WINNER=""
      while [ "$WAITED" -lt 30 ]; do
        if [ -f "$RACE_DIR/lmstudio_done" ] && [ "$(cat "$RACE_DIR/lmstudio_status" 2>/dev/null)" = "200" ]; then
          WINNER="lmstudio"; break
        fi
        if [ -f "$RACE_DIR/ollama_done" ] && [ "$(cat "$RACE_DIR/ollama_status" 2>/dev/null)" = "200" ]; then
          WINNER="ollama"; break
        fi
        sleep 0.1
        WAITED=$((WAITED + 1))
      done
      wait
      rm -rf "$RACE_DIR"

      if [ "$WINNER" = "lmstudio" ]; then
        RESOLVED_MODEL="llama3.2-3b"; RESOLVED_BACKEND="lmstudio"
      elif [ "$WINNER" = "ollama" ]; then
        RESOLVED_MODEL="llama3.2:3b"; RESOLVED_BACKEND="ollama"
      else
        RESOLVED_MODEL="$FIRST_LIVE"; RESOLVED_BACKEND="$FIRST_LIVE_BACKEND"
      fi
    else
      RESOLVED_MODEL="$FIRST_LIVE"; RESOLVED_BACKEND="$FIRST_LIVE_BACKEND"
    fi
  fi

  DIAG_MODEL="$RESOLVED_MODEL"
  DIAG_BACKEND="$RESOLVED_BACKEND"

  if [ -z "$RESOLVED_MODEL" ]; then
    echo "Error: no eligible model for category '$CATEGORY' is currently available." >&2
    echo "Expected one of: $CANDIDATES" >&2
    echo "LM Studio lists: ${LMSTUDIO_LIVE:-<none>}" >&2
    echo "Ollama lists: ${OLLAMA_LIVE:-<none>}" >&2
    echo "Load one of the expected models, or edit $ROUTING_CONFIG." >&2
    exit 1
  fi

  if [ "$RESOLVED_BACKEND" = "lmstudio" ]; then
    BASE_URL="$LMSTUDIO_BASE_URL"
  else
    BASE_URL="$OLLAMA_BASE_URL"
  fi

  call_backend "$BASE_URL" "$RESOLVED_BACKEND" "$RESOLVED_MODEL" "$PROMPT_FILE" "$MAX_TOKENS" "$TEMPERATURE" "$CATEGORY" "auto"
  exit 0
fi

# ---- explicit mode (checked against eligible_models; --force overrides) ----
DIAG_MODE="explicit"
MODEL="$1"
DIAG_MODEL="$MODEL"
PROMPT_FILE="$2"
shift 2

MAX_TOKENS=512
TEMPERATURE=0
CATEGORY=""
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --max-tokens) MAX_TOKENS="$2"; shift 2 ;;
    --temperature) TEMPERATURE="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --force) FORCE=1; DIAG_FORCED="true"; shift ;;
    *) usage ;;
  esac
done

if [ -n "$CATEGORY" ]; then
  MATCH=0
  for c in $VALID_CATEGORIES; do
    [ "$c" = "$CATEGORY" ] && MATCH=1
  done
  if [ "$MATCH" -eq 0 ]; then
    echo "Error: --category must be one of: $VALID_CATEGORIES (got: $CATEGORY)" >&2
    exit 1
  fi
  DIAG_CATEGORY="$CATEGORY"
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

EXPLICIT_BACKEND=""
if [ -f "$ROUTING_CONFIG" ]; then
  if ! jq -e . "$ROUTING_CONFIG" >/dev/null 2>&1; then
    echo "Error: routing config is not valid JSON: $ROUTING_CONFIG" >&2
    exit 1
  fi
  EXPLICIT_BACKEND=$(jq -r --arg m "$MODEL" '.eligible_models[$m].backends[0] // empty' "$ROUTING_CONFIG")
elif [ "$FORCE" -ne 1 ]; then
  echo "Error: routing config not found: $ROUTING_CONFIG" >&2
  exit 1
fi

if [ -z "$EXPLICIT_BACKEND" ]; then
  if [ "$FORCE" -ne 1 ]; then
    echo "Error: model '$MODEL' is not in eligible_models (config/local-model-routing.json, sized for this machine). Add it to that table if it is genuinely safe to run here." >&2
    exit 1
  fi
  EXPLICIT_BACKEND="lmstudio"
fi

if [ "$EXPLICIT_BACKEND" = "ollama" ]; then
  EXPLICIT_BASE_URL="$OLLAMA_BASE_URL"
else
  EXPLICIT_BASE_URL="$LMSTUDIO_BASE_URL"
fi
DIAG_BACKEND="$EXPLICIT_BACKEND"

call_backend "$EXPLICIT_BASE_URL" "$EXPLICIT_BACKEND" "$MODEL" "$PROMPT_FILE" "$MAX_TOKENS" "$TEMPERATURE" "$CATEGORY" "explicit"
