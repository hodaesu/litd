#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/combat_dismemberment.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/dismemberment_runtime.gd").read_text(encoding="utf-8")
    v4 = (root / "scripts/ui/main_v4.gd").read_text(encoding="utf-8")
    v5 = (root / "scripts/ui/main_v5.gd").read_text(encoding="utf-8")
    scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    mechanics = data.get("mechanics", {})
    check("Démembrement : seuil normal positif", int(mechanics.get("normal_threshold", 0)) > 0)
    check("Démembrement : boss plus résistants", int(mechanics.get("boss_threshold", 0)) > int(mechanics.get("normal_threshold", 0)))
    check("Démembrement : coup lourd génère plus de trauma", int(mechanics.get("heavy_trauma", 0)) > int(mechanics.get("strike_trauma", 0)))
    check("Démembrement : boss jamais tué instantanément par perte de membre", mechanics.get("boss_instant_kill_from_limb_loss") is False)

    profiles = data.get("profiles", {})
    check("Démembrement : profils corporels présents", {"humanoid", "beast", "arachnid", "aberration", "boss"} <= set(profiles))
    for profile_id, profile in profiles.items():
        parts = profile.get("parts", [])
        check(f"{profile_id} : au moins deux parties", len(parts) >= 2, str(parts))
        ids = [part.get("id") for part in parts]
        check(f"{profile_id} : IDs de parties uniques", len(ids) == len(set(ids)), str(ids))
        for part in parts:
            check(f"{profile_id}/{part.get('id')} : dégâts bornés", 0.25 <= float(part.get("damage_multiplier", 1.0)) <= 1.0)
            check(f"{profile_id}/{part.get('id')} : peur bornée", 0.0 <= float(part.get("fear_multiplier", 1.0)) <= 1.0)

    visual = data.get("visual_policy", {})
    check("Démembrement : mécanique indépendante du gore", visual.get("mechanics_independent_of_gore") is True)
    check("Démembrement : modes de présentation prévus", set(visual.get("presentation_modes", [])) == {"full", "reduced", "off"})

    check("Runtime autoloadé", 'DismembermentRuntime="*res://scripts/core/dismemberment_runtime.gd"' in project)
    check("Main utilise combat v5", 'res://scripts/ui/main_v5.gd' in scene)
    check("Combat v5 conserve v4 démembrement", 'extends "res://scripts/ui/main_v4.gd"' in v5)
    check("Combat v4 hérite de v3", 'extends "res://scripts/ui/main_v3.gd"' in v4)
    check("Coups enregistrent le trauma", 'DismembermentRuntime.register_hit' in v4)
    check("Brise-garde contribue au démembrement", 'malvor_guard_break' in v4)
    check("UI affiche la jauge de démembrement", 'DÉMEMBREMENT' in v4 and 'status_text' in v4)
    check("Runtime réduit réellement les dégâts", 'enemy["damage"]' in runtime and 'damage_multiplier' in runtime)
    check("Runtime peut réduire la Peur", 'fear_multiplier' in runtime and 'enemy["fear"]' in runtime)
    check("Perte de soutien peut étourdir", 'enemy["stunned"] = true' in runtime)
    check("Boss exposent un hook mécanique", 'boss_dismemberment_changed' in runtime)
    check("Combat v5 exploite le membre perdu pour les rangs", '_apply_limb_displacement' in v5)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "dismemberment-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
