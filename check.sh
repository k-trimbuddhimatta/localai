#!/usr/bin/env bash
# check.sh — Pre-flight system compatibility check for LocalAI Stack

set -uo pipefail

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[0;34m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
dim()    { printf '\033[2m%s\033[0m\n' "$*"; }
inline_red()    { printf '\033[0;31m%s\033[0m' "$*"; }
inline_green()  { printf '\033[0;32m%s\033[0m' "$*"; }
inline_yellow() { printf '\033[0;33m%s\033[0m' "$*"; }

ERRORS=0
WARNINGS=0

pass()  { printf '  '; inline_green '✓'; printf ' %s\n' "$*"; }
warn()  { printf '  '; inline_yellow '!'; printf ' %s\n' "$*"; ((WARNINGS++)) || true; }
fail()  { printf '  '; inline_red '✗'; printf ' %s\n' "$*"; ((ERRORS++)) || true; }
note()  { printf '    '; dim "$*"; }
sep()   { printf '  '; dim "$(printf '─%.0s' {1..52})"; echo ""; }

# ── Banner ────────────────────────────────────────────────────────────────────

echo ""
blue "╔════════════════════════════════════════════════════╗"
blue "║        LocalAI Stack — Pre-flight Check            ║"
blue "╚════════════════════════════════════════════════════╝"
echo ""

# ── OS & hardware ─────────────────────────────────────────────────────────────

bold "  System"
sep

# macOS
if [[ "$(uname)" != "Darwin" ]]; then
  fail "Not macOS — this stack targets macOS (Ollama runs natively for Metal GPU)"
  echo ""
  red "Cannot continue: non-macOS systems require manual Ollama configuration."
  exit 1
fi

MACOS_VER=$(sw_vers -productVersion)
MACOS_MAJOR="${MACOS_VER%%.*}"
if [[ "$MACOS_MAJOR" -ge 13 ]]; then
  pass "macOS $MACOS_VER"
else
  warn "macOS $MACOS_VER (version 13+ recommended for best Metal performance)"
fi

# CPU architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  CHIP=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Chip:" | awk -F': ' '{print $2}' | xargs || echo "Apple Silicon")
  pass "CPU: $CHIP — Metal GPU acceleration available"
  APPLE_SILICON=true
else
  warn "CPU: Intel x86_64 — no GPU acceleration; models will use CPU only (significantly slower)"
  note "Apple M-series is strongly recommended for local LLMs."
  APPLE_SILICON=false
fi

# RAM
RAM_BYTES=$(sysctl -n hw.memsize)
RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))

if [[ "$RAM_GB" -ge 32 ]]; then
  pass "RAM: ${RAM_GB} GB — can run models up to 32B"
elif [[ "$RAM_GB" -ge 24 ]]; then
  pass "RAM: ${RAM_GB} GB — can run qwen2.5-coder:14b comfortably (recommended)"
elif [[ "$RAM_GB" -ge 16 ]]; then
  warn "RAM: ${RAM_GB} GB — 14b models will work but leave little headroom; 7b is safer"
  note "16 GB = ~7 GB for OS/apps + ~9 GB for model. Close other heavy apps before running."
elif [[ "$RAM_GB" -ge 8 ]]; then
  warn "RAM: ${RAM_GB} GB — only 7b/8b models are usable; performance will be limited"
  note "8 GB minimum: OS uses ~4 GB, leaving ~4 GB for the model. Expect slow responses."
else
  fail "RAM: ${RAM_GB} GB — insufficient. 8 GB minimum required for any local LLM."
fi

# ── Model compatibility table ─────────────────────────────────────────────────

echo ""
bold "  Local model compatibility (your RAM: ${RAM_GB} GB)"
sep
printf '  %-26s  %-8s  %-8s  %s\n' "Model" "Size" "Min RAM" "Use case"
dim "  $(printf '─%.0s' {1..70})"

declare -a MODELS
declare -a SIZES
declare -a MIN_RAMS
declare -a USE_CASES

MODELS=("qwen2.5-coder:7b" "qwen2.5-coder:14b" "qwen2.5-coder:32b" "llama3.1:8b" "llama3.1:70b")
SIZES=("~5 GB" "~9 GB" "~20 GB" "~5 GB" "~40 GB")
MIN_RAMS=(8 16 32 8 64)
USE_CASES=(
  "Code autocomplete & chat"
  "Code generation, review, refactoring"
  "Complex reasoning — needs 32+ GB RAM"
  "General purpose chat"
  "Not viable on consumer hardware"
)

for i in "${!MODELS[@]}"; do
  model="${MODELS[$i]}"
  size="${SIZES[$i]}"
  min_ram="${MIN_RAMS[$i]}"
  use_case="${USE_CASES[$i]}"

  suffix=""
  if [[ "$RAM_GB" -ge 24 && "$model" == "qwen2.5-coder:14b" ]]; then
    suffix=" ← recommended"
  elif [[ "$RAM_GB" -ge 8 && "$RAM_GB" -lt 16 && "$model" == "qwen2.5-coder:7b" ]]; then
    suffix=" ← recommended for your RAM"
  fi

  if [[ "$RAM_GB" -ge "$min_ram" ]]; then
    printf '  '; inline_green '✓'; printf '  %-24s  %-8s  %-8s  %s%s\n' "$model" "$size" "${min_ram} GB" "$use_case" "$suffix"
  else
    printf '  '; inline_red '✗'; printf '  %-24s  %-8s  %-8s  %s\n' "$model" "$size" "${min_ram} GB" "needs ${min_ram} GB RAM"
  fi
done

echo ""
note "Why larger models need more RAM:"
note "  Ollama loads the entire model into memory before inference. On Apple Silicon,"
note "  unified memory means all RAM is available (no separate GPU VRAM limit)."
note "  If a model doesn't fit, Ollama falls back to swap — 10-50x slower, unusable."
note "  On Intel Macs, CPU inference is used regardless of model size."

# ── Disk space ────────────────────────────────────────────────────────────────

echo ""
bold "  Disk space"
sep

OLLAMA_DIR="${HOME}/.ollama/models"
if [[ -d "$OLLAMA_DIR" ]]; then
  CHECK_DIR="$OLLAMA_DIR"
else
  CHECK_DIR="$HOME"
fi

DISK_FREE_KB=$(df -k "$CHECK_DIR" | tail -1 | awk '{print $4}')
DISK_FREE_GB=$((DISK_FREE_KB / 1024 / 1024))

if [[ "$DISK_FREE_GB" -ge 20 ]]; then
  pass "Free disk: ${DISK_FREE_GB} GB (Ollama model dir: $CHECK_DIR)"
elif [[ "$DISK_FREE_GB" -ge 10 ]]; then
  warn "Free disk: ${DISK_FREE_GB} GB — enough for 7b models, tight for 14b (~9 GB)"
  note "Free at least 15 GB before pulling qwen2.5-coder:14b."
elif [[ "$DISK_FREE_GB" -ge 6 ]]; then
  warn "Free disk: ${DISK_FREE_GB} GB — only 7b models (~5 GB) will fit"
else
  fail "Free disk: ${DISK_FREE_GB} GB — not enough for any model (minimum ~6 GB required)"
fi

# ── Dependencies ──────────────────────────────────────────────────────────────

echo ""
bold "  Dependencies"
sep

# Docker
if ! command -v docker &>/dev/null; then
  fail "Docker not found — install from https://docs.docker.com/desktop/mac/install/"
elif ! docker info &>/dev/null 2>&1; then
  fail "Docker is installed but not running — start Docker Desktop first"
else
  DOCKER_VER=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  pass "Docker $DOCKER_VER (running)"
fi

# Docker Compose
if docker compose version &>/dev/null 2>&1; then
  DC_VER=$(docker compose version --short 2>/dev/null || echo "v2+")
  pass "Docker Compose $DC_VER"
else
  fail "Docker Compose v2 not found — update Docker Desktop to 4.x+"
fi

# Ollama
if ! command -v ollama &>/dev/null; then
  fail "Ollama not found — install from https://ollama.com/download"
else
  OLLAMA_VER=$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  if ollama list &>/dev/null 2>&1; then
    pass "Ollama $OLLAMA_VER (running)"
    ALREADY_PULLED=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | tr '\n' ' ')
    if [[ -n "$ALREADY_PULLED" ]]; then
      note "Models already downloaded: $ALREADY_PULLED"
    fi
  else
    warn "Ollama $OLLAMA_VER installed but not running — start with: ollama serve"
  fi
fi

# ── Network ───────────────────────────────────────────────────────────────────

echo ""
bold "  Network"
sep

# Port 4000
if lsof -i :4000 -sTCP:LISTEN &>/dev/null 2>&1; then
  HOLDER=$(lsof -i :4000 -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1, "(PID "$2")"}')
  warn "Port 4000 already in use by: $HOLDER"
  note "Stop that process or change LiteLLM's port in docker-compose.yml before running setup.sh."
else
  pass "Port 4000 is free"
fi

# Internet
if curl -sf --max-time 4 https://api.anthropic.com/health &>/dev/null || \
   curl -sf --max-time 4 https://api.openai.com &>/dev/null || \
   curl -sf --max-time 4 https://generativelanguage.googleapis.com &>/dev/null; then
  pass "Internet connectivity (cloud providers reachable)"
else
  warn "No internet connectivity detected — cloud providers unavailable"
  note "The stack will still work with local models only (offline mode)."
fi

# ── Final summary ─────────────────────────────────────────────────────────────

echo ""
sep
echo ""

if [[ "$ERRORS" -eq 0 && "$WARNINGS" -eq 0 ]]; then
  green "  All checks passed. Ready to run: bash setup.sh"
elif [[ "$ERRORS" -eq 0 ]]; then
  yellow "  $WARNINGS warning(s) — review above before running bash setup.sh"
else
  red "  $ERRORS error(s), $WARNINGS warning(s) — resolve errors before running bash setup.sh"
fi

echo ""
