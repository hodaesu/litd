#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def run(root: Path = ROOT) -> dict:
    contract = json.loads((root / "data/visual_vertical_slice.json").read_text(encoding="utf-8"))
    jobs = json.loads((root / "data/blender/visual_vertical_slice_jobs.json").read_text(encoding="utf-8"))
    proxy = (root / "scripts/world/visual_vertical_slice_proxy.gd").read_text(encoding="utf-8")
    cel_shader = (root / "shaders/litd_cel.gdshader").read_text(encoding="utf-8")
    outline_shader = (root / "shaders/litd_outline.gdshader").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    refs = contract.get("reference_rules", {})
    check("Référence : Art Bible autoritaire", refs.get("art_bible_is_authoritative") is True)
    check("Référence : anciens assets non prioritaires", refs.get("older_assets_must_not_override_approved_direction") is True)
    check("Référence : ingestion binaire reportée au PC", refs.get("binary_reference_status") == "pending_manual_pc_ingest")

    art = contract.get("art_direction", {})
    forbidden = set(art.get("forbidden_drift", []))
    check("DA : micro-détails diffus interdits", "micro_details_sur_toute_la_surface" in forbidden)
    check("DA : PBR photoréaliste interdit", "pbr_photorealiste" in forbidden)
    check("DA : micro-détail plafonné", float(art.get("detail_distribution", {}).get("micro_detail", 1.0)) <= 0.2)

    slice_data = contract.get("slice", {})
    check("Slice : Darius héros étalon", slice_data.get("hero_id") == "darius")
    check("Slice : Goule affamée ennemi étalon", slice_data.get("enemy_id") == "enemy_01_goule_affamee")
    check("Slice : scène proxy déclarée", slice_data.get("target_scene") == "res://scenes/visual/visual_vertical_slice_proxy.tscn")

    characters = contract.get("characters", {})
    darius = characters.get("darius", {})
    ghoul = characters.get("enemy_01_goule_affamee", {})
    check("Darius : bouclier et lanterne obligatoires", {"large_shield", "lantern"} <= set(darius.get("mandatory_shapes", [])))
    check("Goule : bras longs et griffes obligatoires", {"elongated_forearms", "claws"} <= set(ghoul.get("mandatory_shapes", [])))
    check("Animations : Darius minimum complet", len(darius.get("animation_minimum", [])) >= 8)
    check("Animations : Goule minimum complet", len(ghoul.get("animation_minimum", [])) >= 7)

    arena = contract.get("arena", {})
    check("Arène : 20x30 m", arena.get("size_m") == [20.0, 30.0])
    check("Arène : zone combat dégagée", arena.get("playable_clear_zone_m") == [12.0, 18.0])
    check("Arène : règle anti-occlusion", "silhouette" in str(arena.get("clutter_rule", "")))

    check("Shader : toon natif Godot", "diffuse_toon" in cel_shader)
    check("Shader : spéculaire désactivé", "specular_disabled" in cel_shader)
    check("Outline : inverted hull cull_front", "cull_front" in outline_shader and "VERTEX += NORMAL" in outline_shader)
    check("Proxy : Darius créé", 'root.name = "DariusProxy"' in proxy)
    check("Proxy : Goule créée", 'root.name = "HungryGhoulProxy"' in proxy)
    check("Proxy : caméra de combat", 'camera.name = "CombatCamera"' in proxy)
    check("Proxy : lumière froide + accent chaud", "CoolMoonKey" in proxy and "WarmLanternAccent" in proxy)

    check("Blender : trois jobs de slice", len(jobs.get("jobs", [])) == 3, str(len(jobs.get("jobs", []))))
    check("Blender : uniquement proxies avant revue", all(item.get("proxy_only_until_reviewed") is True for item in jobs.get("jobs", [])))
    check("Blender : Art Bible prioritaire", all(item.get("art_bible_authoritative") is True for item in jobs.get("jobs", [])))

    check("Godot CI : smoke vertical slice", "visual_vertical_slice_smoke.tscn" in godot_ci)
    check("PC handoff : références avant Blender", "copy_approved_art_bible_to_repo_target" in contract.get("pc_handoff", {}).get("before_opening_blender", []))

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "visual-vertical-slice-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
