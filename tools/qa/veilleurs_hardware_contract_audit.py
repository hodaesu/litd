#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/veilleurs/hardware_validation_contract.json"

EXPECTED = [
    "real_mobile_touch",
    "safe_areas_real_devices",
    "haptics_real_devices",
    "gpu_cpu_thermal_performance",
    "final_visual_readability",
    "physical_controller",
    "real_audio_output",
    "ios_signed_device_build",
]

REQUIRED_GATE_FIELDS = {
    "id",
    "title_fr",
    "platforms",
    "scenarios",
    "required_evidence",
    "acceptance",
}


def main() -> int:
    data = json.loads(CONTRACT.read_text(encoding="utf-8"))
    errors: list[str] = []

    if data.get("godot_version") != "4.7.x":
        errors.append("hardware contract must target Godot 4.7.x")

    gate_ids = data.get("required_gate_ids", [])
    if gate_ids != EXPECTED:
        errors.append(f"required_gate_ids mismatch: {gate_ids}")

    gates = data.get("gates", [])
    if len(gates) != len(EXPECTED):
        errors.append(f"expected 8 gates, got {len(gates)}")

    seen: set[str] = set()
    for gate in gates:
        if not isinstance(gate, dict):
            errors.append("gate is not an object")
            continue
        missing = sorted(REQUIRED_GATE_FIELDS - gate.keys())
        gate_id = str(gate.get("id", "<missing>"))
        if missing:
            errors.append(f"{gate_id}: missing fields {missing}")
        if gate_id in seen:
            errors.append(f"duplicate gate id: {gate_id}")
        seen.add(gate_id)
        for field in ("platforms", "scenarios", "required_evidence", "acceptance"):
            value = gate.get(field)
            if not isinstance(value, list) or not value:
                errors.append(f"{gate_id}: {field} must be a non-empty list")
        if "blocking_issue_count" not in gate.get("required_evidence", []):
            errors.append(f"{gate_id}: blocking_issue_count evidence is required")

    if sorted(seen) != sorted(EXPECTED):
        errors.append(f"gate set mismatch: {sorted(seen)}")

    performance = next((g for g in gates if g.get("id") == "gpu_cpu_thermal_performance"), {})
    targets = performance.get("targets", {})
    if targets.get("preferred_fps") != 60 or targets.get("hard_floor_fps") != 30:
        errors.append("performance gate must preserve 60 FPS preferred / 30 FPS hard floor")
    if targets.get("crash_count_max") != 0 or targets.get("blocking_issue_count_max") != 0:
        errors.append("performance gate must allow no crashes or blocking issues")

    ios = next((g for g in gates if g.get("id") == "ios_signed_device_build"), {})
    if ios.get("platforms") != ["ios"]:
        errors.append("signed iOS build gate must be iOS-only")

    if errors:
        print("VEILLEURS_HARDWARE_CONTRACT_FAILED")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("VEILLEURS_HARDWARE_CONTRACT_OK")
    print("Godot family: 4.7.x | Gates: 8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
