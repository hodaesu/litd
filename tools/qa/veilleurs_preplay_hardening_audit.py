#!/usr/bin/env python3
"""Static pre-play gate for the Chapter I developer self-test.

This gate intentionally does not pretend to validate feel, visual readability or
human comprehension. It only proves that the minimal UI, Sanctuary loop contract,
canonical roster and 3D greybox hooks required before the first PC self-test are
still present and wired into the active Main scene.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/preplay_hardening_contract.json"
SELFTEST_PATH = ROOT / "data/veilleurs/developer_selftest_contract.json"
REPORT_PATH = ROOT / "build/automation/veilleurs_preplay_hardening.json"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def require_file(errors: list[str], rel: str) -> Path:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"Fichier requis absent: {rel}")
    return path


def require_tokens(errors: list[str], rel: str, tokens: list[str]) -> None:
    path = require_file(errors, rel)
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            errors.append(f"Hook pré-play absent dans {rel}: {token}")


def main() -> int:
    errors: list[str] = []
    checks: dict[str, bool] = {}

    contract = load_json(CONTRACT_PATH)
    selftest = load_json(SELFTEST_PATH)

    expected_watchers = ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
    checks["canonical_watchers"] = (
        contract.get("canonical_watchers") == expected_watchers
        and selftest.get("canonical_watchers") == expected_watchers
    )
    if not checks["canonical_watchers"]:
        errors.append("Le quatuor du gate pré-play diverge du canon du self-test.")

    contract_steps = contract.get("required_selftest_steps", [])
    selftest_steps = [row.get("id") for row in selftest.get("steps", [])]
    checks["selftest_sequence"] = contract_steps == selftest_steps and len(contract_steps) == 8
    if not checks["selftest_sequence"]:
        errors.append(f"Séquence self-test divergente: contrat={contract_steps}, runtime={selftest_steps}")

    # Active Main scene: current gameplay, polish and telemetry must be present together.
    require_tokens(errors, "scenes/Main.tscn", [
        'res://scripts/ui/main_v43.gd',
        'res://scripts/ui/hud_context_sanctuary_polish_adapter.gd',
        'res://scripts/qa/developer_selftest_overlay.gd',
        'HUDContextSanctuaryPolishAdapter',
        'DeveloperSelftestOverlay',
    ])

    # Contextual decision readability: action remains inspectable when invalid,
    # explicit reason is exposed, and touch targets stay large enough for mobile parity.
    require_tokens(errors, "scripts/ui/main_v43.gd", [
        "PLAYTEST_MIN_TOUCH",
        "Touchez pour voir pourquoi",
        "aucune cible n'est actuellement atteignable",
        "show_guild_chest",
        "_render_combat_position_menu",
    ])
    require_tokens(errors, "scripts/ui/context_menu_ui_v2.gd", [
        '"inventory": "INVENTAIRE"',
        '"equipment": "ÉQUIPEMENT"',
        '"skills": "COMPÉTENCES"',
        '"journal": "JOURNAL"',
        '"options": "OPTIONS"',
        "show_item_details",
        "selected_skill_id",
        "selected_equipment_slot",
    ])
    require_tokens(errors, "scripts/ui/hud_context_sanctuary_polish_adapter.gd", [
        '"combat":',
        '"contextual":',
        '"sanctuary":',
        "_polish_combat_hud",
        "_polish_contextual_screen",
        "_polish_sanctuary",
        'hero.get("fear", 0)',
        'hero.get("madness", 0)',
    ])

    tabs = contract.get("contextual_ui", {}).get("required_tabs", [])
    checks["contextual_tabs_scope"] = tabs == ["inventory", "equipment", "skills", "journal", "options"]
    if not checks["contextual_tabs_scope"]:
        errors.append("Les onglets contextuels du self-test ont dérivé.")

    sanctuary = contract.get("sanctuary_loop", {}).get("required_sequence", [])
    checks["sanctuary_loop_scope"] = sanctuary == [
        "return_from_expedition",
        "persistent_consequence_visible",
        "inspect_four_watchers",
        "limited_preparation",
        "depart",
        "return_again",
        "save_resume",
    ]
    if not checks["sanctuary_loop_scope"]:
        errors.append("La boucle minimale du Sanctuaire a dérivé.")

    # 3D preparation is intentionally a compact greybox gate, not an art-completion gate.
    for rel in contract.get("three_d_vertical", {}).get("runtime_files", []):
        require_file(errors, rel)
    require_tokens(errors, "scenes/world/terre_des_cendres/ashlands_blockout_zone.tscn", [
        'node name="Navigation"',
        'node name="Encounters"',
        'node name="Resources"',
        'node name="Shortcuts"',
        'node name="Transitions"',
        'node name="Audio"',
        'node name="VFX"',
    ])
    require_tokens(errors, "scripts/world/ashlands_blockout_builder.gd", [
        "_build_floor()",
        "_build_boundaries()",
        "_build_authored_routes()",
        "_build_navigation_placeholder()",
        "_build_performance_probe()",
        "_build_entry_and_exits()",
        "_build_encounter_slots()",
        "_build_resource_slots()",
        "critical_path",
        "NavigationMesh",
    ])

    spaces = contract.get("three_d_vertical", {}).get("required_spaces", [])
    checks["compact_3d_scope"] = spaces == [
        "compact_sanctuary",
        "short_exterior_exploration",
        "interior_position_anatomy_fear_madness",
        "elite_arena",
    ]
    if not checks["compact_3d_scope"]:
        errors.append("Le périmètre 3D de la verticale n'est plus limité aux quatre espaces du self-test.")

    deferred = set(contract.get("three_d_vertical", {}).get("deferred", []))
    checks["deferred_3d_expansion"] = {
        "all_16_zones_polish",
        "final_blender_environment",
        "hero_asset_pass",
        "full_set_dressing",
        "late_game_locations",
    }.issubset(deferred)
    if not checks["deferred_3d_expansion"]:
        errors.append("Le contrat ne protège plus suffisamment la verticale contre l'expansion 3D prématurée.")

    checks["required_files_and_hooks"] = not errors
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "gate": "veilleurs_preplay_hardening",
        "status": "PASS" if not errors else "FAIL",
        "checks": checks,
        "errors": errors,
        "human_validation_still_required": [
            "visual_readability",
            "navigation_feel",
            "comprehension",
            "pace",
            "frustration",
            "final_3d_judgement",
        ],
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("VEILLEURS_PREPLAY_HARDENING_FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("VEILLEURS_PREPLAY_HARDENING_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
