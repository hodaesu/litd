#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT_DIR = ROOT / "reports/vertical_slice"
OUTPUT = REPORT_DIR / "final_report.json"

REQUIRED = {
    "darius_validation": REPORT_DIR / "darius_validation.json",
    "ghoul_validation": REPORT_DIR / "ghoul_validation.json",
    "arena_validation": REPORT_DIR / "arena_validation.json",
    "darius_mobile": REPORT_DIR / "darius_mobile.json",
    "ghoul_mobile": REPORT_DIR / "ghoul_mobile.json",
    "arena_mobile": REPORT_DIR / "arena_mobile.json",
    "captures": REPORT_DIR / "captures/manifest.json",
    "profile": REPORT_DIR / "profile.json",
}


def build_report() -> dict:
    items: dict[str, dict] = {}
    missing: list[str] = []
    blocking: list[str] = []
    warnings: list[str] = []
    for key, path in REQUIRED.items():
        if not path.exists():
            missing.append(key)
            continue
        payload = json.loads(path.read_text(encoding="utf-8"))
        items[key] = payload
        status = str(payload.get("status", "pass"))
        if status == "fail":
            blocking.append(key)
        elif status == "warn":
            warnings.append(key)
    status = "incomplete" if missing else ("fail" if blocking else ("warn" if warnings else "pass"))
    return {"version": 1, "status": status, "missing": missing, "blocking": blocking, "warnings": warnings, "items": items, "art_review": "human_approval_required_and_not_inferred"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    payload = build_report()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("VERTICAL_SLICE_FINAL_REPORT", payload["status"].upper())
    return 1 if args.strict and payload["status"] in {"fail", "incomplete"} else 0


if __name__ == "__main__":
    raise SystemExit(main())
