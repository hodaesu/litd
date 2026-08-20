#!/usr/bin/env python3
"""Static audit for vertical-slice runtime preparation."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    contract = json.loads((ROOT / "data/visual_vertical_slice.json").read_text(encoding="utf-8"))
    assert contract["version"] == 2
    for key in ("asset_ingest", "runtime", "mobile_budget", "visual_review", "future_cast"):
        assert key in contract, key
    required_files = [
        "scripts/visual/validated_glb_loader.gd",
        "scripts/visual/visual_slice_animation_controller.gd",
        "scripts/visual/visual_slice_vfx.gd",
        "scripts/visual/visual_slice_runtime.gd",
        "scripts/visual/visual_slice_scene.gd",
        "scenes/visual/visual_vertical_slice.tscn",
        "tools/qa/visual_asset_validator.py",
        "tools/qa/visual_review_validator.py",
        "tools/blender/vertical_slice_session.py",
        "data/blender/future_visual_cast_contracts.json",
        "reports/visual_slice_review_template.json",
    ]
    for rel in required_files:
        assert (ROOT / rel).exists(), rel
    budget = contract["mobile_budget"]["characters"]
    assert budget["lod0_triangles_each"] > budget["lod1_triangles_each"] > budget["lod2_triangles_each"]
    assert budget["texture_max_px"] <= 2048
    assert contract["mobile_budget"]["arena"]["unique_4k_textures"] == 0
    assert contract["visual_review"]["passing_average"] >= 4.0
    assert contract["asset_ingest"]["replace_proxy_only_when_valid"] is True
    future = json.loads((ROOT / "data/blender/future_visual_cast_contracts.json").read_text(encoding="utf-8"))
    assert future["status"] == "contracts_only_until_vertical_slice_accepted"
    print("VISUAL_SLICE_RUNTIME_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
