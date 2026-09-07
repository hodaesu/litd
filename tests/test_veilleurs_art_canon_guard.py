import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WATCHERS = ROOT / "data/veilleurs/v06/watchers.json"
CATALOG = ROOT / "data/veilleurs/art/asset_catalog_preproduction_v1.json"
MANIFEST = ROOT / "data/veilleurs/art/art_preproduction_manifest_v1.json"

EXPECTED_RUNTIME_IDS = {"nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"}
EXPECTED_ENTITY_IDS = {
    "ENT_WATCHER_NAYRA",
    "ENT_WATCHER_TAREK",
    "ENT_WATCHER_AISHA",
    "ENT_WATCHER_IDRIS",
}
RETIRED_TOKENS = {
    "sahen_varo",
    "mira_sen",
    "narem_osh",
    "ysra_nahal",
    "ent_watcher_sahen",
    "ent_watcher_mira",
    "ent_watcher_narem",
    "ent_watcher_ysra",
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_art_quartet_matches_runtime_canon_exactly():
    watchers = load(WATCHERS)["watchers"]
    assert {watcher["runtime_id"] for watcher in watchers} == EXPECTED_RUNTIME_IDS
    assert {watcher["entity_id"] for watcher in watchers} == EXPECTED_ENTITY_IDS

    catalog = load(CATALOG)
    core = next(package for package in catalog["packages"] if package["id"] == "watchers.core_quartet")
    assert set(core["entities"]) == EXPECTED_RUNTIME_IDS


def test_art_preproduction_contains_no_retired_watcher_ids():
    manifest = load(MANIFEST)
    paths = [ROOT / repo_path for repo_path in manifest["files"].values()]
    for path in paths:
        text = path.read_text(encoding="utf-8").lower()
        for token in RETIRED_TOKENS:
            assert token not in text, f"retired watcher token {token!r} found in {path.relative_to(ROOT)}"
