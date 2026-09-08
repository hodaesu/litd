from tools.qa.veilleurs_maturity_dashboard import build_dashboard


def test_dashboard_preserves_five_stage_model_and_blocks_scale_up():
    registry = {
        "systems": [
            {
                "id": "combat_core",
                "label": "Combat principal",
                "current_stage": "technically_validated",
                "next_gate": "combat_decision_readability",
                "player_evidence": [],
                "mobile_evidence": [],
                "production_evidence": [],
                "blocking_reason": "No human evidence yet",
            }
        ]
    }
    player_contract = {"gates": [{"id": "combat_decision_readability"}]}
    hardware_contract = {"gates": [{"id": "real_mobile_touch"}]}

    dashboard = build_dashboard(registry, player_contract, hardware_contract)

    assert [stage["rank"] for stage in dashboard["stages"]] == [1, 2, 3, 4, 5]
    system = dashboard["systems"][0]
    assert system["rank"] == 2
    assert system["stage_label"] == "Testé techniquement"
    assert system["next_gate_kind"] == "player"
    assert system["scale_up_allowed"] is False
    assert dashboard["summary"]["scale_up_allowed"] is False
    assert "Preuve humaine versionnée absente" in system["blockers"]


def test_production_locked_system_can_scale():
    registry = {
        "systems": [
            {
                "id": "combat_core",
                "current_stage": "production_locked",
                "next_gate": None,
                "player_evidence": ["playtest.json"],
                "mobile_evidence": ["iphone.json"],
                "production_evidence": ["lock.json"],
            }
        ]
    }
    dashboard = build_dashboard(registry, {"gates": []}, {"gates": []})
    assert dashboard["systems"][0]["scale_up_allowed"] is True
    assert dashboard["summary"]["scale_up_allowed"] is True
