import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def test_canonical_quartet_voice_contract_is_exact_and_distinct():
    data = load("refuge_veilleur_voice_contract_v1.json")
    expected = ["SAHEN_VARO", "MIRA_SEN", "NAREM_OSH", "YSRA_NAHAL"]
    assert data["canonical_quartet"] == expected
    assert set(data["voices"]) == set(expected)
    assert data["rules"]["voice_layer_does_not_override_combat_class_or_skill_canon"] is True
    assert data["rules"]["legacy_vs001_names_are_not_current_quartet"] is True
    cores = {row["core"] for row in data["voices"].values()}
    assert len(cores) == 4
    for row in data["voices"].values():
        assert len(row["syntax"]) >= 4
        assert len(row["avoid"]) >= 4
        assert set(row["family_lines"]) == {"conflict","rapprochement","grief","mutilation","debate","memoriel","nemesis","refuge_state"}
        assert all(text.strip() for text in row["family_lines"].values())


def test_24_recruit_reaction_profiles_match_enemy_source_exactly():
    source = load("enemies_24_definitions.json")
    reactions = load("recruit_refuge_reactions_24_v1.json")
    source_ids = {row["entity_id"] for row in source["enemies"]}
    profile_ids = {row[0] for row in reactions["profiles"]}
    assert source["count"] == reactions["count"] == 24
    assert source_ids == profile_ids
    assert reactions["rules"]["reaction_profile_never_grants_recruitability"] is True
    assert reactions["rules"]["nonverbal_entities_are_never_forced_into_human_dialogue"] is True
    assert all(len(row) == len(reactions["record_fields"]) for row in reactions["profiles"])


def test_recruit_profiles_preserve_family_and_have_specific_behavior():
    source = {row["entity_id"]: row for row in load("enemies_24_definitions.json")["enemies"]}
    data = load("recruit_refuge_reactions_24_v1.json")
    for row in data["profiles"]:
        entity_id, name_fr, family, speech_mode, baseline, stress, trust, fear, affinities, staging = row
        assert source[entity_id]["name_fr"] == name_fr
        assert source[entity_id]["family"] == family
        assert speech_mode and baseline and stress and trust and fear and affinities and staging
    assert len({row[4] for row in data["profiles"]}) == 24


def test_event_chains_are_two_or_three_acts_and_reference_real_scenes():
    chains = load("refuge_event_chains_v1.json")
    catalog_ids = {row[0] for row in load("refuge_event_catalog_v2.json")["events"]}
    assert chains["chain_count"] == len(chains["chains"]) == 16
    for chain in chains["chains"]:
        assert 2 <= len(chain["acts"]) <= 3
        assert set(chain["acts"]) <= catalog_ids
        assert len(set(chain["acts"])) == len(chain["acts"])
        assert chain["branch_notes"]
    assert chains["rules"]["never_force_next_act_without_trigger"] is True
    assert chains["rules"]["same_entity_ids_preserved_across_acts"] is True


def test_all_49_scenes_have_exactly_one_staging_binding():
    catalog = load("refuge_event_catalog_v2.json")
    staging = load("refuge_event_staging_49_v1.json")
    catalog_ids = {row[0] for row in catalog["events"]}
    binding_ids = [row[0] for row in staging["bindings"]]
    assert catalog["total_active_events"] == staging["binding_count"] == 49
    assert len(binding_ids) == 49
    assert len(set(binding_ids)) == 49
    assert set(binding_ids) == catalog_ids
    assert all(row[1] in staging["profiles"] for row in staging["bindings"])
    assert all(len(row) == len(staging["record_fields"]) for row in staging["bindings"])


def test_staging_preserves_mobile_dignity_and_reload_rules():
    staging = load("refuge_event_staging_49_v1.json")
    rules = staging["global_rules"]
    assert rules["mobile_first"] is True
    assert rules["max_simultaneous_speaking_faces"] == 2
    assert rules["mutilation_never_framed_as_spectacle"] is True
    assert rules["grief_never_uses_reward_stinger"] is True
    assert rules["choice_ui_appears_after_last_spoken_beat"] is True
    assert rules["camera_preserves_character_spatial_relationships_across_reload"] is True


def test_staging_and_voice_contracts_use_current_quartet_not_legacy_cast():
    voice_text = json.dumps(load("refuge_veilleur_voice_contract_v1.json"), ensure_ascii=False).lower()
    for current in ("sahen varo", "mira sen", "narem osh", "ysra nahal"):
        assert current in voice_text
    # Legacy VS001 cast may remain in the older prototype file, but must not be named as current voices here.
    for legacy in ("nayra orun", "tarek senn", "aisha maren", "idris vael"):
        assert legacy not in voice_text
