import json
from pathlib import Path

from tools.quality.global_governance import REGISTRY_ROOT, validate
from tools.quality.knowledge_intake import apply_plan, plan_intake
from tools.quality.veilleur_v2_ingest import canonical_content_hash


def _root(tmp_path: Path) -> Path:
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_bytes(source.read_bytes())
    return tmp_path


def _event(summary: str = "Godot UI guidance validated to apply to LITD Les Veilleurs") -> dict:
    title = "Verified LITD interface research"
    source_url = "https://example.com/verified-interface-research"
    return {
        "evidence_id": "EV-INTAKE-003",
        "title": title,
        "summary": summary,
        "source_url": source_url,
        "source_verified": True,
        "source_confidence": 0.9,
        "discovered_at": "2026-09-11T13:00:00Z",
        "published_at": "2026-09-10T13:00:00Z",
        "domain_hints": ["ui", "litd"],
        "content_hash": canonical_content_hash(title, summary, source_url),
        "counterevidence": ["Small-screen density may offset the desktop readability benefit."],
    }


def test_verified_litd_event_builds_experimental_candidate(tmp_path: Path):
    root = _root(tmp_path)
    before = (root / "knowledge_registry.json").read_bytes()
    plan = plan_intake(_event(), root)
    assert plan.status == "LITD_KNOWLEDGE_CANDIDATE"
    assert plan.requires_human_review is True
    assert plan.core_write_allowed is False
    assert (root / "knowledge_registry.json").read_bytes() == before
    apply_plan(plan, root)
    assert validate(root) == []
    entries = json.loads((root / "knowledge_registry.json").read_text())["entries"]
    assert entries[-1]["status"] == "EXPERIMENTAL"
    assert entries[-1]["source_evidence_ids"] == ["EV-INTAKE-003"]


def test_unverified_event_is_quarantined(tmp_path: Path):
    event = _event()
    event["source_verified"] = False
    assert plan_intake(event, _root(tmp_path)).status == "QUARANTINED"


def test_general_information_does_not_enter_litd_registry(tmp_path: Path):
    event = _event("Godot GDScript performance optimization for procedural generation")
    event["title"] = "Verified engine research"
    event["domain_hints"] = ["godot", "performance"]
    event["content_hash"] = canonical_content_hash(event["title"], event["summary"], event["source_url"])
    plan = plan_intake(event, _root(tmp_path))
    assert plan.status == "ROUTED_GENERAL"
    assert plan.registry_payload is None


def test_litd_candidate_requires_counterevidence(tmp_path: Path):
    event = _event()
    event["counterevidence"] = []
    plan = plan_intake(event, _root(tmp_path))
    assert plan.status == "QUARANTINED"
    assert plan.reason == "counterevidence_required_for_litd_candidate"


def test_low_confidence_litd_candidate_is_quarantined(tmp_path: Path):
    event = _event()
    event["source_confidence"] = 0.69
    plan = plan_intake(event, _root(tmp_path))
    assert plan.status == "QUARANTINED"
    assert plan.reason == "source_confidence_below_litd_threshold"


def test_reapplying_identical_candidate_is_idempotent(tmp_path: Path):
    root = _root(tmp_path)
    first = plan_intake(_event(), root)
    apply_plan(first, root)
    second = plan_intake(_event(), root)
    assert second.status == "ALREADY_REGISTERED"
    apply_plan(second, root)
    assert validate(root) == []
