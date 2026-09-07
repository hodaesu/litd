import importlib.util
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "veilleurs"
PACK_SHA = "0739666c23b6aad99d79128147b84322155bbdd5ff49c62b0990eaf11fec8919"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_1305_enemy_skills_are_covered_by_87_tree_intent_bindings():
    data = load(DATA / "enemy_skill_intent_contract_v1.json")
    assert data["skill_total"] == 1305
    assert data["entity_count"] == 29
    assert data["trees_per_entity"] == 3
    assert data["skills_per_tree"] == 15
    assert data["tree_binding_count"] == 87
    assert len(data["tree_bindings"]) == 87
    assert len(data["intent_families"]) == 8
    assert [family["label"] for family in data["intent_families"]] == [
        "Assaut",
        "Contrôle",
        "Repositionnement",
        "Défense",
        "Soutien",
        "Environnement",
        "Chasse/Embuscade",
        "Fuite/Cession/Recrutement",
    ]
    counts = Counter(row[0] for row in data["tree_bindings"])
    assert len(counts) == 29
    assert set(counts.values()) == {3}
    assert sum(data["family_usage"].values()) == 87
    assert data["family_usage"]["fuite_cession_recrutement"] == 0
    assert data["family_8_rule"]["handled_by_combat_state_machine"] is True
    assert data["family_8_rule"]["tactical_withdrawal_inside_combat_is_repositionnement"] is True
    assert data["node_role_overrides"] == {
        "Contrôle": "controle",
        "Interaction monde": "environnement",
    }
    assert data["knowledge_projection"]["stored_knowledge_never_reduced_by_perception"] is True
    assert data["knowledge_projection"]["perception_penalties"] == {
        "clear": 0,
        "low_light": 1,
        "critical_visibility": 2,
        "darkness": 3,
    }
    assert data["source"]["pack_sha256"] == PACK_SHA
    assert sum(source["rows"] for source in data["source"]["files"]) == 1305


def test_enemy_skill_runtime_ids_normalize_30_source_collisions():
    data = load(DATA / "enemy_skill_id_normalization_v1.json")
    assert data["source_skill_rows"] == 1305
    assert data["raw_source_id_unique_count"] == 1275
    assert data["raw_source_id_collision_count"] == 30
    assert data["runtime_unique_count"] == 1305
    assert data["runtime_id_format"] == "{entity_id}:{source_skill_id}"
    assert data["entity_plus_source_id_is_unique"] is True
    assert sum(group["count"] for group in data["collision_groups"]) == 30
    assert data["rules"]["source_ids_are_never_rewritten"] is True
    assert data["rules"]["save_data_uses_runtime_id"] is True


def test_64_narratives_rewards_and_capture_use_name_join_and_locked_hashes():
    data = load(DATA / "encounter_narrative_reward_contract_v1.json")
    assert data["count"] == 64
    assert data["join_key"] == "Rencontre"
    assert data["runtime_join_key"] == "name"
    assert data["source"]["pack_sha256"] == PACK_SHA
    assert data["source"]["narrative"] == {
        "file": "rencontres_narratives_64.json",
        "rows": 64,
        "sha256": "2ce678cc8977c6aa4c21418e0ce5dcee3921c045588673ab3d7d8021a9809cf4",
    }
    assert data["source"]["reward_capture"] == {
        "file": "recompenses_capture.json",
        "rows": 64,
        "sha256": "28806a47068f65897e689cce0eec98b3b943a89ed96006dd3dcb780f9a8b608e",
    }
    assert data["validation"]["fallback_by_row_forbidden"] is True
    assert data["validation"]["missing_name_fatal"] is True
    assert data["capture_guardrails"]["capture_is_not_recruitment"] is True
    assert data["capture_guardrails"]["bosses_recruitable"] is False
    assert data["capture_guardrails"]["probability_display_forbidden"] is True


def test_remanence_hooks_cover_all_canonical_promotion_events_and_rank_gates():
    base = load(DATA / "remanence_entity_contract_v1.json")
    hooks = load(DATA / "remanence_adaptation_hooks_v1.json")
    assert set(hooks["event_hooks"]) == set(base["promotion_events"])
    assert hooks["principles"]["learn_only_from_lived_events"] is True
    assert hooks["principles"]["omniscient_learning_forbidden"] is True
    assert hooks["principles"]["artificial_nemesis_spawn_forbidden"] is True
    assert hooks["principles"]["hp_sponge_promotion_forbidden"] is True
    assert hooks["memory_channels"] == {
        key: value for key, value in hooks["memory_channels"].items()
    }
    assert all(channel["active_slots"] == 1 for channel in hooks["memory_channels"].values())
    assert set(hooks["promotion_gates"]) == {
        "normal_to_memorial",
        "memorial_to_veteran",
        "veteran_to_elite",
        "elite_to_nemesis",
    }
    assert hooks["nemesis_rules"]["rare_by_history_not_rng"] is True
    assert hooks["nemesis_rules"]["shared_history_required"] is True
    assert hooks["nemesis_rules"]["retains_real_injuries"] is True
    assert hooks["nemesis_rules"]["no_global_player_build_read"] is True


def test_prepc_binding_generator_is_importable_and_uses_canonical_pack_sha():
    path = ROOT / "tools/veilleurs/build_runtime_bindings_from_prepc_pack.py"
    spec = importlib.util.spec_from_file_location("veilleurs_prepc_bindings", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    assert module.PACK_SHA == PACK_SHA
    assert module.PREFIX == "litd_canonical_pack_2026-09-03/current/"


def test_generation_contract_wires_new_runtime_content():
    data = load(DATA / "encounter_generation_contract_v1.json")
    assert data["version"] == 4
    assert data["enemy_skill_target"] == 1305
    assert data["runtime_catalogs"]["enemy_skill_intents"].endswith("enemy_skill_intent_contract_v1.json")
    assert data["runtime_catalogs"]["encounter_narrative_rewards"].endswith("encounter_narrative_reward_contract_v1.json")
    assert data["runtime_catalogs"]["remanence_adaptation"].endswith("remanence_adaptation_hooks_v1.json")
    assert data["intent_rules"]["skills_covered"] == 1305
    assert data["intent_rules"]["raw_source_skill_ids_are_not_globally_unique"] is True
    assert data["intent_rules"]["runtime_skill_id_uses_entity_plus_source_id"] is True
