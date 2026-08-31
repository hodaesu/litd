from tools.art.search_reference_library import load_library, search
from tools.qa.art_reference_library_audit import audit


def test_art_reference_library_contract_is_valid() -> None:
    assert audit() == []


def test_presets_combine_at_least_three_sources() -> None:
    data = load_library()
    results = search(data, preset="donjon_du_voile")
    assert len(results) >= 3
    assert len({item["culture"] for item in results}) >= 3


def test_search_exposes_mosaics_and_litd_uses() -> None:
    data = load_library()
    results = search(data, category="mosaique")
    assert len(results) >= 3
    assert all(item["litd_uses"] for item in results)


def test_search_exposes_drawings_for_visual_development() -> None:
    data = load_library()
    results = search(data, category="dessin")
    assert len(results) >= 3
    assert all(item["rights"] == "public_domain" for item in results)
