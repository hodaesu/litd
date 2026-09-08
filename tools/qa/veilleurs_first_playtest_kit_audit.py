#!/usr/bin/env python3
"""Audit statique du kit de premier playtest des Veilleurs."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED = (
    "tools/playtest/prepare_veilleurs_first_playtest.py",
    "tools/playtest/run_veilleurs_first_playtest.py",
    "tools/workstation/LITD_VEILLEURS_FIRST_PLAYTEST.cmd",
    "tools/workstation/LITD_VEILLEURS_PC_PREPARE.cmd",
    "docs/veilleurs/FIRST_PLAYTEST_RUNBOOK.md",
    "reports/veilleurs_player_validation_template.json",
    "tools/qa/veilleurs_player_validation_report.py",
    ".github/workflows/veilleurs-first-playtest-windows.yml",
)


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"fichier requis absent: {relative}")

    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    prepare = (ROOT / "tools/playtest/prepare_veilleurs_first_playtest.py").read_text(encoding="utf-8")
    runner = (ROOT / "tools/playtest/run_veilleurs_first_playtest.py").read_text(encoding="utf-8")
    launcher = (ROOT / "tools/workstation/LITD_VEILLEURS_FIRST_PLAYTEST.cmd").read_text(encoding="utf-8")
    preflight_cmd = (ROOT / "tools/workstation/LITD_VEILLEURS_PC_PREPARE.cmd").read_text(encoding="utf-8")
    runbook = (ROOT / "docs/veilleurs/FIRST_PLAYTEST_RUNBOOK.md").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/veilleurs-first-playtest-windows.yml").read_text(encoding="utf-8")

    forbidden_prepare_fragments = (
        '["status"] = "PASS"',
        "['status'] = 'PASS'",
        '"status": "PASS"',
    )
    for fragment in forbidden_prepare_fragments:
        if fragment in prepare:
            errors.append(f"préparateur ne doit jamais fabriquer un PASS: {fragment}")

    if "reports/veilleurs_player_validation_template.json" not in prepare:
        errors.append("le préparateur doit partir du template canonique")
    if "PREPARED_NOT_RUN" not in prepare:
        errors.append("le préparateur doit marquer la session comme préparée mais non exécutée")
    if '"--export-debug"' not in runner or '"Windows Desktop"' not in runner:
        errors.append("le runner doit exporter le preset Windows Desktop en debug")
    if "VALIDATION_STATUS=NOT_RUN" not in runner:
        errors.append("le runner doit rappeler que la validation joueur reste NOT_RUN")
    if "run_veilleurs_first_playtest.py" not in launcher:
        errors.append("le lanceur Windows doit appeler l'orchestrateur de playtest")
    if "Godot 4.3" in preflight_cmd:
        errors.append("le lanceur de préflight Windows contient encore Godot 4.3")
    if "Godot 4.7.x" not in preflight_cmd:
        errors.append("le lanceur de préflight doit annoncer Godot 4.7.x")
    if "5 testeurs naïfs" not in runbook:
        errors.append("le runbook doit préserver l'exigence de cinq testeurs naïfs")
    if "--allow-incomplete" not in runbook:
        errors.append("le runbook doit documenter la validation d'un rapport en cours")
    if "barichello/godot-ci:4.7.2" not in workflow:
        errors.append("la build Windows CI doit utiliser Godot 4.7.2")
    if '--export-debug "Windows Desktop"' not in workflow:
        errors.append("la build Windows CI doit exporter le preset Windows Desktop")
    if "veilleurs-windows-first-playtest" not in workflow:
        errors.append("la build Windows CI doit publier un artefact clairement nommé")

    if errors:
        print("VEILLEURS_FIRST_PLAYTEST_KIT_FAILED")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("VEILLEURS_FIRST_PLAYTEST_KIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
