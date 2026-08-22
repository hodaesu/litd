extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    var calm := {"id":"darius","hp":100,"max_hp":100,"fear":0,"madness":0}
    var terrified := {"id":"darius","hp":100,"max_hp":100,"fear":82,"madness":0}
    var fractured := {"id":"aurelien","hp":100,"max_hp":100,"fear":40,"madness":90}
    var injured := {"id":"darius","hp":45,"max_hp":100,"fear":10,"applied_injury_states":{"arm_l":"injured"}}
    var crippled := {"id":"darius","hp":70,"max_hp":100,"fear":10,"mobility_injury":"critical"}
    var hopeful := {"id":"lysandra","hp":90,"max_hp":100,"fear":20,"hope":80}

    _expect(BodyStateDirector.evaluate(calm).get("psychological_state") == "neutral", "calm state")
    _expect(BodyStateDirector.evaluate(terrified).get("psychological_state") == "terrified", "terrified state")
    _expect(BodyStateDirector.evaluate(fractured).get("psychological_state") == "fractured", "madness state")
    _expect(BodyStateDirector.evaluate(injured).get("physical_state") == "injured", "injured posture")
    _expect(BodyStateDirector.evaluate(crippled).get("locomotion_state") == "limp_walk", "limp locomotion")
    _expect(BodyStateDirector.evaluate(hopeful).get("psychological_state") == "hope", "hope posture")

    var attack: Dictionary = BodyStateDirector.combat_action_plan(injured, "attack_heavy")
    _expect(bool(attack.get("valid", false)), "heavy attack contract")
    _expect((attack.get("required_markers", []) as Array).has("impact"), "impact marker")
    _expect(float(attack.get("gameplay_timing_scale", 0.0)) == 1.0, "gameplay timing authority")
    _expect(float(attack.get("visual_recovery_scale", 1.0)) > 1.0, "injury visual recovery")

    var leg_hit: Dictionary = BodyStateDirector.hit_reaction(calm, "leg", "critical")
    _expect(str(leg_hit.get("clip", "")) == "collapse_leg", "leg-specific critical reaction")

    var relational: Dictionary = BodyStateDirector.evaluate(calm, {"relation_intent":"protect"})
    _expect(str(relational.get("layers", {}).get("relation", "")) == "protect_ally", "relation additive layer")

    if failures.is_empty():
        print("BODY_STATE_DIRECTOR_SMOKE_OK")
        get_tree().quit(0)
    else:
        for failure: String in failures:
            push_error("BODY_STATE_DIRECTOR_SMOKE: %s" % failure)
        get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
