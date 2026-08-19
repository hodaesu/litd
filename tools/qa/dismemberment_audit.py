#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    data = json.loads((root / "data/combat_dismemberment.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/dismemberment_runtime.gd").read_text(encoding="utf-8")
    anatomy_runtime = (root / "scripts/core/anatomy_runtime.gd").read_text(encoding="utf-8")
    v4 = (root / "scripts/ui/main_v4.gd").read_text(encoding="utf-8")
    v5 = (root / "scripts/ui/main_v5.gd").read_text(encoding="utf-8")
    v6 = (root / "scripts/ui/main_v6.gd").read_text(encoding="utf-8")
    v12 = (root / "scripts/ui/main_v12.gd").read_text(encoding="utf-8")
    v13 = (root / "scripts/ui/main_v13.gd").read_text(encoding="utf-8")
    v14 = (root / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
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
    visual = data.get("visual_policy", {})
    check("Démembrement : mécanique indépendante du gore", visual.get("mechanics_independent_of_gore") is True)
    check("Démembrement : modes de présentation prévus", set(visual.get("presentation_modes", [])) == {"full", "reduced", "off"})

    check("Runtime legacy autoloadé", 'DismembermentRuntime="*res://scripts/core/dismemberment_runtime.gd"' in project)
    check("Runtime anatomique autoloadé", 'AnatomyRuntime="*res://scripts/core/anatomy_runtime.gd"' in project)
    check("Main utilise combat v14", 'res://scripts/ui/main_v14.gd' in scene)
    check("Combat v14 conserve v13", 'extends "res://scripts/ui/main_v13.gd"' in v14)
    check("Combat v13 conserve v12", 'extends "res://scripts/ui/main_v12.gd"' in v13)
    check("Combat v12 conserve v11", 'extends "res://scripts/ui/main_v11.gd"' in v12)
    check("Combat v6 conserve v5", 'extends "res://scripts/ui/main_v5.gd"' in v6)
    check("Combat v5 conserve v4 démembrement", 'extends "res://scripts/ui/main_v4.gd"' in v5)
    check("Combat v4 hérite de v3", 'extends "res://scripts/ui/main_v3.gd"' in v4)
    check("Legacy désactivé sous anatomie v2", 'anatomy_v2_enabled' in runtime and 'legacy_skipped' in runtime)
    check("Trauma ciblé indépendant par partie", 'anatomy_part_trauma' in anatomy_runtime and 'register_targeted_hit' in anatomy_runtime)
    check("Runtime réduit réellement les dégâts", 'enemy["damage"]' in runtime or 'enemy["damage"]' in anatomy_runtime)
    check("Runtime peut réduire la Peur", 'enemy["fear"]' in runtime or 'enemy["fear"]' in anatomy_runtime)
    check("Boss exposent un hook mécanique", 'boss_dismemberment_changed' in runtime or 'boss_dismemberment_changed' in anatomy_runtime)
    check("Combat v5 exploite le membre perdu pour les rangs", '_apply_limb_displacement' in v5)
    check("Combat v6 exploite le membre perdu par famille", '_apply_family_limb_reaction' in v6 and 'required_part' in v6)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


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
