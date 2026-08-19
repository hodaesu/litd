from __future__ import annotations

import json
from pathlib import Path

from tools.qa.sfx_library_audit import run

ROOT = Path(__file__).resolve().parents[1]


def test_sfx_library_audit_is_clean() -> None:
    payload = run(ROOT)
    failures = [item for item in payload["checks"] if not item["ok"]]
    assert not failures, failures


def test_sfx_catalog_has_broad_gameplay_coverage() -> None:
    data = json.loads((ROOT / "data/sfx_library.json").read_text(encoding="utf-8"))
    domains = data["cue_domains"]
    cue_ids = {cue for values in domains.values() for cue in values}
    assert len(cue_ids) >= 80
    assert {"combat", "creature", "psychology", "ambience", "sanctuary", "ui"} <= set(domains)
    assert {"dismemberment", "combat_telegraph", "hope_manifestation", "bell_sanctuary"} <= cue_ids


def test_noncommercial_and_unknown_licenses_are_blocked() -> None:
    data = json.loads((ROOT / "data/sfx_library.json").read_text(encoding="utf-8"))
    excluded = {item["id"] for item in data["excluded_license_classes"]}
    assert "cc_by_nc" in excluded
    assert "unknown_license" in excluded
    assert all(pack["tier"] != "red" for pack in data["candidate_packs"])


def test_catalog_does_not_claim_audio_was_ingested() -> None:
    data = json.loads((ROOT / "data/sfx_library.json").read_text(encoding="utf-8"))
    assert all(pack.get("local_path", "") == "" for pack in data["candidate_packs"])
