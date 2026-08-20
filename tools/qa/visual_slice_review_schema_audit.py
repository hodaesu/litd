#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    contract = json.loads((ROOT / "data/visual_vertical_slice.json").read_text(encoding="utf-8"))
    template = json.loads((ROOT / "reports/visual_slice_review_template.json").read_text(encoding="utf-8"))
    assert set(template["scores"]) == set(contract["visual_review"]["criteria"])
    assert contract["visual_review"]["report_template"] == "reports/visual_slice_review_template.json"
    print("VISUAL_SLICE_REVIEW_SCHEMA_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
