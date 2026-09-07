#!/usr/bin/env python3
"""Audit du verrou pré-PC de LITD : Les Veilleurs.

Ce contrôle ne prétend pas remplacer les tests sur appareil réel. Il vérifie que
le dépôt contient et relie tout ce qui peut être sécurisé avant ce passage.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/veilleurs/pre_pc_gate.json"
REPORT = ROOT / "build/automation/veilleurs_pre_pc_status.json"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def scan_runtime_files() -> list[Path]:
    roots = [
        ROOT / "scripts/core",
        ROOT / "scripts/ui",
        ROOT / "scripts/world",
        ROOT / "scripts/qa",
        ROOT / "scenes/veilleurs",
        ROOT / "scenes/tests",
        ROOT / "data/veilleurs",
    ]
    result: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path == CONTRACT:
                continue
            if path.is_file() and path.suffix.lower() in {".gd", ".tscn", ".tres", ".json"}:
                result.append(path)
    return result


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    checks: dict[str, bool] = {}

    contract = load_json(CONTRACT)

    missing = [p for p in contract["required_files"] if not (ROOT / p).exists()]
    checks["required_files"] = not missing
    if missing:
        fail(errors, "Fichiers requis absents: " + ", ".join(missing))

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    checks["godot_version"] = 'config/features=PackedStringArray("4.7")' in project_text
    if not checks["godot_version"]:
        fail(errors, "project.godot ne verrouille pas Godot 4.7")
    checks["android_etc2_astc"] = "textures/vram_compression/import_etc2_astc=true" in project_text
    if not checks["android_etc2_astc"]:
        fail(errors, "La compression ETC2/ASTC requise pour l'export Android Godot 4.7 n'est pas activée")

    plugin_entry = 'res://addons/veilleurs_pipeline/plugin.cfg'
    checks["editor_pipeline_enabled"] = "[editor_plugins]" in project_text and plugin_entry in project_text
    if not checks["editor_pipeline_enabled"]:
        fail(errors, "L'addon Veilleurs Production Pipeline n'est pas activé dans project.godot")

    export_text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    missing_presets = [name for name in contract["required_export_presets"] if f'name="{name}"' not in export_text]
    checks["export_presets"] = not missing_presets
    if missing_presets:
        fail(errors, "Presets d'export absents: " + ", ".join(missing_presets))
    checks["android_package_identity"] = 'package/unique_name="com.hodaesu.lightinthedark"' in export_text
    if not checks["android_package_identity"]:
        fail(errors, "L'identité de package Android stable com.hodaesu.lightinthedark est absente")

    workflow_path = ROOT / ".github/workflows/veilleurs-production-automation.yml"
    workflow_text = workflow_path.read_text(encoding="utf-8") if workflow_path.is_file() else ""
    android_markers = [
        "android-debug-export:",
        "Android debug APK export",
        'godot --headless --path . --export-debug "Android" build/android/LightInTheDark.apk',
        "test -s build/android/LightInTheDark.apk",
        "veilleurs-android-debug-apk",
    ]
    checks["android_debug_export_ci"] = all(marker in workflow_text for marker in android_markers)
    if not checks["android_debug_export_ci"]:
        fail(errors, "Le gate CI d'export Android debug est absent ou incomplet")
    checks["android_ci_not_fake_ios"] = '--export-debug "iOS"' not in workflow_text and '--export-release "iOS"' not in workflow_text
    if not checks["android_ci_not_fake_ios"]:
        fail(errors, "Le workflow Linux prétend valider un export iOS signé")

    wave3 = load_json(ROOT / "data/veilleurs/v09/wave3_contract.json")
    actual_dungeons = wave3.get("vertical_slice", {}).get("dungeon_ids", [])
    checks["six_dungeons"] = actual_dungeons == contract["production_dungeons"]
    if not checks["six_dungeons"]:
        fail(errors, f"Contrat six donjons différent: {actual_dungeons}")

    actual_qa = wave3.get("vertical_slice", {}).get("qa_requires", [])
    checks["v09_qa_contract"] = actual_qa == contract["v09_qa_requires"]
    if not checks["v09_qa_contract"]:
        fail(errors, f"Contrat QA v0.9 différent: {actual_qa}")

    runtime_path = ROOT / "scripts/core/veilleurs_vertical_slice_runtime_v08.gd"
    runtime_text = runtime_path.read_text(encoding="utf-8")
    roster_match = re.search(r"const CANONICAL_WATCHERS: Array\[String\] = \[(.*?)\]", runtime_text)
    roster: list[str] = []
    if roster_match:
        roster = re.findall(r'"([^"]+)"', roster_match.group(1))
    checks["canonical_roster"] = roster == contract["canonical_watchers"]
    if not checks["canonical_roster"]:
        fail(errors, f"Roster canonique runtime différent: {roster}")

    allowed_stale_files = set(contract.get("allowed_stale_reference_files", []))
    stale_hits: dict[str, list[str]] = {}
    for path in scan_runtime_files():
        relative = path.relative_to(ROOT).as_posix()
        if relative in allowed_stale_files:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for stale_id in contract["forbidden_stale_runtime_ids"]:
            if stale_id in text:
                stale_hits.setdefault(stale_id, []).append(relative)
    checks["stale_runtime_ids"] = not stale_hits
    if stale_hits:
        for stale_id, paths in stale_hits.items():
            fail(errors, f"Identifiant obsolète {stale_id}: " + ", ".join(paths))

    polish = load_json(ROOT / "data/veilleurs/polish_manifest.json")
    ultimates = polish.get("ultimate_assets", [])
    checks["ultimate_count"] = len(ultimates) == int(contract["expected_ultimate_count"])
    if not checks["ultimate_count"]:
        fail(errors, f"Nombre d'ultimes dans polish_manifest: {len(ultimates)}")

    ultimate_errors: list[str] = []
    for index, ultimate in enumerate(ultimates):
        label = ultimate.get("name", f"ultimate_{index}")
        slots = ultimate.get("asset_slots", {})
        for slot in contract["required_ultimate_asset_slots"]:
            if slots.get(slot) != "required":
                ultimate_errors.append(f"{label}: slot {slot} non verrouillé")
        validation = ultimate.get("validation", [])
        for target in contract["required_ultimate_validation_targets"]:
            if target not in validation:
                ultimate_errors.append(f"{label}: validation {target} absente")
        if not ultimate.get("mechanic") or not ultimate.get("beats"):
            ultimate_errors.append(f"{label}: mécanique ou chorégraphie absente")
    checks["ultimate_handoff_contract"] = not ultimate_errors
    if ultimate_errors:
        errors.extend(ultimate_errors)

    pipeline = load_json(ROOT / "tools/godot/veilleurs_pipeline_config.json")
    checks["pipeline_godot_version"] = pipeline.get("godot_version") == contract.get("godot_version") == "4.7"
    if not checks["pipeline_godot_version"]:
        fail(errors, f"Version Godot incohérente entre contrat et pipeline: {contract.get('godot_version')} / {pipeline.get('godot_version')}")

    this_audit = "tools/qa/veilleurs_pre_pc_audit.py"
    checks["pre_pc_audit_wired"] = this_audit in pipeline.get("python_audits", [])
    if not checks["pre_pc_audit_wired"]:
        fail(errors, "L'audit pré-PC n'est pas câblé dans le pipeline Veilleurs")

    intake_audit = "tools/qa/veilleurs_content_intake_audit.py"
    checks["content_intake_audit_wired"] = intake_audit in pipeline.get("python_audits", [])
    if not checks["content_intake_audit_wired"]:
        fail(errors, "L'audit d'intake de contenu n'est pas câblé dans le pipeline Veilleurs")

    intake = load_json(ROOT / "data/veilleurs/content_intake_contract.json")
    expected_intake_types = {"watcher", "enemy", "boss", "dungeon", "ui_screen", "ultimate", "generic"}
    checks["content_intake_types"] = set(intake.get("supported_types", {})) == expected_intake_types
    if not checks["content_intake_types"]:
        fail(errors, "Les types d'intake de contenu sont incomplets")
    intake_rules = intake.get("rules", {})
    required_intake_rules = {
        "presentation_never_decides_gameplay",
        "reservation_never_mutates_canonical_gameplay",
        "work_order_presence_reserves_id",
        "duplicate_canonical_ids_forbidden",
        "duplicate_reserved_ids_forbidden",
        "path_traversal_forbidden",
    }
    checks["content_intake_guardrails"] = required_intake_rules.issubset(intake_rules)
    if not checks["content_intake_guardrails"]:
        fail(errors, "Les garde-fous de réservation d'intake sont incomplets")

    smoke_scenes = {row.get("scene") for row in pipeline.get("quick_godot_smokes", [])}
    essential_smokes = {
        "res://scenes/tests/veilleurs_v06_tactical_smoke.tscn",
        "res://scenes/tests/veilleurs_v07_production_smoke.tscn",
        "res://scenes/tests/veilleurs_v08_wave2_smoke.tscn",
        "res://scenes/tests/veilleurs_v09_wave3_smoke.tscn",
        "res://scenes/veilleurs/v09_vertical_slice_qa.tscn",
        "res://scenes/tests/mobile_touch_smoke.tscn",
        "res://scenes/tests/ui_player_journey_smoke.tscn",
    }
    checks["essential_smokes_wired"] = essential_smokes.issubset(smoke_scenes)
    if not checks["essential_smokes_wired"]:
        fail(errors, "Les smokes essentiels v0.6→v0.9/mobile/UI ne sont pas tous câblés dans le pipeline rapide")

    pc_preflight_path = ROOT / "tools/workstation/veilleurs_pc_preflight.py"
    pc_preflight_text = pc_preflight_path.read_text(encoding="utf-8") if pc_preflight_path.exists() else ""
    tools_match = re.search(r"REQUIRED_TOOLS\s*=\s*\{(.*?)\n\}", pc_preflight_text, re.DOTALL)
    first_pc_tools: list[str] = []
    if tools_match:
        first_pc_tools = re.findall(r'^\s*"([^"]+)"\s*:', tools_match.group(1), re.MULTILINE)
    checks["dedicated_pc_preflight"] = first_pc_tools == contract.get("required_first_pc_tools", [])
    if not checks["dedicated_pc_preflight"]:
        fail(errors, f"Préflight PC Veilleurs trop lourd ou incomplet: {first_pc_tools}")
    checks["pc_preflight_godot_47"] = 'godot_compatible = "4.7" in godot_version' in pc_preflight_text
    if not checks["pc_preflight_godot_47"]:
        fail(errors, "Le préflight PC n'accepte pas explicitement la famille Godot 4.7.x")

    launcher_text = (ROOT / "tools/workstation/LITD_VEILLEURS_PC_PREPARE.cmd").read_text(encoding="utf-8")
    checks["pc_preflight_launcher"] = "veilleurs_pc_preflight.py --run-tests" in launcher_text
    if not checks["pc_preflight_launcher"]:
        fail(errors, "Le lanceur PC Veilleurs n'appelle pas le préflight dédié avec les tests")

    hardware_gates = contract.get("hardware_only_gates", [])
    checks["hardware_boundary_declared"] = len(hardware_gates) >= 8 and all(g.get("id") and g.get("reason") for g in hardware_gates)
    if not checks["hardware_boundary_declared"]:
        fail(errors, "La frontière des validations matérielles n'est pas complète")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    status = {
        "stage": contract.get("stage"),
        "ok": not errors,
        "checks": checks,
        "errors": errors,
        "warnings": warnings,
        "hardware_only_gates": hardware_gates,
        "message": "PRE_PC_AUTOMATION_COMPLETE" if not errors else "PRE_PC_AUTOMATION_BLOCKED",
    }
    REPORT.write_text(json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("VEILLEURS_PRE_PC_FAILED")
        for message in errors:
            print("ERROR:", message)
        return 1

    print("VEILLEURS_PRE_PC_OK")
    print(f"Automated checks: {len(checks)}")
    print(f"Hardware-only gates remaining: {len(hardware_gates)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
