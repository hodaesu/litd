from __future__ import annotations

import json
from pathlib import Path

from tools.qa.visual_asset_validator import validate_report
from tools.qa.visual_review_validator import validate_review

ROOT = Path(__file__).resolve().parents[1]


def _contract() -> dict:
    return json.loads((ROOT / "data/visual_vertical_slice.json").read_text(encoding="utf-8"))


def _valid_character_report(asset_id: str) -> dict:
    c = _contract()
    return {
        "asset_id": asset_id,
        "triangles_lod0": 50000,
        "triangles_lod1": 25000,
        "triangles_lod2": 10000,
        "materials": 3,
        "bones": len(c["asset_ingest"]["required_bones"]),
        "bone_names": c["asset_ingest"]["required_bones"],
        "skinned_meshes": 2,
        "max_texture_px": 2048,
        "sockets": c["asset_ingest"]["required_sockets"],
        "animations": c["characters"][asset_id]["animation_minimum"],
        "up_axis": "Y",
        "meters_per_unit": 1.0,
        "negative_scale": False,
    }


def test_visual_contract_has_runtime_and_mobile_budgets() -> None:
    c = _contract()
    assert c["version"] == 2
    assert c["asset_ingest"]["replace_proxy_only_when_valid"] is True
    assert c["mobile_budget"]["frame"]["target_fps"] == 60
    assert "combat_telegraph_readability" in c["visual_review"]["blocking_criteria"]


def test_character_validator_accepts_budgeted_darius() -> None:
    c = _contract()
    assert validate_report(_valid_character_report("darius"), c) == []


def test_character_validator_rejects_missing_socket_and_large_texture() -> None:
    c = _contract()
    report = _valid_character_report("enemy_01_goule_affamee")
    report["sockets"] = report["sockets"][:-1]
    report["max_texture_px"] = 4096
    errors = validate_report(report, c)
    assert any("missing socket" in error for error in errors)
    assert "texture resolution budget exceeded" in errors


def test_visual_review_requires_four_on_blocking_criteria() -> None:
    c = _contract()
    criteria = c["visual_review"]["criteria"]
    review = {"scores": {key: 5 for key in criteria}, "approved": True}
    assert validate_review(review, c) == []
    review["scores"]["silhouette"] = 3
    assert any("silhouette" in error for error in validate_review(review, c))


def test_future_cast_is_blocked_until_slice_acceptance() -> None:
    payload = json.loads((ROOT / "data/blender/future_visual_cast_contracts.json").read_text(encoding="utf-8"))
    assert payload["status"] == "contracts_only_until_vertical_slice_accepted"
    assert all("after_validation" in asset["pipeline"] or "extension_after_validation" in asset["pipeline"] for asset in payload["assets"])
