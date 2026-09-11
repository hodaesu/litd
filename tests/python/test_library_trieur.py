from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "quality" / "library_trieur.py"
spec = spec_from_file_location("library_trieur", MODULE_PATH)
assert spec and spec.loader
module = module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

Route = module.Route
route_information = module.route_information
can_write_core = module.can_write_core


def test_unverified_source_is_quarantined():
    decision = route_information("Godot 4 improves performance", source_verified=False)
    assert decision.route == Route.QUARANTINE
    assert decision.core_write_allowed is False


def test_general_knowledge_stays_general():
    decision = route_information(
        "Godot GDScript performance optimization technique for procedural generation",
        source_verified=True,
    )
    assert decision.route == Route.GENERAL
    assert decision.cross_reference is False


def test_litd_specific_information_goes_to_project_library():
    decision = route_information(
        "LITD Les Veilleurs uses Mathilde and Marec in the expedition",
        source_verified=True,
    )
    assert decision.route == Route.LITD


def test_mixed_general_information_needs_explicit_litd_application():
    decision = route_information(
        "Godot UI accessibility guidance and LITD notes",
        source_verified=True,
    )
    assert decision.route == Route.QUARANTINE


def test_explicit_litd_application_cross_references_general_source():
    decision = route_information(
        "Godot UI accessibility guidance approved and validated to apply to LITD Les Veilleurs",
        source_verified=True,
    )
    assert decision.route == Route.LITD
    assert decision.cross_reference is True


def test_unknown_domain_is_quarantined():
    decision = route_information("An unrelated observation with no known domain", source_verified=True)
    assert decision.route == Route.QUARANTINE


def test_trieur_never_authorizes_core_write():
    samples = [
        "Godot performance optimization",
        "LITD Terre des Cendres expedition",
        "Godot UI validated to apply to LITD",
    ]
    for text in samples:
        decision = route_information(text, source_verified=True)
        assert can_write_core(decision) is False
        assert decision.core_write_allowed is False
