import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARALLEL = ROOT / "data" / "veilleurs" / "parallel_content"


def load(name: str):
    return json.loads((PARALLEL / name).read_text(encoding="utf-8"))


def test_projection_adapter_contract_preserves_existing_owners_and_remanence_rules():
    data = load("refuge_memory_projection_adapter_contract_v1.json")
    assert data["enabled_by_default"] is False
    assert data["runtime_wiring"] == "none"
    assert data["owners"] == {
        "archive": "VeilleursContentRuntime.record_archive_hook",
        "remanence": "VeilleursRuntimeCoordinator / VeilleursRemanencePolicy",
        "memory": "VeilleursRefugeMemoryServiceCandidate",
    }
    archive = data["archive_policy"]
    assert archive["knowledge_upgrade_automatic"] is False
    assert archive["future_boss_phase_write_forbidden"] is True
    assert archive["stored_knowledge_erasure_forbidden"] is True

    remanence = data["remanence_policy"]
    assert remanence["reference_only_default"] is True
    assert remanence["reference_does_not_mutate_rank"] is True
    assert remanence["unknown_or_social_event_never_forwarded_to_policy"] is True
    assert remanence["nemesis_spawn_forbidden"] is True
    assert set(remanence["canonical_promotion_events"]) == {
        "survival", "watcher_kill", "mutilation", "escape", "failed_capture",
        "important_item_taken_or_recovered", "forced_retreat", "repeated_encounter"
    }


def test_projection_adapter_is_candidate_only_and_smoked_in_ci():
    script = ROOT / "scripts" / "core" / "veilleurs_refuge_memory_projection_adapter_candidate.gd"
    scene = ROOT / "scenes" / "tests" / "veilleurs_refuge_memory_projection_adapter_candidate_smoke.tscn"
    assert script.exists()
    assert scene.exists()

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert "VeilleursRefugeMemoryProjectionAdapterCandidate" not in project_text
    assert "veilleurs_refuge_memory_projection_adapter_candidate.gd" not in project_text

    workflow = (ROOT / ".github" / "workflows" / "remanence-smoke.yml").read_text(encoding="utf-8")
    assert "veilleurs_refuge_memory_projection_adapter_candidate_smoke.tscn" in workflow

    forbidden_token = "refuge_memory_projection_adapter_contract_v1.json"
    for path in [
        ROOT / "data" / "veilleurs" / "content_foundation_v2.json",
        ROOT / "data" / "veilleurs" / "encounter_generation_contract_v1.json",
        ROOT / "data" / "veilleurs" / "archives_refuge_ui_contract_v1.json",
    ]:
        assert forbidden_token not in path.read_text(encoding="utf-8")


def test_projection_adapter_never_turns_reference_only_memory_into_canonical_event():
    script_text = (ROOT / "scripts" / "core" / "veilleurs_refuge_memory_projection_adapter_candidate.gd").read_text(encoding="utf-8")
    assert 'event_type == "refuge_memory_shared_history"' in script_text
    assert 'evidence_verified' in script_text
    assert 'canonical_event_type in CANONICAL_PROMOTION_EVENTS' in script_text
    assert 'coordinator.note_enemy_memory_event' in script_text
    assert 'coordinator.runtime_event.emit("refuge_remanence_reference"' in script_text
