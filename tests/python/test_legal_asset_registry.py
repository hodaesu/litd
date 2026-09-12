from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "legal" / "ASSET-LITD.csv"

ALLOWED_STATUS = {
    "ORANGE",
    "GREEN",
    "RED",
    "LEGACY_PLACEHOLDER",
    "REPLACE_BEFORE_RELEASE",
}
UNVERIFIED_VALUES = {"", "TO_VERIFY", "UNVERIFIED", "UNKNOWN", "N/A"}


def _rows() -> list[dict[str, str]]:
    assert REGISTRY.is_file(), "legal/ASSET-LITD.csv is required"
    with REGISTRY.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def test_asset_registry_has_unique_ids_and_paths() -> None:
    rows = _rows()
    assert len(rows) >= 64
    ids = [row["asset_id"] for row in rows]
    paths = [row["path"] for row in rows]
    assert len(ids) == len(set(ids)), "duplicate asset_id in ASSET-LITD.csv"
    assert len(paths) == len(set(paths)), "duplicate path in ASSET-LITD.csv"


def test_asset_registry_status_values_are_controlled() -> None:
    for row in _rows():
        assert row["status"] in ALLOWED_STATUS, (
            f"{row['asset_id']}: unsupported legal status {row['status']!r}"
        )


def test_green_assets_have_a_documented_rights_chain() -> None:
    """GREEN is a release assertion and must never be granted on incomplete metadata."""
    required_for_green = (
        "source",
        "creator",
        "ownership",
        "license",
        "license_evidence",
        "commercial_ok",
        "attribution_required",
    )
    for row in _rows():
        if row["status"] != "GREEN":
            continue
        for field in required_for_green:
            assert row[field].strip().upper() not in UNVERIFIED_VALUES, (
                f"{row['asset_id']}: GREEN asset has unverified {field}"
            )
        assert row["commercial_ok"].strip().upper() in {"YES", "TRUE", "OK"}, (
            f"{row['asset_id']}: GREEN asset is not explicitly cleared for commercial use"
        )


def test_registered_repository_assets_exist() -> None:
    """Existing repository binaries cannot silently disappear without registry cleanup."""
    for row in _rows():
        if row["source"] != "REPOSITORY":
            continue
        assert (ROOT / row["path"]).is_file(), f"missing registered asset: {row['path']}"
