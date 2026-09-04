from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FILES = {
    "save": ROOT / "scripts/core/save_manager.gd",
    "bridge": ROOT / "scripts/world/veilleurs_vs001_playable_bridge.gd",
    "persistence": ROOT / "scripts/world/veilleurs_vs001_persistence_bridge.gd",
    "layer": ROOT / "scripts/world/veilleurs_vs001_persistence_layer.gd",
    "corpse": ROOT / "scripts/world/veilleurs_vs001_corpse_proxy.gd",
    "world": ROOT / "scripts/world/veilleurs_vs001_playable_world.gd",
    "map": ROOT / "scripts/ui/veilleurs_vs001_map_view.gd",
    "scene": ROOT / "scenes/world/veilleurs/voices_under_sanctuary_playable.tscn",
}
PHYSICAL_MAP = ROOT / "data/dungeons/voices_under_sanctuary_physical_map.json"


def _text(key: str) -> str:
    return FILES[key].read_text(encoding="utf-8")


def audit() -> list[str]:
    errors: list[str] = []
    for key, path in FILES.items():
        if not path.exists():
            errors.append(f"missing:{key}:{path.relative_to(ROOT)}")
    if errors:
        return errors

    save = _text("save")
    bridge = _text("bridge")
    persistence = _text("persistence")
    layer = _text("layer")
    corpse = _text("corpse")
    world = _text("world")
    map_view = _text("map")
    scene = _text("scene")

    for token in (
        '"veilleurs_vs001": VeilleursVS001PlayableBridge.serialize()',
        'VeilleursVS001PlayableBridge.deserialize(payload.get("veilleurs_vs001",{}))',
        'payload["veilleurs_vs001"] = payload.get("veilleurs_vs001",{})',
        '"mode": "veilleurs_vs001" if VeilleursVS001WorldRuntime.is_active() else "litd1"',
    ):
        if token not in save:
            errors.append(f"save_contract:{token}")

    expected_ids = ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"]
    for watcher_id in expected_ids:
        if f'"id": "{watcher_id}"' not in bridge:
            errors.append(f"watcher_missing:{watcher_id}")
    watcher_defs = bridge.split("const WATCHER_DEFS", 1)[1].split("]", 1)[0]
    if "aurelien" in watcher_defs.lower():
        errors.append("aurelien_must_not_be_watcher")
    for token in (
        "LES VEILLEURS · VS001",
        "func resume_playable()",
        "func serialize()",
        "func deserialize(payload: Dictionary)",
        '"party_position"',
        "SaveManager.save_finished",
    ):
        if token not in bridge:
            errors.append(f"bridge_contract:{token}")

    for token in (
        '"persistent_corpse"',
        "wound_history",
        "_register_s6_survivor",
        'CreatureManager.call("_create_creature", definition)',
        "CaptureWoundRuntime.apply_to_latest_capture(enemy)",
        'RemanenceRuntime.set_entity_status(entity_id, "recruited")',
        'PersistentInjuryRuntime.apply_injury(enemy, "fracture_leg", "critical")',
    ):
        if token not in persistence:
            errors.append(f"persistence_contract:{token}")

    for token in (
        "veilleurs_vs001_persistent_corpse",
        "CapsuleMesh",
        "body_snapshot",
        "active_corpse_scars",
    ):
        if token not in layer + corpse:
            errors.append(f"corpse_materialization:{token}")

    for token in (
        'text = "CARTE"',
        'text = "SAUVER"',
        "custom_minimum_size = Vector2(118.0, 54.0)",
        "viewport_size.x < 950.0",
        "PersistentInjuryRuntime.prepare_character(hero)",
        "SaveManager.autosave",
        "KEY_M",
    ):
        if token not in world:
            errors.append(f"hud_contract:{token}")

    for token in (
        'state.get("visited_rooms", {})',
        'state.get("s8_unlocked", false)',
        'state.get("s8_discovered", false)',
        'room_id == "s8_lower_archive" and not show_secret',
    ):
        if token not in map_view:
            errors.append(f"map_knowledge_contract:{token}")

    if "VeilleursVS001PersistenceLayer" not in layer or 'name="PersistentWorld"' not in scene:
        errors.append("persistent_world_scene_missing")
    if "scene_snapshot" in persistence.lower() or "scene_snapshot" in layer.lower():
        errors.append("scene_snapshot_persistence_forbidden")

    physical = json.loads(PHYSICAL_MAP.read_text(encoding="utf-8"))
    anchors = {str(a.get("id", "")): a for a in physical.get("gameplay_anchors", [])}
    for anchor_id in ("s3_corpses", "s6_survivor", "s7_combat"):
        if anchor_id not in anchors:
            errors.append(f"required_persistence_anchor:{anchor_id}")
    if bool(physical.get("design_rules", {}).get("scene_snapshot_persistence", True)):
        errors.append("physical_map_snapshot_rule")

    return errors


def main() -> int:
    errors = audit()
    print(json.dumps({"system": "veilleurs_vs001_persistence_ui", "ok": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
