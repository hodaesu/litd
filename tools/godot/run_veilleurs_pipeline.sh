#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-quick}"
BASE_REF="${2:-origin/main}"

PYTHON_BIN="${PYTHON_BIN:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    echo "Python 3 est requis pour lancer le pipeline Veilleurs." >&2
    exit 127
  fi
fi

exec "$PYTHON_BIN" tools/godot/veilleurs_pipeline.py --mode "$MODE" --base-ref "$BASE_REF" "${@:3}"
