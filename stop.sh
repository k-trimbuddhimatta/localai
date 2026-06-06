#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

red()   { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
blue()  { echo -e "\033[0;34m$*\033[0m"; }

echo ""
blue "=== localai stop ==="
echo ""

cd "$SCRIPT_DIR"

# ── Docker ────────────────────────────────────────────────────────────────

if docker info &>/dev/null; then
  blue "Parando servicios Docker..."
  docker compose down
  green "Docker: servicios parados."
else
  echo "Docker no está corriendo — omitiendo."
fi

# ── Ollama ────────────────────────────────────────────────────────────────

if pgrep -x ollama &>/dev/null; then
  blue "Parando Ollama..."
  pkill -x ollama
  green "Ollama parado."
else
  echo "Ollama no estaba corriendo — omitiendo."
fi

echo ""
green "=== Entorno parado ==="
echo ""
