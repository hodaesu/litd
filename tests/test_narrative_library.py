import json
from pathlib import Path

from tools.qa.narrative_library_audit import run

ROOT = Path(__file__).resolve().parents[1]


def test_narrative_library_audit_has_no_errors():
    payload = run()
    failures = [item for item in payload["checks"] if not item["ok"]]
    assert not failures, failures


def test_sidequests_mix_multiple_narrative_families():
    payload = run()
    family_checks = [
        item for item in payload["checks"]
        if "trois familles narratives distinctes" in item["name"]
    ]
    assert family_checks
    assert all(item["ok"] for item in family_checks)


def test_global_folklore_atlas_is_broad_and_not_a_story_copy_bank():
    atlas = json.loads((ROOT / "data/global_folklore_atlas.json").read_text(encoding="utf-8"))
    regions = atlas["regions"]
    clusters = [cluster for region in regions for cluster in region.get("reference_clusters", [])]
    assert len(regions) >= 28
    assert len(clusters) >= 200
    assert len(atlas["narrative_forms"]) >= 25
    assert len(atlas["motif_families"]) >= 40
    forbidden = " ".join(atlas["cultural_protocol"]["forbidden"]).lower()
    assert "copier un conte" in forbidden
    assert "restreint" in forbidden
    assert "community_review_required" in atlas["cultural_protocol"]["access_levels"]


def test_global_folklore_atlas_covers_world_regions_without_pan_indigenous_bucket():
    atlas = json.loads((ROOT / "data/global_folklore_atlas.json").read_text(encoding="utf-8"))
    ids = {region["id"] for region in atlas["regions"]}
    for region_id in [
        "west_africa", "south_asia", "china", "oceania", "indigenous_australia",
        "indigenous_north_america", "mesoamerica_central_america", "andes_amazonia",
        "celtic_atlantic", "slavic_baltic_finnic", "arctic_circumpolar",
    ]:
        assert region_id in ids
    north = next(region for region in atlas["regions"] if region["id"] == "indigenous_north_america")
    assert any("aucun 'mythe amérindien générique'" in item.lower() for item in north["reference_clusters"])
