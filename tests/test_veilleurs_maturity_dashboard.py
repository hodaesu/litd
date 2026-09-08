from tools.qa.veilleurs_maturity_dashboard import build_dashboard


def test_dashboard_preserves_five_stage_model_and_blocks_scale_up():
    registry = {
        "project": "LITD : Les Veilleurs",
        "model": "five_stage_system_maturity",
        "systems": [
            {
                "id": "combat_core",
                "label_fr": "Combat principal",
                "current_stage": "technically_validated",
                "next_gate": "combat_decision_readability",
                "evidence": {
                    "design": ["design.md"],
                    "technical": ["smoke.gd"],
                    "player": [],
                    "mobile": [],
                    "production": [],
                },
                "blocking_reason": "No human evidence yet",
            }
        ],
    }
    player_contract = {"gates": [{"id": "combat_decision_readability"}]}
    hardware_contract = {"gates": [{"id": "real_mobile_touch"}]}

    dashboard = build_dashboard(registry, player_contract, hardware_contract)

    assert [stage["rank"] for stage in dashboard["stages"]] == [1, 2, 3, 4, 5]
    system = dashboard["systems"][0]
    assert system["label"] == "Combat principal"
    assert system["rank"] == 2
    assert system["stage_label"] == "Testé techniquement"
    assert system["next_gate_kind"] == "player"
    assert system["proof_counts"]["design"] == 1
    assert system["proof_counts"]["technical"] == 1
    assert system["proof_counts"]["player"] == 0
    assert system["scale_up_allowed"] is False
    assert dashboard["summary"]["scale_up_allowed"] is False
    assert dashboard["summary"]["player_evidence_missing_count"] == 1
    assert "Preuve humaine versionnée absente" in system["blockers"]


def test_production_locked_system_can_scale():
    registry = {
        "systems": [
            {
                "id": "combat_core",
                "label_fr": "Combat principal",
                "current_stage": "production_locked",
                "next_gate": None,
                "evidence": {
                    "design": ["design.md"],
                    "technical": ["smoke.gd"],
                    "player": ["playtest.json"],
                    "mobile": ["iphone.json"],
                    "production": ["lock.json"],
                },
            }
        ]
    }
    dashboard = build_dashboard(registry, {"gates": []}, {"gates": []})
    assert dashboard["systems"][0]["scale_up_allowed"] is True
    assert dashboard["summary"]["scale_up_allowed"] is True


def test_real_mobile_interaction_is_classified_as_player_gate():
    registry = {
        "systems": [
            {
                "id": "mobile_combat_ux",
                "current_stage": "technically_validated",
                "next_gate": "real_mobile_interaction",
                "evidence": {},
            }
        ]
    }
    dashboard = build_dashboard(
        registry,
        {"gates": [{"id": "real_mobile_interaction"}]},
        {"gates": [{"id": "real_mobile_touch"}]},
    )
    assert dashboard["systems"][0]["next_gate_kind"] == "player"
