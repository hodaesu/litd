extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_timeline_speed_priority()
    _test_capture_preserves_body_state()
    _test_failed_seal_memory_becomes_resistance()
    _finish()

func _test_timeline_speed_priority() -> void:
    var slow := {"id": "slow", "name": "Lent", "hp": 20, "speed": 4, "fear": 0}
    var fast := {"id": "fast", "name": "Rapide", "hp": 20, "speed": 18, "enemy_fear": 0}
    var entries: Array = ActionTimelineDirector.rebuild([slow], [fast])
    _check(entries.size() == 2, "G01/T01 : la timeline doit contenir les deux combattants vivants")
    if entries.size() == 2:
        _check(str((entries[0] as Dictionary).get("id", "")) == "fast", "G01/T01 : un combattant nettement plus rapide doit agir avant le lent")

func _test_capture_preserves_body_state() -> void:
    CreatureManager.reset_new_game(62001)
    var creature := {
        "instance_id": "hungry_ghoul-prepc-0001",
        "species_id": "hungry_ghoul",
        "enemy_id": 1,
        "name": "Goule test",
        "level": 1,
        "xp": 0,
        "skill_points": 1,
        "unlocked_skills": [],
        "specialization": ""
    }
    CreatureManager.captured_creatures = [creature]
    CreatureManager.active_instance_id = str(creature.get("instance_id", ""))

    var enemy := {
        "id": 1,
        "name": "Goule amputée",
        "hp": 0,
        "max_hp": 24,
        "captured": true,
        "remanence_id": "entity:prepc:ghoul-amputee",
        "dismembered_parts": ["arm_right"],
        "anatomy_injuries": {"arm_right": "critical", "leg_left": "wounded"},
        "anatomy_part_states": {"arm_right": "lost", "leg_left": "wounded"},
        "anatomy_part_trauma": {"arm_right": 100, "leg_left": 37},
        "persistent_injuries": [{"id": "leg_left_old_wound", "part_id": "leg_left"}],
        "body_state": {"mobility": "impaired"}
    }
    GameState.battle_enemies = [enemy]

    CreatureManager.creature_captured.emit(creature.duplicate(true))
    var captured := CreatureManager.get_creature(str(creature.get("instance_id", "")))
    _check(not captured.is_empty(), "G06/T22 : la recrue doit rester présente après transfert corporel")
    _check((captured.get("dismembered_parts", []) as Array).has("arm_right"), "G06/T22 : le membre perdu doit rester perdu après ralliement")
    _check(str((captured.get("anatomy_part_states", {}) as Dictionary).get("arm_right", "")) == "lost", "G06/T22 : l'état anatomique perdu doit être transféré")
    _check(int((captured.get("anatomy_part_trauma", {}) as Dictionary).get("arm_right", 0)) == 100, "G06/T22 : le trauma anatomique doit être conservé")
    _check(not (captured.get("persistent_injuries", []) as Array).is_empty(), "G06/T22 : les blessures persistantes doivent être conservées")
    _check(str(captured.get("remanence_origin_id", "")) == "entity:prepc:ghoul-amputee", "G06/T22 : l'origine de Rémanence doit être conservée")
    _check(bool(captured.get("anatomy_recovery_locked", false)), "G06/T22 : une capture mutilée doit commencer en convalescence")

    var recovered := CaptureWoundRuntime.provide_sanctuary_care(str(creature.get("instance_id", "")), 999)
    _check(not bool(recovered.get("anatomy_recovery_locked", true)), "G06/T22 : les soins terminés doivent lever la convalescence")
    _check((recovered.get("dismembered_parts", []) as Array).has("arm_right"), "G06/T22 : les soins ne doivent jamais faire repousser un membre")
    _check((recovered.get("disabled_anatomy_parts", []) as Array).has("arm_right"), "G06/T22 : un membre absent doit rester fonctionnellement indisponible")
    _check(str(recovered.get("capture_condition", "")) == "adapted", "G06/T22 : une recrue amputée stabilisée doit être adaptée, pas miraculeusement restaurée")

func _test_failed_seal_memory_becomes_resistance() -> void:
    RemanenceRuntime.reset_new_game()
    var director: Node = RemanenceCombatBridge.world_director
    _check(director != null, "G06/T24 : le directeur mondial de Rémanence doit exister")
    if director == null:
        return
    director.call("reset_new_game")

    var enemy := {"id": 8, "species_id": "traque_suie", "name": "Traque-Suie du sceau", "hp": 20, "max_hp": 20, "damage": [3, 5]}
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, "premier_voile")
    RemanenceRuntime.note_encounter(enemy, "premier_voile")
    for attempt_index in range(3):
        RemanenceRuntime.record_enemy_event(enemy, "capture_escaped", {"region_id": "premier_voile", "attempt": attempt_index + 1})
    RemanenceRuntime.note_encounter(enemy, "premier_voile")

    var record := RemanenceRuntime.entity_state(entity_id)
    _check(str(record.get("stage", "")) == "veteran", "G06/T24 : trois sceaux échoués puis une seconde rencontre doivent suffire au stade vétéran")
    _check((record.get("adaptations", []) as Array).has("seal_resistance"), "G06/T24 : la mémoire des sceaux échoués doit attribuer automatiquement la résistance au sceau")

    var fresh := {"id": 8, "species_id": "traque_suie", "name": "Traque-Suie revenu", "hp": 20, "max_hp": 20, "damage": [3, 5]}
    director.call("apply_entity_memory_to_enemy", fresh, entity_id)
    _check(int(fresh.get("remanence_capture_resistance", 0)) > 0, "G06/T24 : l'adaptation doit produire une résistance de capture réelle lors du retour")
    fresh["hp"] = 1
    var without_memory: Dictionary = fresh.duplicate(true)
    without_memory.erase("remanence_capture_resistance")
    var remembered_chance := CreatureManager.capture_chance(fresh)
    var baseline_chance := CreatureManager.capture_chance(without_memory)
    _check(remembered_chance < baseline_chance, "G06/T24 : un adversaire qui se souvient du sceau doit devenir effectivement plus difficile à rallier")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    GameState.battle_enemies = []
    if failures.is_empty():
        print("VEILLEURS_PREPC_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_PREPC_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_PREPC_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
