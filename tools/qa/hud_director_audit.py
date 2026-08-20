from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def audit() -> list[str]:
    errors: list[str] = []
    contract = _load("data/hud_director_contract.json")
    final_ui = _load("data/final_ui_contract.json")

    if contract.get("exploration", {}).get("default_level") != 0:
        errors.append("Exploration HUD must default to level 0")
    if contract.get("combat", {}).get("visual_groups_max") != 3:
        errors.append("Combat HUD must be limited to three visual groups")
    if contract.get("combat", {}).get("status_icons_visible_max") != 2:
        errors.append("Status icon aggregation must start after two icons")
    if not contract.get("priorities", {}).get("INFORMATION", {}).get("defer_when_critical"):
        errors.append("INFORMATION must defer while CRITICAL is active")
    if contract.get("motion", {}).get("persistent_blinking") is not False:
        errors.append("Persistent blinking is forbidden")
    if not contract.get("palette", {}).get("information_never_color_only"):
        errors.append("Information must never rely on color alone")
    if float(contract.get("accessibility", {}).get("normal_contrast_ratio_min", 0)) < 4.5:
        errors.append("Normal contrast floor must be at least 4.5:1")
    if int(contract.get("touch", {}).get("touch_target_min_px", 0)) < 48:
        errors.append("Touch target minimum must be at least 48 px")

    if final_ui.get("hud_director_contract") != "data/hud_director_contract.json":
        errors.append("final_ui_contract.json must point to HUD Director contract")

    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'HUDDirector="*res://scripts/ui/hud_director.gd"' not in project:
        errors.append("HUDDirector autoload is missing")

    context_hud = (ROOT / "scripts/ui/context_hud.gd").read_text(encoding="utf-8")
    if "HUDDirector.route_event" not in context_hud:
        errors.append("ContextHUD must route notifications through HUDDirector")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        print("HUD_DIRECTOR_AUDIT_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("HUD_DIRECTOR_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
