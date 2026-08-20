#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from tools.qa.visual_asset_validator import validate_report

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    contract = json.loads((ROOT / "data/visual_vertical_slice.json").read_text(encoding="utf-8"))
    examples = json.loads((ROOT / "data/qa/visual_asset_report_examples.json").read_text(encoding="utf-8"))["examples"]
    assert validate_report(examples["darius"], contract) == []
    assert validate_report(examples["arena"], contract) == []
    print("VISUAL_SLICE_EXAMPLES_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
