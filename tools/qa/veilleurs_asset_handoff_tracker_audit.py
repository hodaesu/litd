#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools/workstation/veilleurs_asset_handoff.py"


def load_module():
    spec = importlib.util.spec_from_file_location("veilleurs_asset_handoff", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load asset handoff tracker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    errors: list[str] = []
    report = module.build_report()
    items = report.get("items", [])

    if len(items) != 19:
        errors.append(f"expected 19 tracked items (7 groups + 12 ultimates), got {len(items)}")
    if any(item.get("status") != "pending" for item in items):
        errors.append("new handoff report must start entirely pending")

    ultimate = next((item for item in items if item.get("item_type") == "ultimate"), None)
    if ultimate is None:
        errors.append("no ultimate item generated")
    else:
        slots = ultimate.get("slots", {})
        if set(slots) != {"animation", "camera", "vfx", "audio", "haptic", "ui"}:
            errors.append(f"ultimate slots invalid: {sorted(slots)}")
        for row in slots.values():
            row["status"] = "done"
            row["evidence"] = ""
        module.refresh_item(ultimate)
        if ultimate.get("status") == "done":
            errors.append("tracker accepted a complete item without evidence")
        for row in slots.values():
            row["evidence"] = "audit-proof"
        module.refresh_item(ultimate)
        if ultimate.get("status") != "done":
            errors.append("tracker rejected a fully evidenced item")
        first = next(iter(slots.values()))
        first["status"] = "blocked"
        module.refresh_item(ultimate)
        if ultimate.get("status") != "blocked":
            errors.append("blocked slot did not block the package")

    if errors:
        print("VEILLEURS_ASSET_HANDOFF_TRACKER_AUDIT_FAILED")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("VEILLEURS_ASSET_HANDOFF_TRACKER_AUDIT_OK")
    print("19 items tracked; evidence required; blocked slot propagates.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
