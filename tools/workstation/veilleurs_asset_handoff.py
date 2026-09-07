#!/usr/bin/env python3
"""Suivi local du handoff d'assets final de LITD : Les Veilleurs.

Ce script ne produit pas les assets. Il matérialise les jobs spécifiés dans le
dépôt et empêche qu'un package soit déclaré complet sans tous ses slots et une
preuve locale pour chacun.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data/veilleurs/final_asset_handoff_contract.json"
DEFAULT_REPORT = ROOT / "local/reports/veilleurs_asset_handoff/session.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_report() -> dict:
    contract = load_json(CONTRACT_PATH)
    items: list[dict] = []

    for group in contract.get("production_groups", []):
        items.append({
            "item_type": "group",
            "item_id": str(group.get("group_id", "")),
            "output_root": str(group.get("output_root", "")),
            "status": "pending",
            "slots": {
                str(slot): {"status": "pending", "evidence": "", "note": ""}
                for slot in group.get("required_slots", [])
            },
        })

    ultimate_slots = contract.get("ultimate_slot_contract", {}).get("required_slots", [])
    for package in contract.get("ultimate_packages", []):
        items.append({
            "item_type": "ultimate",
            "item_id": str(package.get("ultimate_id", "")),
            "ultimate_id": str(package.get("ultimate_id", "")),
            "output_root": str(package.get("output_root", "")),
            "status": "pending",
            "slots": {
                str(slot): {"status": "pending", "evidence": "", "note": ""}
                for slot in ultimate_slots
            },
        })

    return {
        "schema_version": 1,
        "contract_stage": contract.get("stage"),
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "items": items,
    }


def report_path(value: str | None) -> Path:
    return Path(value).expanduser().resolve() if value else DEFAULT_REPORT


def command_init(args: argparse.Namespace) -> int:
    path = report_path(args.report)
    if path.exists() and not args.force:
        print(f"Report already exists: {path}")
        return 2
    write_json(path, build_report())
    print(path)
    return 0


def find_item(report: dict, item_id: str) -> dict | None:
    for item in report.get("items", []):
        if str(item.get("item_id", "")) == item_id:
            return item
    return None


def refresh_item(item: dict) -> None:
    slots = item.get("slots", {})
    complete = bool(slots) and all(
        row.get("status") == "done" and bool(str(row.get("evidence", "")).strip())
        for row in slots.values()
    )
    blocked = any(row.get("status") == "blocked" for row in slots.values())
    item["status"] = "blocked" if blocked else ("done" if complete else "pending")


def command_record(args: argparse.Namespace) -> int:
    path = report_path(args.report)
    if not path.is_file():
        print(f"Missing report: {path}")
        return 2
    report = load_json(path)
    item = find_item(report, args.item)
    if item is None:
        print(f"Unknown item: {args.item}")
        return 2
    slot = item.get("slots", {}).get(args.slot)
    if slot is None:
        print(f"Unknown slot {args.slot} for {args.item}")
        return 2
    if args.status == "done" and not args.evidence.strip():
        print("A done slot requires --evidence.")
        return 2

    slot["status"] = args.status
    slot["evidence"] = args.evidence.strip()
    slot["note"] = args.note.strip()
    slot["updated_at"] = now_iso()
    refresh_item(item)
    report["updated_at"] = now_iso()
    write_json(path, report)
    print(f"{args.item}:{args.slot} -> {args.status}; item={item['status']}")
    return 0


def summary(report: dict) -> dict:
    items = report.get("items", [])
    return {
        "total": len(items),
        "done": sum(1 for row in items if row.get("status") == "done"),
        "blocked": sum(1 for row in items if row.get("status") == "blocked"),
        "pending": sum(1 for row in items if row.get("status") == "pending"),
    }


def command_status(args: argparse.Namespace) -> int:
    path = report_path(args.report)
    if not path.is_file():
        print(f"Missing report: {path}")
        return 2
    state = summary(load_json(path))
    print(json.dumps(state, ensure_ascii=False))
    if args.require_complete and (state["pending"] or state["blocked"]):
        return 1
    return 0


def command_jobs(_args: argparse.Namespace) -> int:
    contract = load_json(CONTRACT_PATH)
    rows = []
    for group in contract.get("production_groups", []):
        rows.append({
            "item_type": "group",
            "item_id": group["group_id"],
            "output_root": group["output_root"],
            "slots": list(group["required_slots"]),
        })
    slots = list(contract.get("ultimate_slot_contract", {}).get("required_slots", []))
    for package in contract.get("ultimate_packages", []):
        rows.append({
            "item_type": "ultimate",
            "item_id": package["ultimate_id"],
            "output_root": package["output_root"],
            "slots": slots,
        })
    print(json.dumps(rows, ensure_ascii=False, indent=2))
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Veilleurs final asset handoff tracker")
    sub = root.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init")
    init.add_argument("--report")
    init.add_argument("--force", action="store_true")
    init.set_defaults(func=command_init)

    record = sub.add_parser("record")
    record.add_argument("--report")
    record.add_argument("--item", required=True)
    record.add_argument("--slot", required=True)
    record.add_argument("--status", choices=["pending", "done", "blocked"], required=True)
    record.add_argument("--evidence", default="")
    record.add_argument("--note", default="")
    record.set_defaults(func=command_record)

    status = sub.add_parser("status")
    status.add_argument("--report")
    status.add_argument("--require-complete", action="store_true")
    status.set_defaults(func=command_status)

    jobs = sub.add_parser("jobs")
    jobs.set_defaults(func=command_jobs)
    return root


def main() -> int:
    args = parser().parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
