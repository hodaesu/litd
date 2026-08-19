#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ERROR_PATTERN='SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Failed to create an autoload|ERROR: Failed to instantiate an autoload|ERROR: FATAL:|handle_crash: Program crashed'

run_checked() {
  local label="$1"
  shift
  local log_file
  log_file="$(mktemp)"
  echo "==> ${label}"

  set +e
  "$@" 2>&1 | tee "$log_file"
  local command_status=${PIPESTATUS[0]}
  set -e

  if [[ $command_status -ne 0 ]]; then
    echo "Godot a quitté avec le code ${command_status} pendant: ${label}" >&2
    rm -f "$log_file"
    return "$command_status"
  fi

  if grep -E "$ERROR_PATTERN" "$log_file" >/dev/null; then
    echo "Des erreurs GDScript/autoload ont été détectées pendant: ${label}" >&2
    grep -E "$ERROR_PATTERN" "$log_file" >&2 || true
    rm -f "$log_file"
    return 1
  fi

  rm -f "$log_file"
}

run_checked "Import strict du projet" godot --headless --path . --import --quit
run_checked "Smoke test noyau" godot --headless --path . res://scenes/tests/core_smoke.tscn
run_checked "Parcours campagne I→X, fin, postgame et NG+" godot --headless --path . res://scenes/tests/campaign_e2e_smoke.tscn
run_checked "Opérations joueur : scènes, expédition, équipement, capture et sauvegarde disque" godot --headless --path . res://scenes/tests/runtime_player_smoke.tscn

echo "GODOT_CI_STRICT_OK"
