extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_timeline_speed_priority()
    _test_capture_preserves_body_state()
    _test_failed_seal_memory_becomes_resistance()
    _test_witnesses_can_disagree()
    _test_remembered_enemy_survival_and_death_rules()
    _test_lost_limb_survives_adaptation()
    _test_autosave_backup_recovery()
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

func _test_witnesses_can_disagree() -> void:
    GameState.reset_new_game()
    FieldMemoryRuntime.prepare_party()
    _check(GameState.party.size() >= 2, "G08/T29 : deux Veilleurs sont requis")
    if GameState.party.size() < 2:
        return
    var supporter: Dictionary = GameState.party[0]
    var opponent: Dictionary = GameState.party[1]
    supporter["convictions"] = {"solidarity": 3, "security": -2, "mercy": 3, "openness": 2, "pragmatism": -1, "justice": 1}
    opponent["convictions"] = {"solidarity": -3, "security": 3, "mercy": -3, "openness": -2, "pragmatism": 2, "justice": -1}
    var result := FieldMemoryRuntime.record_resource_choice("prepc_shared_event", "aid", "aider les survivants")
    _check(bool(result.get("applied", false)), "G08/T29 : un événement partagé doit créer une mémoire de terrain")
    var reactions: Dictionary = result.get("reactions", {})
    var first: Dictionary = reactions.get(str(supporter.get("id", "")), {})
    var second: Dictionary = reactions.get(str(opponent.get("id", "")), {})
    _check(not first.is_empty() and not second.is_empty(), "G08/T29 : les deux témoins doivent recevoir leur propre interprétation")
    _check(int(first.get("score", 0)) > 0 and int(second.get("score", 0)) < 0, "G08/T29 : deux témoins du même fait doivent pouvoir conclure en sens opposé")
    _check(str(first.get("stance", "")) != str(second.get("stance", "")), "G08/T29 : leurs croyances persistantes doivent pouvoir diverger")

func _test_remembered_enemy_survival_and_death_rules() -> void:
    RemanenceRuntime.reset_new_game()
    var survivor := {"id": 8, "species_id": "traque_suie", "name": "Survivant", "hp": 12, "max_hp": 20}
    var survivor_id := RemanenceRuntime.prepare_enemy(survivor, "premier_voile")
    RemanenceRuntime.note_encounter(survivor, "premier_voile")
    RemanenceRuntime.record_enemy_event(survivor, "survived_combat", {"region_id": "premier_voile"})
    RemanenceRuntime.record_enemy_event(survivor, "forced_retreat", {"region_id": "premier_voile"})
    var survivor_record := RemanenceRuntime.entity_state(survivor_id)
    _check(int(survivor_record.get("score", 0)) > 0, "G09/T33 : survivre et forcer une retraite doit laisser une preuve mémorielle")
    _check(RemanenceRuntime.recent_events(survivor_id, 4).size() >= 3, "G09/T33 : la chronologie doit conserver rencontre, survie et fuite")

    var doomed := {"id": 1, "species_id": "hungry_ghoul", "name": "Éphémère", "hp": 10, "max_hp": 10}
    GameState.battle_enemies = [doomed]
    RemanenceCombatBridge._on_new_game_reset()
    RemanenceCombatBridge._begin_current_combat()
    var doomed_id := str(doomed.get("remanence_id", ""))
    doomed["hp"] = 0
    RemanenceCombatBridge._scan_enemy_changes()
    RemanenceCombatBridge._finish_current_combat(true, "victory")
    var dead_record := RemanenceRuntime.entity_state(doomed_id)
    _check(str(dead_record.get("status", "")) == "dead", "G09/T34 : une mort immédiate doit fermer l'identité active")
    _check(str(dead_record.get("stage", "")) == "normal", "G09/T34 : un ennemi mort dès sa première rencontre ne doit pas évoluer post-mortem")

func _test_lost_limb_survives_adaptation() -> void:
    RemanenceRuntime.reset_new_game()
    var director: Node = RemanenceCombatBridge.world_director
    if director == null:
        _check(false, "G09/T36 : le directeur mondial est requis")
        return
    director.call("reset_new_game")
    var enemy := {"id": 8, "species_id": "traque_suie", "name": "Ancien mutilé", "hp": 20, "max_hp": 20}
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, "premier_voile")
    RemanenceRuntime.note_encounter(enemy, "premier_voile")
    RemanenceRuntime.record_enemy_event(enemy, "major_mutilation", {"object_id": "arm_right", "summary": "Bras droit perdu"})
    var record: Dictionary = RemanenceRuntime.entities.get(entity_id, {})
    record["stage"] = "veteran"
    record["score"] = 8
    record["encounters"] = 2
    record["body_snapshot"] = {
        "dismembered_parts": ["arm_right"],
        "anatomy_injuries": {"arm_right": "critical"},
        "anatomy_part_states": {"arm_right": "lost"},
        "anatomy_part_trauma": {"arm_right": 100},
        "persistent_injuries": [],
        "body_state": {}
    }
    RemanenceRuntime.entities[entity_id] = record
    _check(RemanenceRuntime.add_adaptation(entity_id, "guard_old_wound"), "G09/T36 : l'ennemi vétéran doit pouvoir apprendre à protéger son ancienne plaie")
    var returned := {"id": 8, "species_id": "traque_suie", "name": "Ancien mutilé revenu", "hp": 20, "max_hp": 20}
    director.call("apply_entity_memory_to_enemy", returned, entity_id)
    _check((returned.get("dismembered_parts", []) as Array).has("arm_right"), "G09/T36 : une adaptation ne doit jamais recréer un membre perdu")
    _check(str((returned.get("anatomy_part_states", {}) as Dictionary).get("arm_right", "")) == "lost", "G09/T36 : l'état anatomique perdu doit survivre à l'adaptation")
    _check(str(returned.get("protected_anatomy_part", "")) == "arm_right", "G09/T36 : l'adaptation peut protéger la plaie restante sans annuler la mutilation")

func _test_autosave_backup_recovery() -> void:
    SaveManager.delete_slot(SaveManager.AUTOSAVE_SLOT)
    GameState.gold = 444
    _check(SaveManager.autosave("prepc_a"), "G13/T46 : la première autosauvegarde doit réussir")
    GameState.gold = 555
    _check(SaveManager.autosave("prepc_b"), "G13/T46 : la seconde autosauvegarde doit créer un état courant et un secours")
    var autosave_path := "user://litd_autosave.json"
    var corrupt := FileAccess.open(autosave_path, FileAccess.WRITE)
    _check(corrupt != null, "G13/T46 : le test doit pouvoir simuler une interruption/corruption")
    if corrupt != null:
        corrupt.store_string("{corrupted_autosave")
        corrupt.flush()
        corrupt.close()
    GameState.gold = 1
    _check(SaveManager.load_game(SaveManager.AUTOSAVE_SLOT), "G13/T46 : une autosauvegarde corrompue doit pouvoir reprendre depuis le secours cohérent")
    _check(GameState.gold == 444, "G13/T46 : la reprise doit restaurer l'état A valide plutôt qu'un état partiellement écrit")
    SaveManager.delete_slot(SaveManager.AUTOSAVE_SLOT)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    GameState.battle_enemies = []
    RemanenceCombatBridge._on_new_game_reset()
    if failures.is_empty():
        print("VEILLEURS_PREPC_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_PREPC_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_PREPC_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)