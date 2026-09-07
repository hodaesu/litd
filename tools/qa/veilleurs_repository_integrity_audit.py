#!/usr/bin/env python3
"""Audit transversal du périmètre actif de LITD : Les Veilleurs.

Ce contrôle complète les audits fonctionnels existants en recherchant les dérives
entre dossiers : JSON cassé, canon divergent, anciens Veilleurs, version Godot,
références res:// invalides, contrats non reliés et fichiers actifs vides.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "build/automation/veilleurs_repository_integrity.json"
PRE_PC = ROOT / "data/veilleurs/pre_pc_gate.json"
PIPELINE = ROOT / "tools/godot/veilleurs_pipeline_config.json"
SELF = Path(__file__).resolve()

CANON_ENTITY_IDS = [
    "ENT_WATCHER_NAYRA",
    "ENT_WATCHER_TAREK",
    "ENT_WATCHER_AISHA",
    "ENT_WATCHER_IDRIS",
]
CANON_RUNTIME_IDS = ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"]
CANON_NAMES = ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael"]
CI_GODOT = "4.7.2"
PROJECT_GODOT = "4.7"
WORKFLOWS = [
    "build.yml",
    "ci.yml",
    "nightly.yml",
    "remanence-smoke.yml",
    "veilleurs-production-automation.yml",
    "veilleurs-v06.yml",
    "veilleurs-v07-production.yml",
    "veilleurs-v08-wave2.yml",
    "veilleurs-v09-wave3.yml",
]
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".json", ".md", ".py", ".ps1", ".sh", ".cmd"}
RES_SUFFIXES = {".gd", ".tscn", ".tres", ".json", ".cfg", ".png", ".svg", ".webp", ".jpg", ".jpeg", ".wav", ".ogg", ".mp3", ".glb", ".res", ".theme", ".ttf", ".otf"}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def iter_active_text_files() -> list[Path]:
    files: set[Path] = set()
    whole_roots = [
        ROOT / "data/veilleurs",
        ROOT / "scenes/veilleurs",
        ROOT / "docs/veilleurs",
        ROOT / "addons/veilleurs_pipeline",
    ]
    for base in whole_roots:
        if base.exists():
            files.update(p for p in base.rglob("*") if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES)

    tests_dir = ROOT / "scenes/tests"
    if tests_dir.exists():
        for path in tests_dir.rglob("*"):
            low = path.name.lower()
            if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES and (
                "veilleurs" in low or "mobile_touch" in low or "ui_player_journey" in low
            ):
                files.add(path)

    for base in [ROOT / "scripts/core", ROOT / "scripts/ui", ROOT / "scripts/world", ROOT / "scripts/qa"]:
        if base.exists():
            files.update(p for p in base.rglob("*.gd") if p.is_file())

    for base in [ROOT / "tools/godot", ROOT / "tools/workstation", ROOT / "tools/qa"]:
        if base.exists():
            files.update(
                p for p in base.rglob("*")
                if p.is_file() and p.suffix.lower() in TEXT_SUFFIXES and "veilleurs" in p.name.lower()
            )

    files.discard(SELF)
    return sorted(files)


def iter_reference_files() -> list[Path]:
    files: set[Path] = set()
    for base in [ROOT / "scenes/veilleurs", ROOT / "addons/veilleurs_pipeline"]:
        if base.exists():
            files.update(p for p in base.rglob("*") if p.is_file() and p.suffix.lower() in {".gd", ".tscn", ".tres", ".cfg"})
    tests_dir = ROOT / "scenes/tests"
    if tests_dir.exists():
        for p in tests_dir.rglob("*"):
            if p.is_file() and p.suffix.lower() in {".gd", ".tscn", ".tres"} and (
                "veilleurs" in p.name.lower() or "mobile_touch" in p.name.lower() or "ui_player_journey" in p.name.lower()
            ):
                files.add(p)
    for base in [ROOT / "scripts/core", ROOT / "scripts/ui", ROOT / "scripts/world", ROOT / "scripts/qa"]:
        if base.exists():
            files.update(p for p in base.rglob("*veilleurs*.gd") if p.is_file())
    return sorted(files)


def add_error(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    checks: dict[str, bool] = {}

    # 1. Tous les JSON Veilleurs doivent être lisibles.
    json_errors: list[str] = []
    json_files = sorted((ROOT / "data/veilleurs").rglob("*.json"))
    for path in json_files:
        try:
            load_json(path)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            json_errors.append(f"{rel(path)}: {exc}")
    checks["all_veilleurs_json_parse"] = not json_errors
    errors.extend(f"JSON invalide: {row}" for row in json_errors)

    # 2. Aucun fichier texte actif ne doit être vide.
    active_files = iter_active_text_files()
    empty = [rel(p) for p in active_files if p.stat().st_size == 0]
    checks["no_empty_active_files"] = not empty
    if empty:
        errors.append("Fichiers actifs vides: " + ", ".join(empty))

    # 3. Canon exact des quatre Veilleurs.
    watchers = load_json(ROOT / "data/veilleurs/v06/watchers.json")
    rows = watchers.get("watchers", [])
    entity_ids = [row.get("entity_id") for row in rows]
    runtime_ids = [row.get("runtime_id") for row in rows]
    names = [row.get("name_fr") for row in rows]
    checks["canonical_watchers"] = (
        watchers.get("count") == 4
        and entity_ids == CANON_ENTITY_IDS
        and runtime_ids == CANON_RUNTIME_IDS
        and names == CANON_NAMES
    )
    add_error(errors, checks["canonical_watchers"], f"Quatuor canonique divergent: {entity_ids} / {runtime_ids} / {names}")

    positions = [tuple(row.get("starter_position", [])) for row in rows]
    checks["starter_positions"] = len(set(positions)) == 4 and all(
        len(pos) == 2 and 0 <= pos[0] < 6 and 0 <= pos[1] < 5 for pos in positions
    )
    add_error(errors, checks["starter_positions"], f"Positions initiales incohérentes: {positions}")

    loadouts = load_json(ROOT / "data/veilleurs/v06/starter_loadouts_watchers.json")
    checks["starter_loadout_roster"] = list(loadouts.keys()) == CANON_ENTITY_IDS
    add_error(errors, checks["starter_loadout_roster"], f"Loadouts initiaux divergents: {list(loadouts.keys())}")

    # 4. 12 arbres / 180 compétences et cohérence entre proxy, fichiers et contrat source.
    tree_catalog = load_json(ROOT / "data/veilleurs/v06/watcher_tree_catalog.json")
    source_contract = load_json(ROOT / "data/veilleurs/skills/source_contract.json")
    catalog_rows = tree_catalog.get("watchers", [])
    checks["tree_catalog_counts"] = tree_catalog.get("tree_count") == 12 and tree_catalog.get("skill_count") == 180
    add_error(errors, checks["tree_catalog_counts"], "Le catalogue n'annonce pas exactement 12 arbres / 180 compétences")
    checks["tree_catalog_roster"] = [row.get("entity_id") for row in catalog_rows] == CANON_ENTITY_IDS
    add_error(errors, checks["tree_catalog_roster"], "Le catalogue d'arbres ne suit pas le quatuor canonique")
    checks["source_contract_roster"] = list(source_contract.get("watchers", {}).keys()) == CANON_RUNTIME_IDS
    add_error(errors, checks["source_contract_roster"], "Le contrat source des compétences ne suit pas les runtime IDs canoniques")

    skill_ids_global: list[str] = []
    skill_layout_ok = True
    for row, runtime_id, expected_name in zip(catalog_rows, CANON_RUNTIME_IDS, CANON_NAMES):
        source = str(row.get("source", ""))
        path = ROOT / source.removeprefix("res://")
        if not path.is_file():
            errors.append(f"Source de compétences absente: {source}")
            skill_layout_ok = False
            continue
        data = load_json(path)
        if data.get("watcher_id") != runtime_id or data.get("watcher_name") != expected_name:
            errors.append(f"Identité de fichier compétence divergente: {rel(path)}")
            skill_layout_ok = False
        trees = data.get("trees", {})
        if len(trees) != 3 or any(len(tree.get("skills", [])) != 15 for tree in trees.values()):
            errors.append(f"Arbres/compétences incomplets: {rel(path)}")
            skill_layout_ok = False
        local_ids = [skill[0] for tree in trees.values() for skill in tree.get("skills", []) if skill]
        if len(local_ids) != 45 or len(set(local_ids)) != 45:
            errors.append(f"IDs compétence dupliqués ou incomplets: {rel(path)}")
            skill_layout_ok = False
        contracted = set(source_contract.get("watchers", {}).get(runtime_id, {}).get("skills", {}).keys())
        if set(local_ids) != contracted:
            errors.append(f"Contrat source différent des compétences runtime: {runtime_id}")
            skill_layout_ok = False
        skill_ids_global.extend(local_ids)
    checks["skills_180_integrity"] = skill_layout_ok and len(skill_ids_global) == 180 and len(set(skill_ids_global)) == 180
    add_error(errors, checks["skills_180_integrity"], "Les 180 compétences canoniques ne sont pas globalement uniques et complètes")

    # 5. Bestiaire ordinaire et six donjons de production.
    enemies = load_json(ROOT / "data/veilleurs/v06/enemies_24_definitions.json")
    enemy_ids = [row.get("entity_id") for row in enemies.get("enemies", [])]
    checks["enemy_roster_24"] = enemies.get("count") == 24 and len(enemy_ids) == 24 and len(set(enemy_ids)) == 24
    add_error(errors, checks["enemy_roster_24"], "Le roster de 24 ennemis ordinaires est incomplet ou dupliqué")

    pre_pc = load_json(PRE_PC)
    wave3 = load_json(ROOT / "data/veilleurs/v09/wave3_contract.json")
    dungeons = wave3.get("vertical_slice", {}).get("dungeon_ids", [])
    checks["six_dungeons"] = len(dungeons) == 6 and dungeons == pre_pc.get("production_dungeons") and len(set(dungeons)) == 6
    add_error(errors, checks["six_dungeons"], f"Contrat des six donjons divergent: {dungeons}")

    # 6. Version moteur et CI : une seule vérité active.
    pipeline = load_json(PIPELINE)
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    checks["godot_contract_alignment"] = (
        pre_pc.get("godot_version") == PROJECT_GODOT
        and pipeline.get("godot_version") == PROJECT_GODOT
        and f'config/features=PackedStringArray("{PROJECT_GODOT}")' in project
    )
    add_error(errors, checks["godot_contract_alignment"], "Dérive de version entre project.godot, pré-PC et pipeline")

    workflow_errors: list[str] = []
    for name in WORKFLOWS:
        path = ROOT / ".github/workflows" / name
        if not path.is_file():
            workflow_errors.append(f"workflow absent: {name}")
            continue
        text = path.read_text(encoding="utf-8")
        if "barichello/godot-ci:" in text and f"barichello/godot-ci:{CI_GODOT}" not in text:
            workflow_errors.append(f"image Godot CI divergente: {name}")
        if "barichello/godot-ci:4.3" in text or "4.3.stable" in text:
            workflow_errors.append(f"ancien verrou 4.3 actif: {name}")
    production_workflow = (ROOT / ".github/workflows/veilleurs-production-automation.yml").read_text(encoding="utf-8")
    if f"export_templates/{CI_GODOT}.stable" not in production_workflow:
        workflow_errors.append("template Android CI non aligné sur Godot 4.7.2")
    checks["ci_godot_alignment"] = not workflow_errors
    errors.extend(workflow_errors)

    # 7. Les fichiers requis du verrou pré-PC doivent tous exister.
    missing_required = [item for item in pre_pc.get("required_files", []) if not (ROOT / item).is_file()]
    checks["pre_pc_required_files"] = not missing_required
    if missing_required:
        errors.append("Fichiers pré-PC requis absents: " + ", ".join(missing_required))

    # 8. Aucun ancien quatuor hors exceptions historiques explicites.
    allowed_stale = set(pre_pc.get("allowed_stale_reference_files", []))
    allowed_stale.add("data/veilleurs/pre_pc_gate.json")
    stale_tokens = set(pre_pc.get("forbidden_stale_runtime_ids", [])) | {
        "Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal",
        "sahen_varo", "mira_sen", "narem_osh", "ysra_nahal",
    }
    stale_hits: dict[str, list[str]] = {}
    for path in active_files:
        relative = rel(path)
        if relative in allowed_stale:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for token in stale_tokens:
            if token in text:
                stale_hits.setdefault(token, []).append(relative)
    checks["no_stale_quartet_drift"] = not stale_hits
    if stale_hits:
        errors.extend(f"Ancien canon {token}: {', '.join(sorted(paths))}" for token, paths in sorted(stale_hits.items()))

    # 9. Les références res:// statiques des scènes/scripts Veilleurs doivent résoudre.
    unresolved: dict[str, list[str]] = {}
    ref_pattern = re.compile(r"res://[^\"'\s)\],]+")
    for path in iter_reference_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for raw in ref_pattern.findall(text):
            target = raw.rstrip(".;:")
            if any(marker in target for marker in ("%", "{", "}", "*")):
                continue
            target_path = ROOT / target.removeprefix("res://")
            if target_path.suffix.lower() not in RES_SUFFIXES:
                continue
            if not target_path.exists():
                unresolved.setdefault(rel(path), []).append(target)
    checks["static_res_references"] = not unresolved
    if unresolved:
        errors.extend(f"Référence res:// absente dans {path}: {', '.join(sorted(set(refs)))}" for path, refs in sorted(unresolved.items()))

    # 10. Signaux faibles : ils n'échouent pas la CI mais restent visibles dans le rapport.
    todo_hits: list[str] = []
    vs001_hits: list[str] = []
    for path in active_files:
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        low = text.lower()
        if any(marker in low for marker in ("todo", "fixme", "notimplemented")):
            todo_hits.append(rel(path))
        if "vs001" in low and (rel(path).startswith("scripts/") or rel(path).startswith("scenes/veilleurs/")):
            vs001_hits.append(rel(path))
    if todo_hits:
        warnings.append("Marqueurs TODO/FIXME à revoir: " + ", ".join(sorted(set(todo_hits))))
    if vs001_hits:
        warnings.append("Références VS001 encore présentes dans le runtime/scènes: " + ", ".join(sorted(set(vs001_hits))))

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "ok": not errors,
        "checks": checks,
        "errors": errors,
        "warnings": warnings,
        "metrics": {
            "json_files_scanned": len(json_files),
            "active_text_files_scanned": len(active_files),
            "reference_files_scanned": len(iter_reference_files()),
            "canonical_watchers": len(rows),
            "canonical_skills": len(skill_ids_global),
            "ordinary_enemies": len(enemy_ids),
            "production_dungeons": len(dungeons),
        },
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("VEILLEURS_REPOSITORY_INTEGRITY_FAILED")
        for message in errors:
            print("ERROR:", message)
        for message in warnings:
            print("WARNING:", message)
        return 1

    print("VEILLEURS_REPOSITORY_INTEGRITY_OK")
    print(json.dumps(report["metrics"], ensure_ascii=False, sort_keys=True))
    for message in warnings:
        print("WARNING:", message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
