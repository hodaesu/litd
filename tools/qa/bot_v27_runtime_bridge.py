#!/usr/bin/env python3
"""Bot v27: bridge model-level v21/v25 transitions to production-runtime evidence.

This bot does not pretend model transitions are production actions. It requires concrete Godot
reports that exercise the same domains, then reports any abstract transition lacking runtime proof.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPORTS = Path("reports")
OUT = REPORTS / "player-bot-v27-runtime-bridge.json"

EVIDENCE: dict[str, list[str]] = {
    "combat": ["player-bot-v6-real-campaign.json", "player-bot-v8-fast-combat-contract.json"],
    "loot": ["player-bot-v6-real-campaign.json"],
    "extraction": ["player-bot-v6-real-campaign.json"],
    "market": ["player-bot-v7-sanctuary-economy.json", "player-bot-v19-economy-stress.json"],
    "recruit": ["player-bot-v7-sanctuary-economy.json", "player-bot-v19-economy-stress.json"],
    "save_load": ["player-bot-v9-save-integrity.json", "player-bot-v5-longitudinal-campaign.json"],
    "ui": ["player-bot-v10-sanctuary-ui-smoke.json"],
}

MODEL_SOURCES = [
    "player-bot-v21-longhaul-campaign.json",
    "player-bot-v25-stateful-chaos.json",
]


def load(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def report_ok(data: dict[str, Any] | None) -> bool:
    if not data:
        return False
    return str(data.get("status", "")).lower() in {"passed", "success", "ok"}


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    model_presence = {name: load(REPORTS / name) is not None for name in MODEL_SOURCES}
    domains: dict[str, Any] = {}
    missing_runtime: list[str] = []

    for domain, files in EVIDENCE.items():
        evidence = []
        for name in files:
            data = load(REPORTS / name)
            evidence.append({
                "report": name,
                "present": data is not None,
                "status": data.get("status") if data else None,
                "passing": report_ok(data),
            })
        proven = any(row["present"] for row in evidence)
        passing = any(row["passing"] for row in evidence)
        domains[domain] = {"runtime_proven": proven, "runtime_passing": passing, "evidence": evidence}
        if not proven:
            missing_runtime.append(domain)

    # Missing evidence is a coverage failure. Red production evidence remains visible but is not
    # duplicated as a second failure here; the source suite owns its own red status.
    status = "failed" if missing_runtime else "passed"
    report = {
        "bot": "v27",
        "status": status,
        "method": "cross-validation of model transitions against real Godot runtime reports",
        "model_sources": model_presence,
        "domains": domains,
        "missing_runtime_evidence": missing_runtime,
        "contract": "v21/v25 remain models; every modeled gameplay domain must have at least one production-runtime bot as evidence.",
    }
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PLAYER_BOT_V27_{status.upper()} domains={len(domains)} missing={len(missing_runtime)}")
    return 1 if status == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
