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
run_checked "Psychologie : Peur, traces durables et manifestations d'Espoir" godot --headless --path . res://scenes/tests/psychology_smoke.tscn
run_checked "Relations : confiance, admiration, tensions et interposition" godot --headless --path . res://scenes/tests/relationship_smoke.tscn
run_checked "Mémoire : décisions, convictions et conséquences différées" godot --headless --path . res://scenes/tests/decision_memory_smoke.tscn
run_checked "Mémoire de terrain : recrutement, retraite, boss et réévaluation" godot --headless --path . res://scenes/tests/field_memory_smoke.tscn
run_checked "Monde réactif : survivants, ressources et retours différés" godot --headless --path . res://scenes/tests/field_encounter_smoke.tscn
run_checked "Sanctuaire vivant : personnes, rumeurs et quêtes émergentes" godot --headless --path . res://scenes/tests/community_network_smoke.tscn
run_checked "Narration : bibliothèque transmédiatique, dialogues et mise en scène" godot --headless --path . res://scenes/tests/narrative_library_smoke.tscn
run_checked "Musique : bibliothèque, licences et accompagnement narratif" godot --headless --path . res://scenes/tests/music_library_smoke.tscn
run_checked "Parcours campagne I→X, fin, postgame et NG+" godot --headless --path . res://scenes/tests/campaign_e2e_smoke.tscn
run_checked "Opérations joueur : scènes, expédition, équipement, capture et sauvegarde disque" godot --headless --path . res://scenes/tests/runtime_player_smoke.tscn
run_checked "Parcours UI joueur : Sanctuaire, exploration, combat, récompenses et retour" timeout 90s godot --headless --path . res://scenes/tests/ui_player_journey_smoke.tscn
run_checked "Bâtiments du Sanctuaire : Chapelle, Taverne et Mémorial" timeout 60s godot --headless --path . res://scenes/tests/sanctuary_buildings_smoke.tscn
run_checked "Mobile tactile : formats iPhone, cibles tactiles et ScreenTouch" timeout 90s godot --headless --path . res://scenes/tests/mobile_touch_smoke.tscn

echo "GODOT_CI_STRICT_OK"
