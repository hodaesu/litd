from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project.godot"
PLAYABLE_SCENE = ROOT / "scenes" / "world" / "veilleurs" / "voices_under_sanctuary_playable.tscn"
SMOKE_SCENE = ROOT / "scenes" / "tests" / "veilleurs_vs001_playable_smoke.tscn"
SMOKE_SCRIPT = ROOT / "scripts" / "core" / "veilleurs_vs001_playable_smoke_test.gd"
WORLD_RUNTIME = ROOT / "scripts" / "world" / "veilleurs_vs001_world_runtime.gd"
PLAYABLE_BRIDGE = ROOT / "scripts" / "world" / "veilleurs_vs001_playable_bridge.gd"
PLAYABLE_WORLD = ROOT / "scripts" / "world" / "veilleurs_vs001_playable_world.gd"
BLOCKOUT = ROOT / "scripts" / "world" / "veilleurs_vs001_blockout_builder.gd"
GAME_STATE = ROOT / "scripts" / "core" / "game_state.gd"
PHYSICAL_MAP = ROOT / "data" / "dungeons" / "voices_under_sanctuary_physical_map.json"
GODOT_CI = ROOT / "tools" / "build" / "run_godot_ci.sh"

WATCHER_IDS = ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"]
WATCHER_NAMES = ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def audit() -> list[str]:
    errors: list[str] = []
    required_files = [
        PLAYABLE_SCENE,
        SMOKE_SCENE,
        SMOKE_SCRIPT,
        WORLD_RUNTIME,
        PLAYABLE_BRIDGE,
        PLAYABLE_WORLD,
        BLOCKOUT,
        GAME_STATE,
        PHYSICAL_MAP,
        GODOT_CI,
    ]
    for path in required_files:
        if not path.exists():
            errors.append(f"missing_file:{path.relative_to(ROOT)}")
    if errors:
        return errors

    project = _text(PROJECT)
    bridge = _text(PLAYABLE_BRIDGE)
    world = _text(PLAYABLE_WORLD)
    runtime = _text(WORLD_RUNTIME)
    blockout = _text(BLOCKOUT)
    game_state = _text(GAME_STATE)
    playable_scene = _text(PLAYABLE_SCENE)
    smoke_scene = _text(SMOKE_SCENE)
    smoke_script = _text(SMOKE_SCRIPT)
    ci = _text(GODOT_CI)
    physical = json.loads(_text(PHYSICAL_MAP))

    if 'VeilleursVS001WorldRuntime="*res://scripts/world/veilleurs_vs001_world_runtime.gd"' not in project:
        errors.append("autoload_world_runtime")
    if 'VeilleursVS001PlayableBridge="*res://scripts/world/veilleurs_vs001_playable_bridge.gd"' not in project:
        errors.append("autoload_playable_bridge")
    if 'DeepVestigeBossRuntime="*res://scripts/world/deep_vestige_boss_runtime_v2.gd"' not in project:
        errors.append("deep_vestige_autoload_regression")

    for watcher_id in WATCHER_IDS:
        if f'"id": "{watcher_id}"' not in bridge:
            errors.append(f"watcher_id_missing:{watcher_id}")
    for watcher_name in WATCHER_NAMES:
        if f'"name": "{watcher_name}"' not in bridge:
            errors.append(f"watcher_name_missing:{watcher_name}")
    if '"id": "aurelien"' in bridge or '"name": "Aurélien"' in bridge:
        errors.append("aurelien_must_not_be_watcher")
    if 'watcher["race_id"] = "human"' not in bridge:
        errors.append("watchers_human_contract")
    if "previous_party = GameState.party.duplicate(true)" not in bridge or "restore_previous_party" not in bridge:
        errors.append("party_restore_contract")

    if "voices_under_sanctuary_blockout.tscn" not in playable_scene:
        errors.append("playable_scene_missing_blockout")
    if "veilleurs_vs001_playable_world.gd" not in playable_scene:
        errors.append("playable_scene_missing_controller")

    anchors = physical.get("gameplay_anchors", [])
    expected_interactions = len([a for a in anchors if a.get("id") != "entry_spawn"])
    rooms = physical.get("rooms", [])
    if len(rooms) != 8:
        errors.append("physical_room_count_changed")
    if expected_interactions != 16:
        errors.append("playable_interaction_count_changed")

    world_contracts = [
        "_build_room_sensors()",
        "_build_interaction_proxies()",
        "VeilleursVS001WorldRuntime.enter_room(room_id)",
        "VeilleursVS001WorldRuntime.preview_anchor(anchor_id)",
        "VeilleursVS001WorldRuntime.execute_anchor_action(current_anchor_id, action_id)",
        "blockout.set_secret_connection_open(bool(state_value.get(\"s8_unlocked\", false)))",
        "CONFIRMER · ",
    ]
    for contract in world_contracts:
        if contract not in world:
            errors.append(f"playable_world_contract:{contract}")

    if "AshlandsCombatBridge.begin(encounter_id, \"normal\")" not in runtime:
        errors.append("shared_combat_bridge_missing")
    if '"vs001_s3_ghouls"' not in runtime or '"vs001_s7_ghouls"' not in runtime:
        errors.append("authored_combat_encounters_missing")
    if '"hungry_standard", "hungry_standard", "hungry_scout"' not in runtime:
        errors.append("s3_composition_contract")
    if '"voracious_evolved", "hungry_standard", "hungry_standard"' not in runtime:
        errors.append("s7_composition_contract")
    if "GameState.battle_rounds = 0" not in runtime:
        errors.append("battle_round_reset_missing")
    if "var battle_rounds := 0" not in game_state:
        errors.append("battle_round_state_missing")

    if "set_secret_connection_open(false)" not in blockout:
        errors.append("secret_must_start_locked")
    if "_set_collision_enabled_recursive(secret, is_open)" not in blockout:
        errors.append("secret_collision_gate_missing")
    if "secret_connection_locked()" not in blockout or "secret_connection_open()" not in blockout:
        errors.append("secret_physical_state_contract")

    smoke_contracts = [
        "Aurélien must never be a Watcher in VS001",
        "sensors.size() == 8",
        "interactables.size() == 16",
        "Previewing information must not mutate authoritative session state",
        "S8 secret path must begin invisible and physically non-colliding",
        "Unlocked S8 must become an actual traversable session room",
        "Leaving VS001 must restore the previous game party exactly",
        "VEILLEURS_VS001_PLAYABLE_SMOKE_OK",
    ]
    for contract in smoke_contracts:
        if contract not in smoke_script:
            errors.append(f"smoke_contract_missing:{contract}")
    if "veilleurs_vs001_playable_smoke_test.gd" not in smoke_scene:
        errors.append("smoke_scene_binding")
    if "veilleurs_vs001_playable_smoke.tscn" not in ci:
        errors.append("godot_ci_playable_smoke_missing")

    return errors


def main() -> int:
    errors = audit()
    print(json.dumps({"system": "veilleurs_vs001_playable", "ok": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
