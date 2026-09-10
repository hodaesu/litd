#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

DOMAIN="${1:-}"
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

scene() {
  local timeout_s="$1"
  local label="$2"
  local path="$3"
  if [[ "$timeout_s" == "0" ]]; then
    run_checked "$label" godot --headless --path . "$path"
  else
    run_checked "$label" timeout "${timeout_s}s" godot --headless --path . "$path"
  fi
}

run_checked "Import strict du projet" godot --headless --path . --import --quit

case "$DOMAIN" in
  core-world)
    scene 0 "Smoke test noyau" res://scenes/tests/core_smoke.tscn
    scene 0 "Psychologie" res://scenes/tests/psychology_smoke.tscn
    scene 0 "Relations" res://scenes/tests/relationship_smoke.tscn
    scene 0 "Mémoire des décisions" res://scenes/tests/decision_memory_smoke.tscn
    scene 0 "Mémoire de terrain" res://scenes/tests/field_memory_smoke.tscn
    scene 0 "Monde réactif" res://scenes/tests/field_encounter_smoke.tscn
    scene 0 "Sanctuaire vivant" res://scenes/tests/community_network_smoke.tscn
    scene 0 "Croisements systémiques" res://scenes/tests/systemic_cross_smoke.tscn
    scene 0 "Croisements narratifs" res://scenes/tests/systemic_cross_narrative_smoke.tscn
    scene 0 "Conséquences différées" res://scenes/tests/systemic_cross_afterlife_smoke.tscn
    scene 0 "Relations des Sept" res://scenes/tests/legendary_seven_relationship_smoke.tscn
    scene 60 "Hall des Descendants" res://scenes/tests/descendants_hall_smoke.tscn
    scene 60 "Bâtiments du Sanctuaire" res://scenes/tests/sanctuary_buildings_smoke.tscn
    ;;
  audiovisual)
    scene 0 "Narration" res://scenes/tests/narrative_library_smoke.tscn
    scene 0 "Musique" res://scenes/tests/music_library_smoke.tscn
    scene 0 "Bruitages" res://scenes/tests/sfx_library_smoke.tscn
    scene 0 "Audio adaptatif" res://scenes/tests/audio_director_smoke.tscn
    scene 0 "Entraînement musical adaptatif" res://scenes/tests/adaptive_music_smoke.tscn
    scene 0 "Orchestration verticale" res://scenes/tests/layered_music_smoke.tscn
    scene 0 "Audio runtime" res://scenes/tests/audio_runtime_smoke.tscn
    scene 0 "Audio narratif" res://scenes/tests/narrative_audio_smoke.tscn
    scene 0 "Dialogues réactifs" res://scenes/tests/dialogue_director_smoke.tscn
    scene 0 "Voix synthétiques" res://scenes/tests/voice_runtime_smoke.tscn
    scene 0 "Mise en scène cinématique" res://scenes/tests/cinematic_direction_smoke.tscn
    scene 0 "Corps" res://scenes/tests/body_state_smoke.tscn
    scene 0 "Animation visible" res://scenes/tests/body_state_visual_smoke.tscn
    scene 0 "Mouvements" res://scenes/tests/movement_registry_smoke.tscn
    scene 90 "Direction artistique canonique v41" res://scenes/tests/canonical_art_v41_smoke.tscn
    scene 90 "Corps visuel systémique v42" res://scenes/tests/body_visual_v42_smoke.tscn
    ;;
  runtime)
    scene 0 "HUD intelligent" res://scenes/tests/hud_director_smoke.tscn
    scene 0 "Vertical slice visuel" res://scenes/tests/visual_vertical_slice_smoke.tscn
    scene 0 "Vertical slice runtime" res://scenes/tests/visual_slice_runtime_smoke.tscn
    scene 0 "Parcours campagne" res://scenes/tests/campaign_e2e_smoke.tscn
    scene 0 "Opérations joueur" res://scenes/tests/runtime_player_smoke.tscn
    scene 0 "Première Descente" res://scenes/tests/first_descent_smoke.tscn
    scene 60 "Donjon physique" res://scenes/tests/physical_dungeon_smoke.tscn
    scene 60 "Blockout 3D" res://scenes/tests/first_veil_proxy_smoke.tscn
    scene 60 "Guidage des cendres" res://scenes/tests/ash_guidance_smoke.tscn
    ;;
  veilleurs)
    scene 0 "Les Veilleurs VS001" res://scenes/tests/veilleurs_vs001_smoke.tscn
    scene 60 "Les Veilleurs VS001 physique" res://scenes/tests/veilleurs_vs001_physical_smoke.tscn
    scene 90 "Les Veilleurs VS001 jouable" res://scenes/tests/veilleurs_vs001_playable_smoke.tscn
    scene 90 "Les Veilleurs VS001 persistance" res://scenes/tests/veilleurs_vs001_persistence_ui_smoke.tscn
    scene 90 "Les Veilleurs canon" res://scenes/tests/veilleurs_canonical_skills_corpses_smoke.tscn
    scene 90 "Entaille, Anatomie et Suture" res://scenes/tests/veilleurs_entaille_anatomie_suture_smoke.tscn
    scene 90 "Réactions cliniques" res://scenes/tests/veilleurs_clinical_reactions_smoke.tscn
    scene 90 "Hémocorde" res://scenes/tests/veilleurs_hemocorde_smoke.tscn
    scene 90 "Hémocorde réactions" res://scenes/tests/veilleurs_hemocorde_reactions_smoke.tscn
    ;;
  ui-qa)
    scene 90 "Parcours UI joueur" res://scenes/tests/ui_player_journey_smoke.tscn
    scene 90 "Interface canonique Les Veilleurs" res://scenes/tests/canonical_ui_smoke.tscn
    scene 90 "Finition UX canonique" res://scenes/tests/canonical_ux_smoke.tscn
    scene 90 "Mobile tactile" res://scenes/tests/mobile_touch_smoke.tscn
    scene 90 "Salle QA intégrée" res://scenes/tests/qa_validation_room_smoke.tscn
    ;;
  *)
    echo "Usage: $0 {core-world|audiovisual|runtime|veilleurs|ui-qa}" >&2
    exit 2
    ;;
esac

echo "GODOT_CI_DOMAIN_OK:${DOMAIN}"
