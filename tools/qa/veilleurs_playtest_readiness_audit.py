#!/usr/bin/env python3
"""Audit statique de préparation au playtest Wave 2 des Veilleurs."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
READINESS = ROOT / "data/veilleurs/playtest_readiness_contract.json"
HARDWARE = ROOT / "data/veilleurs/hardware_validation_contract.json"
PLAYER = ROOT / "data/veilleurs/player_validation_contract.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate() -> list[str]:
    errors: list[str] = []
    for path in (READINESS, HARDWARE, PLAYER):
        if not path.is_file():
            errors.append(f"fichier manquant: {path.relative_to(ROOT)}")
    if errors:
        return errors

    readiness = _load(READINESS)
    hardware = _load(HARDWARE)
    player = _load(PLAYER)

    rules = readiness.get("rules", {})
    if rules.get("cannot_promote_player_maturity") is not True:
        errors.append("la préparation doit interdire la promotion automatique joueur")
    if rules.get("cannot_promote_mobile_maturity") is not True:
        errors.append("la préparation doit interdire la promotion automatique mobile")
    if rules.get("human_results_start_not_run") is not True:
        errors.append("les résultats humains doivent démarrer à NOT_RUN")
    if rules.get("minimum_naive_testers") != 5:
        errors.append("le pack canonique doit exiger exactement le minimum de 5 testeurs naïfs")

    measurement = readiness.get("measurement", {})
    required_fields = set(measurement.get("required_observation_fields", []))
    mandatory_fields = {
        "tester_id",
        "build_commit",
        "platform",
        "scenario_id",
        "first_action",
        "hesitation_count",
        "help_request_count",
        "coach_intervention_count",
        "misinput_count",
        "blocking_issue_count",
        "player_explanation",
        "observer_notes",
    }
    if not mandatory_fields.issubset(required_fields):
        errors.append("champs de mesure obligatoires incomplets")

    player_gate_ids = set(player.get("required_gate_ids", []))
    scenario_ids = set(measurement.get("required_scenarios", []))
    if not scenario_ids.issubset(player_gate_ids):
        errors.append("les scénarios de mesure doivent référencer des gates joueur existants")

    hypotheses = readiness.get("probable_fix_hypotheses", [])
    if len(hypotheses) < 5:
        errors.append("au moins cinq hypothèses de correction doivent être préparées")
    if any(item.get("apply_before_evidence") is not False for item in hypotheses):
        errors.append("aucune correction probable ne doit être appliquée sans preuve")

    accessibility = readiness.get("accessibility_static_readiness", {})
    access_requirements = set(accessibility.get("requirements", []))
    for required in (
        "critical_information_not_color_only",
        "focus_state_required_for_interactive_controls",
        "haptics_must_have_visual_or_audio_equivalent",
    ):
        if required not in access_requirements:
            errors.append(f"accessibilité manquante: {required}")
    if accessibility.get("final_validation_requires_human_or_device") is not True:
        errors.append("l'accessibilité finale doit rester humaine/matérielle")

    localization = readiness.get("localization_static_readiness", {})
    if localization.get("source_locale") != "fr":
        errors.append("la locale source doit rester fr")
    if localization.get("text_expansion_target_percent") != 35:
        errors.append("la cible de pseudo-localisation doit réserver 35 % d'expansion")
    if localization.get("final_language_validation_requires_human") is not True:
        errors.append("la validation linguistique finale doit rester humaine")

    performance = readiness.get("performance_theoretical_readiness", {})
    if performance.get("linked_hardware_gate") != "gpu_cpu_thermal_performance":
        errors.append("la performance théorique doit rester liée au gate matériel réel")
    if performance.get("preferred_fps") != 60 or performance.get("hard_floor_fps") != 30:
        errors.append("les budgets FPS doivent rester 60 préférés / 30 plancher")
    if performance.get("theoretical_audit_cannot_claim_runtime_pass") is not True:
        errors.append("l'audit théorique ne doit jamais déclarer un PASS runtime")

    hw_gate = next((g for g in hardware.get("gates", []) if g.get("id") == "gpu_cpu_thermal_performance"), None)
    if not hw_gate:
        errors.append("gate matériel performance introuvable")
    else:
        targets = hw_gate.get("targets", {})
        if targets.get("preferred_fps") != performance.get("preferred_fps"):
            errors.append("preferred_fps incohérent avec hardware_validation_contract")
        if targets.get("hard_floor_fps") != performance.get("hard_floor_fps"):
            errors.append("hard_floor_fps incohérent avec hardware_validation_contract")
        if set(hw_gate.get("scenarios", [])) != set(performance.get("required_runtime_scenarios", [])):
            errors.append("scénarios de performance incohérents avec le contrat matériel")

    required_files = [
        "tools/playtest/prepare_naive_tester_pack.py",
        "tools/playtest/summarize_naive_playtests.py",
        "docs/veilleurs/PLAYTEST_READINESS_WAVE2.md",
        ".github/workflows/veilleurs-playtest-readiness.yml",
        "tests/test_veilleurs_playtest_readiness.py",
    ]
    for rel in required_files:
        if not (ROOT / rel).is_file():
            errors.append(f"fichier readiness manquant: {rel}")

    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"FAIL - {error}")
        return 1
    print("VEILLEURS_PLAYTEST_READINESS_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
