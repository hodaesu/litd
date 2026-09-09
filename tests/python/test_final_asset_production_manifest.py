from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "art" / "v41" / "PRODUCTION_MANIFEST.csv"

VALID_PRIORITIES = {"P0", "P1", "P2"}
VALID_STATUS = {
    "missing",
    "placeholder",
    "candidate",
    "approved",
    "final",
    "blocked_name_clearance",
    "blocked_quartet_reset",
}
VALID_LEGAL = {"TO_DOCUMENT", "ORANGE", "GREEN", "RED", "BLOCKED"}


def rows() -> list[dict[str, str]]:
    assert MANIFEST.is_file(), "canonical production manifest is required"
    with MANIFEST.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def test_production_manifest_has_unique_ids_and_targets() -> None:
    data = rows()
    ids = [r["asset_id"] for r in data]
    targets = [r["target_path"] for r in data]
    assert len(ids) == len(set(ids)), "duplicate production asset id"
    assert len(targets) == len(set(targets)), "duplicate production target path"


def test_production_manifest_uses_controlled_states() -> None:
    for row in rows():
        assert row["priority"] in VALID_PRIORITIES
        assert row["status"] in VALID_STATUS
        assert row["legal_status"] in VALID_LEGAL


def test_p0_starter_portraits_are_neutral_and_blocked_during_reset() -> None:
    heroes = [r for r in rows() if r["asset_id"].startswith("ART-LITD-V41-HERO-")]
    assert [r["entity_id"] for r in heroes] == [
        "starter_slot_01",
        "starter_slot_02",
        "starter_slot_03",
        "starter_slot_04",
    ]
    assert all(r["display_name"].startswith("UNASSIGNED STARTER") for r in heroes)
    assert all(r["status"] == "blocked_quartet_reset" for r in heroes)
    assert all(r["legal_status"] == "BLOCKED" for r in heroes)
    stale = {"sahen_varo", "mira_sen", "narem_osh", "ysra_nahal"}
    assert stale.isdisjoint({r["entity_id"] for r in heroes})


def test_release_ready_art_requires_green_legal_status() -> None:
    for row in rows():
        if row["status"] in {"approved", "final"}:
            assert row["legal_status"] == "GREEN", (
                f"{row['asset_id']}: {row['status']} asset must be legally GREEN"
            )


def test_final_wordmark_remains_blocked_until_title_clearance() -> None:
    wordmarks = [r for r in rows() if r["slot_or_family"] == "brand.wordmark"]
    assert len(wordmarks) == 1
    assert wordmarks[0]["status"] == "blocked_name_clearance"
    assert wordmarks[0]["legal_status"] == "BLOCKED"
