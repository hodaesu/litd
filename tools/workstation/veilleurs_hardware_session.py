#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/hardware_validation_contract.json"
REPORT_DIR = ROOT / "local/reports/veilleurs_hardware"


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def session_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    return path


def parse_evidence(values: list[str]) -> dict[str, object]:
    result: dict[str, object] = {}
    for item in values:
        if "=" not in item:
            raise ValueError(f"evidence must use key=value: {item}")
        key, raw = item.split("=", 1)
        key = key.strip()
        raw = raw.strip()
        if not key:
            raise ValueError("evidence key cannot be empty")
        lowered = raw.lower()
        if lowered in {"true", "false"}:
            value: object = lowered == "true"
        else:
            try:
                value = int(raw)
            except ValueError:
                try:
                    value = float(raw)
                except ValueError:
                    value = raw
        result[key] = value
    return result


def command_init(args: argparse.Namespace) -> int:
    contract = load_json(CONTRACT_PATH)
    platform = args.platform
    gates = []
    for gate in contract["gates"]:
        applicable = platform in gate.get("platforms", [])
        gates.append(
            {
                "id": gate["id"],
                "title_fr": gate["title_fr"],
                "applicable": applicable,
                "status": "not_tested" if applicable else "not_applicable",
                "tested_at": None,
                "evidence": {},
                "notes": [],
            }
        )

    report = {
        "schema_version": 1,
        "project": contract.get("project"),
        "contract_schema_version": contract.get("schema_version"),
        "created_at": now(),
        "updated_at": now(),
        "session": args.session,
        "platform": platform,
        "device": args.device,
        "os_version": args.os_version,
        "build": args.build,
        "gates": gates,
    }
    target = REPORT_DIR / f"{args.session}.json"
    if target.exists() and not args.force:
        print(f"Session already exists: {target}")
        return 2
    save_json(target, report)
    print(target.relative_to(ROOT).as_posix())
    return 0


def command_record(args: argparse.Namespace) -> int:
    path = session_path(args.session_file)
    report = load_json(path)
    contract = load_json(CONTRACT_PATH)
    gate_contract = next((g for g in contract["gates"] if g["id"] == args.gate), None)
    if gate_contract is None:
        print(f"Unknown gate: {args.gate}")
        return 2

    row = next((g for g in report.get("gates", []) if g.get("id") == args.gate), None)
    if row is None:
        print(f"Gate absent from session: {args.gate}")
        return 2
    if not row.get("applicable", False):
        print(f"Gate is not applicable to platform {report.get('platform')}: {args.gate}")
        return 2

    try:
        evidence = parse_evidence(args.evidence)
    except ValueError as exc:
        print(str(exc))
        return 2

    row["evidence"].update(evidence)
    if args.note:
        row["notes"].append(args.note)
    row["status"] = args.status
    row["tested_at"] = now()
    missing = [key for key in gate_contract["required_evidence"] if key not in row["evidence"]]
    row["missing_required_evidence"] = missing
    if args.status == "pass" and missing:
        row["status"] = "incomplete"
        print("PASS refused: missing evidence: " + ", ".join(missing))
    report["updated_at"] = now()
    save_json(path, report)
    print(f"{args.gate}: {row['status']}")
    return 0 if row["status"] in {"pass", "fail"} else 2


def command_status(args: argparse.Namespace) -> int:
    path = session_path(args.session_file)
    report = load_json(path)
    applicable = [g for g in report.get("gates", []) if g.get("applicable", False)]
    for gate in applicable:
        print(f"{gate['id']}: {gate['status']}")
    complete = bool(applicable) and all(g.get("status") == "pass" for g in applicable)
    print("VEILLEURS_HARDWARE_SESSION_OK" if complete else "VEILLEURS_HARDWARE_SESSION_INCOMPLETE")
    return 0 if complete else 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="LITD : Les Veilleurs hardware validation session recorder")
    sub = parser.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init", help="Create a device/platform validation session")
    init.add_argument("--session", required=True, help="Stable short session name")
    init.add_argument("--platform", required=True, choices=["ios", "android", "windows"])
    init.add_argument("--device", required=True)
    init.add_argument("--os-version", required=True)
    init.add_argument("--build", default="development")
    init.add_argument("--force", action="store_true")
    init.set_defaults(func=command_init)

    record = sub.add_parser("record", help="Record one gate result")
    record.add_argument("--session-file", required=True)
    record.add_argument("--gate", required=True)
    record.add_argument("--status", required=True, choices=["pass", "fail"])
    record.add_argument("--note")
    record.add_argument("--evidence", action="append", default=[], help="key=value; repeat for every evidence item")
    record.set_defaults(func=command_record)

    status = sub.add_parser("status", help="Check whether all applicable gates passed")
    status.add_argument("--session-file", required=True)
    status.set_defaults(func=command_status)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
