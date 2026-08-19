#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_CUES = {
    "footstep_ash", "footstep_stone", "weapon_blade_hit", "weapon_blunt_hit", "parry",
    "combat_telegraph", "dismemberment", "ultimate_release", "creature_ghoul",
    "creature_conscious", "boss_phase_change", "fear_heartbeat", "fear_tinnitus",
    "panic_sting", "hope_manifestation", "wind_ashlands", "ash_storm", "door_wood",
    "bell_sanctuary", "forge_hammer", "memorial_roomtone", "trap_trigger", "ui_confirm",
    "ui_page", "ui_reward", "ui_capture",
}


def run(root: Path = ROOT) -> dict:
    library_path = root / "data/sfx_library.json"
    runtime_path = root / "scripts/core/sfx_library.gd"
    smoke_path = root / "scripts/core/sfx_library_smoke_test.gd"
    scene_path = root / "scenes/tests/sfx_library_smoke.tscn"
    project_path = root / "project.godot"
    ci_path = root / ".github/workflows/ci.yml"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"
    guide_path = root / "docs/design/sfx_library.md"

    library = json.loads(library_path.read_text(encoding="utf-8"))
    runtime = runtime_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    ci = ci_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")
    guide = guide_path.read_text(encoding="utf-8")

    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("SFX : schéma v1", int(library.get("version", 0)) >= 1)
    check("SFX : source de design", library.get("design_source") == "sound_design_library_pass_18")
    check("SFX : catalogue sans faux binaires", "Aucun binaire audio" in str(library.get("purpose", "")))

    sources = {item.get("id"): item for item in library.get("source_pools", []) if isinstance(item, dict)}
    for source_id in ["sonniss_gdc", "freesound_cc0", "freesound_ccby", "pixabay", "oga_cc0", "itch_cc0"]:
        check(f"Source SFX : {source_id}", source_id in sources)
    check("Freesound CC0 vert", sources.get("freesound_cc0", {}).get("tier") == "green")
    check("Freesound CC BY ambre", sources.get("freesound_ccby", {}).get("tier") == "amber")
    check("Pixabay ambre", sources.get("pixabay", {}).get("tier") == "amber")

    packs = [item for item in library.get("candidate_packs", []) if isinstance(item, dict)]
    pack_ids = [str(item.get("id", "")) for item in packs]
    green = [item for item in packs if item.get("tier") == "green"]
    amber = [item for item in packs if item.get("tier") == "amber"]
    check("Packs : au moins douze", len(packs) >= 12, str(len(packs)))
    check("Packs : IDs uniques", len(pack_ids) == len(set(pack_ids)))
    check("Packs : dix sources vertes minimum", len(green) >= 10, str(len(green)))
    check("Packs : ambre isolé", len(amber) >= 2, str(len(amber)))
    for item in packs:
        pack_id = str(item.get("id", ""))
        check(f"{pack_id} : URL", str(item.get("url", "")).startswith("https://"))
        check(f"{pack_id} : licence", bool(item.get("license")))
        check(f"{pack_id} : pas de faux chemin local", item.get("local_path", "") == "")
        check(f"{pack_id} : source connue", item.get("source") in sources)
        check(f"{pack_id} : niveau légal", item.get("tier") in {"green", "amber", "red"})

    domains = library.get("cue_domains", {})
    cue_ids = {str(cue) for values in domains.values() if isinstance(values, list) for cue in values}
    check("Cues : douze domaines", len(domains) >= 12, str(len(domains)))
    check("Cues : quatre-vingts familles minimum", len(cue_ids) >= 80, str(len(cue_ids)))
    for cue_id in sorted(REQUIRED_CUES):
        check(f"Cue SFX : {cue_id}", cue_id in cue_ids)

    metadata = library.get("cue_metadata", {})
    for cue_id in ["dismemberment", "combat_telegraph", "ultimate_release", "creature_conscious", "fear_heartbeat", "hope_manifestation", "bell_sanctuary"]:
        check(f"Metadata critique : {cue_id}", cue_id in metadata)
    check("Démembrement : gore retenu", "restrained" in str(metadata.get("dismemberment", {}).get("brief", "")))
    check("Ultimes : signature", "signature" in str(metadata.get("ultimate_release", {}).get("brief", "")))
    check("Créature consciente : intelligence", "intelligent" in str(metadata.get("creature_conscious", {}).get("brief", "")))

    check("Layering : sept presets", len(library.get("layering_presets", [])) >= 7)
    check("Sound design : seize règles", len(library.get("implementation_rules", [])) >= 16)
    check("Ingestion : seize étapes", len(library.get("ingestion_checklist", [])) >= 16)
    exclusions = {item.get("id") for item in library.get("excluded_license_classes", []) if isinstance(item, dict)}
    for exclusion in ["cc_by_nc", "unknown_license", "editorial_only", "recognizable_franchise", "unverified_voice"]:
        check(f"Exclusion : {exclusion}", exclusion in exclusions)

    mix = library.get("mix_priorities", {})
    priority = mix.get("priority_order", [])
    check("Mix : dialogue avant musique", priority and priority[0] == "critical_dialogue" and priority[-1] == "music")
    check("Mix : ducking dialogue", int(mix.get("critical_dialogue_ducking_db", 0)) < 0)

    for token in [
        'const DATA_PATH := "res://data/sfx_library.json"',
        "func candidate_packs()", "func shipping_candidate_packs(", "func cue_ids()",
        "func cues_for_domain(", "func cue_metadata(", "func packs_for_cue(",
        "func attribution_lines()", "func coverage()",
    ]:
        check(f"Runtime SFX : {token}", token in runtime)

    check("Projet : SfxLibrary autoload", 'SfxLibrary="*res://scripts/core/sfx_library.gd"' in project)
    check("Smoke : runner SFX", "SfxLibrary.coverage()" in smoke)
    check("Smoke : scène SFX", "sfx_library_smoke_bootstrap.gd" in scene)
    check("Godot CI : smoke SFX", "sfx_library_smoke.tscn" in godot_ci)
    check("CI : audit SFX", "python -m tools.qa.sfx_library_audit" in ci)

    check("Documentation : Freesound", "Freesound" in guide)
    check("Documentation : Sonniss", "Sonniss" in guide)
    check("Documentation : Pixabay", "Pixabay" in guide)
    check("Documentation : voix", "voix" in guide.lower())
    check("Documentation : iPhone", "iPhone" in guide)
    check("Documentation : pas de faux binaires", "n'importe aucun binaire audio" in guide)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "sfx-library-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
