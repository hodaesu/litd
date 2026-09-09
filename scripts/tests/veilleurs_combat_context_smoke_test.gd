extends Node

func _ready() -> void:
    var roster := VeilleursCombatContextRuntime.hero_roster()
    assert(roster.size() == 4)
    assert(str(roster[0].get("name")) == "Mathilde")
    assert(str(roster[1].get("name")) == "Marec")
    assert(str(roster[2].get("name")) == "Anouk")
    assert(str(roster[3].get("name")) == "Aurélien")
    for i in roster.size():
        assert(int(roster[i].get("formation_slot")) == i + 1)
        assert(int(roster[i].get("ap")) == 2)

    var mathilde: Dictionary = roster[0]
    mathilde["pain_state"] = "severe"
    mathilde["debuffs"] = [
        {"id":"arm_injury", "name":"Bras lésé", "priority":100},
        {"id":"pain", "name":"Douleur", "priority":80},
        {"id":"accuracy_down", "name":"Précision réduite", "priority":60},
        {"id":"minor", "name":"Effet mineur", "priority":10},
    ]
    mathilde["anatomy"] = {
        "right_arm": {"state":"injured", "armor":"light", "function":"impaired", "injuries":["arm_injury"]}
    }
    var hero_quick := VeilleursCombatContextRuntime.quick_summary(mathilde)
    assert(int(hero_quick.get("debuff_count")) == 4)
    assert(int(hero_quick.get("more_effects")) == 1)
    var hero_detail := VeilleursCombatContextRuntime.detailed_inspection(mathilde)
    assert(int(hero_detail.get("inspection_cost_ap")) == 0)
    assert(bool(hero_detail.get("read_only")))

    var enemy := {
        "id":"ash_bearer_01",
        "name":"Porte-Cendre",
        "side":"enemy",
        "formation_slot":1,
        "public_vital_state":"wounded",
        "pain_state":"severe",
        "bleeding_state":"critical",
        "buffs":[{"id":"guard", "name":"Garde", "priority":90}],
        "anatomy":{"right_leg":{"state":"injured","armor":"weak","function":"impaired","injuries":["fracture"]}}
    }
    var knowledge := {}
    var hidden := VeilleursCombatContextRuntime.detailed_inspection(enemy, knowledge)
    assert(str(hidden.get("pain_state")) == "unknown")
    var hidden_zones: Array = hidden.get("anatomy", [])
    assert(not bool(hidden_zones[5].get("known")))

    VeilleursCombatContextRuntime.record_enemy_observation(knowledge, "ash_bearer_01", "pain_state", "severe")
    VeilleursCombatContextRuntime.record_enemy_zone(knowledge, "ash_bearer_01", "right_leg", {"state":"injured","armor":"weak","function":"impaired","injuries":["fracture"]})
    var revealed := VeilleursCombatContextRuntime.detailed_inspection(enemy, knowledge)
    assert(str(revealed.get("pain_state")) == "severe")
    var zones: Array = revealed.get("anatomy", [])
    assert(bool(zones[5].get("known")))
    assert(str(zones[5].get("function")) == "impaired")

    print("VEILLEURS_COMBAT_CONTEXT_SMOKE_OK")
    get_tree().quit(0)
