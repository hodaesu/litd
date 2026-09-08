from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = ROOT / "data/veilleurs/system_maturity_registry.json"
DEFAULT_PLAYER_CONTRACT = ROOT / "data/veilleurs/player_validation_contract.json"
DEFAULT_HARDWARE_CONTRACT = ROOT / "data/veilleurs/hardware_validation_contract.json"
DEFAULT_OUT = ROOT / "reports/veilleurs_maturity_dashboard.json"

STAGE_ORDER = [
    "implemented",
    "technically_validated",
    "player_validated",
    "mobile_validated",
    "production_locked",
]
STAGE_LABELS = {
    "implemented": "Implémenté",
    "technically_validated": "Testé techniquement",
    "player_validated": "Compris par le joueur",
    "mobile_validated": "Validé mobile",
    "production_locked": "Verrouillé pour production",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _gate_ids(contract: dict[str, Any]) -> set[str]:
    gates = contract.get("gates", [])
    return {str(g.get("id")) for g in gates if isinstance(g, dict) and g.get("id")}


def build_dashboard(
    registry: dict[str, Any],
    player_contract: dict[str, Any],
    hardware_contract: dict[str, Any],
) -> dict[str, Any]:
    player_ids = _gate_ids(player_contract)
    hardware_ids = _gate_ids(hardware_contract)
    systems = []

    raw_systems = registry.get("systems", [])
    if not isinstance(raw_systems, list):
        raise ValueError("system_maturity_registry.systems must be a list")

    for raw in raw_systems:
        if not isinstance(raw, dict):
            raise ValueError("each system maturity entry must be an object")
        system_id = str(raw.get("id", "")).strip()
        stage = str(raw.get("current_stage", "")).strip()
        if not system_id or stage not in STAGE_ORDER:
            raise ValueError(f"invalid maturity entry: {system_id!r} stage={stage!r}")

        rank = STAGE_ORDER.index(stage) + 1
        next_gate = raw.get("next_gate")
        next_gate = str(next_gate).strip() if next_gate else None
        blockers = []
        blocking_reason = raw.get("blocking_reason")
        if blocking_reason:
            blockers.append(str(blocking_reason))

        evidence = {
            "player": list(raw.get("player_evidence", []) or []),
            "mobile": list(raw.get("mobile_evidence", []) or []),
            "production": list(raw.get("production_evidence", []) or []),
        }

        if rank < 3 and not evidence["player"]:
            blockers.append("Preuve humaine versionnée absente")
        if rank < 4 and not evidence["mobile"]:
            blockers.append("Preuve appareil réel absente")
        if rank < 5 and not evidence["production"]:
            blockers.append("Preuve de verrouillage production absente")

        if next_gate:
            if next_gate in player_ids:
                next_gate_kind = "player"
            elif next_gate in hardware_ids:
                next_gate_kind = "hardware"
            else:
                next_gate_kind = "unknown"
        else:
            next_gate_kind = None

        systems.append(
            {
                "id": system_id,
                "label": raw.get("label", system_id),
                "stage": stage,
                "stage_label": STAGE_LABELS[stage],
                "rank": rank,
                "next_gate": next_gate,
                "next_gate_kind": next_gate_kind,
                "blockers": blockers,
                "evidence": evidence,
                "scale_up_allowed": stage == "production_locked",
            }
        )

    scale_up_allowed = bool(systems) and all(s["scale_up_allowed"] for s in systems)
    return {
        "project": "LITD : Les Veilleurs",
        "model": "system_maturity_5_stage",
        "stages": [
            {"rank": i + 1, "id": stage, "label": STAGE_LABELS[stage]}
            for i, stage in enumerate(STAGE_ORDER)
        ],
        "systems": systems,
        "summary": {
            "system_count": len(systems),
            "production_locked_count": sum(1 for s in systems if s["scale_up_allowed"]),
            "scale_up_allowed": scale_up_allowed,
            "rule": "Le scale-up de contenu n'est autorisé qu'après verrouillage production des systèmes prioritaires.",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the Veilleurs maturity dashboard")
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--player-contract", type=Path, default=DEFAULT_PLAYER_CONTRACT)
    parser.add_argument("--hardware-contract", type=Path, default=DEFAULT_HARDWARE_CONTRACT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    dashboard = build_dashboard(
        load_json(args.registry),
        load_json(args.player_contract),
        load_json(args.hardware_contract),
    )

    if args.check:
        if dashboard["summary"]["system_count"] < 1:
            raise SystemExit("No maturity systems found")
        for system in dashboard["systems"]:
            if system["next_gate"] and system["next_gate_kind"] == "unknown":
                raise SystemExit(
                    f"Unknown next gate for {system['id']}: {system['next_gate']}"
                )
        print("VEILLEURS_MATURITY_DASHBOARD_OK")
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(dashboard, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
