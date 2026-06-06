#!/usr/bin/env bash
# setup.sh — LocalAI Stack bootstrap & configuration wizard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
dim()    { printf '\033[2m%s\033[0m\n' "$*"; }
sep()    { printf '  '; printf '\033[2m%.0s─\033[0m' {1..52}; echo ""; }

# ── Dependency checks ─────────────────────────────────────────────────────────

check_deps() {
  local ok=true

  if ! command -v docker &>/dev/null; then
    red "ERROR: Docker not found. Install from https://docs.docker.com/desktop/mac/install/"
    ok=false
  elif ! docker info &>/dev/null 2>&1; then
    red "ERROR: Docker is not running. Start Docker Desktop first."
    ok=false
  fi

  if ! command -v ollama &>/dev/null; then
    red "ERROR: Ollama not found. Install from https://ollama.com/download"
    ok=false
  fi

  if [[ "$ok" == "false" ]]; then
    echo ""
    yellow "Tip: run 'bash check.sh' for a detailed pre-flight report."
    exit 1
  fi
}

# ── RAM detection ─────────────────────────────────────────────────────────────

get_ram_gb() {
  local bytes
  bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  echo $((bytes / 1024 / 1024 / 1024))
}

# ── Provider wizard ───────────────────────────────────────────────────────────

configure_providers() {
  echo ""
  bold "  Cloud providers"
  sep
  echo ""
  echo "  Configure your cloud AI providers. Press Enter to skip any."
  echo "  (You can add or update keys later by editing .env)"
  echo ""
  echo "    [A]  Anthropic — Claude Sonnet 4.6, Claude Opus 4.8"
  echo "    [O]  OpenAI    — GPT-4o, GPT-4o mini"
  echo "    [G]  Google    — Gemini 2.5 Flash, Gemini 2.5 Pro"
  echo "    [N]  None      — offline / local only"
  echo ""
  read -rp "  Select providers (e.g. 'AO' for Anthropic + OpenAI) [Enter for none]: " PROVIDER_CHOICE
  PROVIDER_CHOICE="${PROVIDER_CHOICE^^}"

  ANTHROPIC_KEY=""
  OPENAI_KEY=""
  GEMINI_KEY=""

  if [[ "$PROVIDER_CHOICE" == *"A"* ]]; then
    echo ""
    read -rp "  Anthropic API key: " ANTHROPIC_KEY
  fi
  if [[ "$PROVIDER_CHOICE" == *"O"* ]]; then
    echo ""
    read -rp "  OpenAI API key: " OPENAI_KEY
  fi
  if [[ "$PROVIDER_CHOICE" == *"G"* ]]; then
    echo ""
    read -rp "  Google Gemini API key: " GEMINI_KEY
  fi
}

# ── LiteLLM auth ──────────────────────────────────────────────────────────────

configure_auth() {
  echo ""
  bold "  LiteLLM authentication"
  sep
  echo ""
  echo "  The master key protects your LiteLLM API and web UI."
  echo "  Use it as the API key in Cline, curl, and any other client."
  echo ""

  local default_key
  default_key="sk-localdev-$(openssl rand -hex 6 2>/dev/null || date +%s)"
  read -rp "  Master key [$default_key]: " LITELLM_MASTER_KEY
  LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-$default_key}"

  LITELLM_SALT_KEY=$(openssl rand -hex 32 2>/dev/null || date +%s%N | shasum | awk '{print $1}')

  echo ""
  bold "  Database"
  sep
  echo ""
  local default_pg
  default_pg=$(openssl rand -hex 12 2>/dev/null || echo "localdev$(date +%s)")
  read -rsp "  PostgreSQL password [$default_pg]: " POSTGRES_PASSWORD
  echo ""
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$default_pg}"
}

# ── Write .env ────────────────────────────────────────────────────────────────

write_env() {
  cat > "$SCRIPT_DIR/.env" <<EOF
# ── Cloud providers (leave empty to use offline/local only) ───────────────────
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
OPENAI_API_KEY=${OPENAI_KEY}
GEMINI_API_KEY=${GEMINI_KEY}

# ── LiteLLM ───────────────────────────────────────────────────────────────────
LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
LITELLM_SALT_KEY=${LITELLM_SALT_KEY}

# ── PostgreSQL ────────────────────────────────────────────────────────────────
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF
  green "  .env written."
}

# ── Model selection ───────────────────────────────────────────────────────────

select_model() {
  local ram_gb
  ram_gb=$(get_ram_gb)

  echo ""
  bold "  Local model selection"
  sep
  echo ""
  echo "  Your system has ${ram_gb} GB RAM."
  echo ""

  local options=()
  local idx=1

  if [[ "$ram_gb" -ge 16 ]]; then
    printf '  %d)  qwen2.5-coder:14b  [~9 GB]  ★ Recommended — best code quality\n' $idx
    options+=("qwen2.5-coder:14b")
    ((idx++))
  fi

  printf '  %d)  qwen2.5-coder:7b   [~5 GB]    Good quality, lower RAM requirement\n' $idx
  options+=("qwen2.5-coder:7b")
  ((idx++))

  printf '  %d)  llama3.1:8b        [~5 GB]    General purpose (not code-specialised)\n' $idx
  options+=("llama3.1:8b")
  ((idx++))

  printf '  %d)  None — cloud only\n' $idx
  options+=("")

  echo ""
  echo "  Model RAM requirements:"
  dim "  ─────────────────────────────────────────────────────────"
  dim "    7b / 8b  models need  8 GB free RAM  (safe on 16 GB systems)"
  dim "   14b       models need 16 GB free RAM  (recommended on 24+ GB)"
  dim "   32b       models need 32 GB free RAM  (not listed — use at own risk)"
  dim "   70b+      models need 64 GB free RAM  (not viable on consumer hardware)"
  echo ""
  dim "  Why? Ollama loads the full model into memory before inference."
  dim "  If it doesn't fit, it falls back to swap — 10–50x slower and unusable."
  echo ""

  local default=1
  read -rp "  Select [$default]: " choice
  choice="${choice:-$default}"

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
    LOCAL_MODEL="${options[$((choice - 1))]}"
  else
    LOCAL_MODEL="${options[0]}"
  fi
}

# ── Pull model ────────────────────────────────────────────────────────────────

pull_model() {
  if [[ -z "$LOCAL_MODEL" ]]; then
    yellow "  No local model selected — skipping pull."
    return
  fi

  echo ""
  if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$LOCAL_MODEL"; then
    green "  Model $LOCAL_MODEL already downloaded — skipping pull."
  else
    blue "  Downloading $LOCAL_MODEL (this may take several minutes)..."
    ollama pull "$LOCAL_MODEL"
    green "  Model ready."
  fi
}

# ── Start stack ───────────────────────────────────────────────────────────────

start_stack() {
  echo ""
  blue "  Starting Docker services..."
  cd "$SCRIPT_DIR"
  docker compose up -d

  echo ""
  blue "  Waiting for LiteLLM to become healthy..."
  local attempts=0
  until curl -sf http://localhost:4000/health &>/dev/null || [[ "$attempts" -ge 30 ]]; do
    sleep 2
    ((attempts++)) || true
  done

  if curl -sf http://localhost:4000/health &>/dev/null; then
    green "  LiteLLM is up."
  else
    yellow "  LiteLLM health check timed out. Check logs: docker compose logs litellm"
  fi
}

# ── Summary ───────────────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo ""
  green "╔════════════════════════════════════════════════════╗"
  green "║            LocalAI Stack is running!              ║"
  green "╚════════════════════════════════════════════════════╝"
  echo ""
  bold "  Access URLs"
  sep
  printf '  %-20s  %s\n' "LiteLLM API"    "http://localhost:4000"
  printf '  %-20s  %s\n' "LiteLLM Web UI" "http://localhost:4000/ui"
  echo ""
  bold "  Cline configuration (VS Code)"
  sep
  printf '  %-20s  %s\n' "Provider"  "OpenAI Compatible"
  printf '  %-20s  %s\n' "Base URL"  "http://localhost:4000"
  printf '  %-20s  %s\n' "API Key"   "${LITELLM_MASTER_KEY:-<your LITELLM_MASTER_KEY in .env>}"
  printf '  %-20s  %s\n' "Model"     "claude-sonnet-4-6  (recommended for agent mode)"
  echo ""
  dim "  For offline/local work, switch the Cline model to: ${LOCAL_MODEL:-qwen2.5-coder:14b}"
  echo ""
  bold "  Useful commands"
  sep
  dim "  Stop the stack:       bash stop.sh"
  dim "  View logs:            docker compose logs -f litellm"
  dim "  Check health:         curl http://localhost:4000/health"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo ""
blue "╔════════════════════════════════════════════════════╗"
blue "║          LocalAI Stack — Setup Wizard             ║"
blue "╚════════════════════════════════════════════════════╝"

check_deps

cd "$SCRIPT_DIR"

if [[ -f .env ]]; then
  echo ""
  yellow "  .env already exists. Using existing configuration."
  echo ""
  read -rp "  Re-run the configuration wizard anyway? [y/N]: " RERUN
  if [[ "${RERUN,,}" == "y" ]]; then
    configure_providers
    configure_auth
    write_env
  fi
else
  configure_providers
  configure_auth
  write_env
fi

select_model
pull_model
start_stack
print_summary
