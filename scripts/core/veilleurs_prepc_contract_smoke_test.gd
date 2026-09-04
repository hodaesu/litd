extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_timeline_cycle_one_action_each()
    _test_timeline_simultaneous_shift_deterministic()
    _test_timeline_boss_multiaction_visible()
    _test_timeline_speed_priority_supplemental()
    _test_timeline_stun_supplemental()
    _test_capture_preserves_body_state()
    _test_failed_seal_memory_becomes_resistance()
    _test_witnesses_can_disagree()
    _test_remembered_enemy_survival_and_death_rules()
    _test_lost_limb_survives_adaptation()
    _test_autosave_backup_recovery()
    _finish()

func _test_timeline_cycle_one_action_each() -> void:
    var heroes: Array = []
    var enemies: Array = []
    for index in range(4):
        heroes.append({"id": "hero_%d" % index, "name": "Veilleur %d" % index, "hp": 20, "speed": 10 + index, "fear": 0})
        enemies.append({"id": "enemy_%d" % index, "name": "Ennemi %d" % index, "hp": 20, "speed": 9 + index, "enemy_fear": 0})
    var queue := ActionTimelineDirector.begin_cycle(heroes, enemies)
    _check(queue.size() == 8, "Tests_48/T01 : 4 Veilleurs + 4 ennemis doivent produire exactement 8 actions primaires")
    var counts: Dictionary = ActionTimelineDirector.cycle_actor_action_counts(false)
    _check(counts.size() == 8, "Tests_48/T01 : chaque acteur vivant doit apparaître exactement une fois dans le cycle")
    for actor_id_value: Variant in counts.keys():
        _check(int(counts.get(actor_id_value, 0)) == 1, "Tests_48/T01 : aucun acteur standard ne doit obtenir un second tour caché")
    var queue_size_before_reaction := ActionTimelineDirector.cycle_snapshot().size()
    var reaction := ActionTimelineDirector.register_reaction("hero_0", "interposition")
    _check(not bool(reaction.get("grants_turn", true)), "Tests_48/T01 : une réaction ne doit jamais accorder un nouveau tour")
    _check(ActionTimelineDirector.cycle_snapshot().size() == queue_size_before_reaction, "Tests_48/T01 : enregistrer une réaction ne doit pas modifier le nombre d'actions du cycle")

func _test_timeline_simultaneous_shift_deterministic() -> void:
    var heroes := [
        {"id": "advance", "name": "Avancé", "hp": 20, "speed": 10, "fear": 0},
        {"id": "neutral_a", "name": "Neutre A", "hp": 20, "speed": 10, "fear": 0}
    ]
    var enemies := [
        {"id": "delay", "name": "Retardé", "hp": 20, "speed": 10, "enemy_fear": 0},
        {"id": "neutral_b", "name": "Neutre B", "hp": 20, "speed": 10, "enemy_fear": 0}
    ]
    ActionTimelineDirector.begin_cycle(heroes, enemies)
    var before := ActionTimelineDirector.cycle_snapshot()
    var shifted := ActionTimelineDirector.apply_cycle_shifts({"advance": 5.0, "delay": -5.0})
    _check(shifted.size() == before.size(), "Tests_48/T02 : avance + retard simultanés ne doivent perdre ni dupliquer d'acteur")
    _check(str((shifted[0] as Dictionary).get("id", "")) == "advance", "Tests_48/T02 : l'avance doit placer l'acteur devant les priorités neutres")
    _check(str((shifted[shifted.size() - 1] as Dictionary).get("id", "")) == "delay", "Tests_48/T02 : le retard doit placer l'acteur derrière les priorités neutres")
    var token_ids: Dictionary = {}
    for token_value: Variant in shifted:
        var token: Dictionary = token_value
        var token_id := str(token.get("token_id", ""))
        _check(token_id != "" and not token_ids.has(token_id), "Tests_48/T02 : chaque entrée doit conserver un jeton unique")
        token_ids[token_id] = true
    ActionTimelineDirector.begin_cycle(heroes, enemies)
    var repeated := ActionTimelineDirector.apply_cycle_shifts({"advance": 5.0, "delay": -5.0})
    var first_order: Array[String] = []
    var second_order: Array[String] = []
    for token_value: Variant in shifted:
        first_order.append(str((token_value as Dictionary).get("id", "")))
    for token_value: Variant in repeated:
        second_order.append(str((token_value as Dictionary).get("id", "")))
    _check(first_order == second_order, "Tests_48/T02 : la résolution simultanée doit être déterministe")

func _test_timeline_boss_multiaction_visible() -> void:
    var heroes := [{"id": "hero", "name": "Veilleur", "hp": 20, "speed": 11, "fear": 0}]
    var enemies := [
        {"id": "boss", "name": "Boss test", "hp": 100, "speed": 10, "enemy_fear": 0, "boss": true, "actions_per_cycle": 3},
        {"id": "minion", "name": "Serviteur", "hp": 20, "speed": 9, "enemy_fear": 0}
    ]
    var queue := ActionTimelineDirector.begin_cycle(heroes, enemies)
    _check(queue.size() == 5, "Tests_48/T03 : 1 héros + 1 serviteur + boss à 3 actions doivent exposer exactement 5 entrées")
    var boss_tokens: Array[Dictionary] = []
    var seen_tokens: Dictionary = {}
    for token_value: Variant in queue:
        var token: Dictionary = token_value
        var token_id := str(token.get("token_id", ""))
        _check(token_id != "" and not seen_tokens.has(token_id), "Tests_48/T03 : chaque action boss doit avoir un jeton séparé")
        seen_tokens[token_id] = true
        if str(token.get("id", "")) == "boss":
            boss_tokens.append(token)
    _check(boss_tokens.size() == 3, "Tests_48/T03 : les trois actions du boss doivent être présentes dans la timeline")
    for boss_token: Dictionary in boss_tokens:
        _check(bool(boss_token.get("visible", false)), "Tests_48/T03 : aucune action boss ne doit être cachée")
        _check(int(boss_token.get("action_index", 0)) >= 1, "Tests_48/T03 : chaque action boss doit être numérotée explicitement")
    var before_reaction := ActionTimelineDirector.cycle_snapshot().size()
    ActionTimelineDirector.register_reaction("boss", "boss_reaction")
    _check(ActionTimelineDirector.cycle_snapshot().size() == before_reaction, "Tests_48/T03 : une réaction boss ne doit pas devenir une action gratuite")

func _test_timeline_speed_priority_supplemental() -> void:
    var slow := {"id": "slow", "name": "Lent", "hp": 20, "speed": 4, "fear": 0}
    var fast := {"id": "fast", "name": "Rapide", "hp": 20, "speed": 18, "enemy_fear": 0}
    var entries: Array = ActionTimelineDirector.rebuild([slow], [fast])
    _check(entries.size() == 2, "Timeline supplément : la prévisualisation doit contenir les deux combattants vivants")
    if entries.size() == 2:
        _check(str((entries[0] as Dictionary).get("id", "")) == "fast", "Timeline supplément : un combattant nettement plus rapide doit être prioritaire")

func _test_timeline_stun_supplemental() -> void:
    var hero := {"id": "stunned", "name": "Étourdi", "hp": 20, "speed": 12, "fear": 0}
    var enemy := {"id": "witness", "name": "Témoin", "hp": 20, "speed": 8, "enemy_fear": 0}
    ActionTimelineDirector.begin_cycle([hero], [enemy])
    ActionTimelineDirector.set_cycle_status("stunned", "stun_turns", 1)
    var event := ActionTimelineDirector.consume_cycle_action()
    _check(str(event.get("id", "")) == "stunned", "Timeline supplément : l'acteur étourdi doit atteindre son créneau")
    _check(bool(event.get("skipped", false)) and bool(event.get("recovered", false)), "Timeline supplément : le créneau étourdi est sauté puis le statut récupère sans créer de tour")

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
    _check(not captured.is_empty(), "Capture supplément : la recrue doit rester présente après transfert corporel")
    _check((captured.get("dismembered_parts", []) as Array).has("arm_right"), "Capture supplément : le membre perdu doit rester perdu après ralliement")
    _check(str((captured.get("anatomy_part_states", {}) as Dictionary).get("arm_right", "")) == "lost", "Capture supplément : l'état anatomique perdu doit être transféré")
    _check(int((captured.get("anatomy_part_trauma", {}) as Dictionary).get("arm_right", 0)) == 100, "Capture supplément : le trauma anatomique doit être conservé")
    _check(not (captured.get("persistent_injuries", []) as Array).is_empty(), "Capture supplément : les blessures persistantes doivent être conservées")
    _check(str(captured.get("remanence_origin_id", "")) == "entity:prepc:ghoul-amputee", "Capture supplément : l'origine de Rémanence doit être conservée")
    _check(bool(captured.get("anatomy_recovery_locked", false)), "Capture supplément : une capture mutilée doit commencer en convalescence")

    var recovered := CaptureWoundRuntime.provide_sanctuary_care(str(creature.get("instance_id", "")), 999)
    _check(not bool(recovered.get("anatomy_recovery_locked", true)), "Capture supplément : les soins terminés doivent lever la convalescence")
    _check((recovered.get("dismembered_parts", []) as Array).has("arm_right"), "Capture supplément : les soins ne doivent jamais faire repousser un membre")
    _check((recovered.get("disabled_anatomy_parts", []) as Array).has("arm_right"), "Capture supplément : un membre absent doit rester fonctionnellement indisponible")
    _check(str(recovered.get("capture_condition", "")) == "adapted", "Capture supplément : une recrue amputée stabilisée doit être adaptée, pas miraculeusement restaurée")

func _test_failed_seal_memory_becomes_resistance() -> void:
    RemanenceRuntime.reset_new_game()
    var director: Node = RemanenceCombatBridge.world_director
    _check(director != null, "Tests_48/T24 : le directeur mondial de Rémanence doit exister")
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
    _check(str(record.get("stage", "")) == "veteran", "Tests_48/T24 : les échecs répétés doivent produire une mémoire durable")
    _check((record.get("adaptations", []) as Array).has("seal_resistance"), "Tests_48/T24 : l'échec de capture doit pouvoir augmenter la résistance mémorisée")

    var fresh := {"id": 8, "species_id": "traque_suie", "name": "Traque-Suie revenu", "hp": 20, "max_hp": 20, "damage": [3, 5]}
    director.call("apply_entity_memory_to_enemy", fresh, entity_id)
    _check(int(fresh.get("remanence_capture_resistance", 0)) > 0, "Tests_48/T24 : la résistance doit être réelle lors d'un retour")
    fresh["hp"] = 1
    var without_memory: Dictionary = fresh.duplicate(true)
    without_memory.erase("remanence_capture_resistance")
    var remembered_chance := CreatureManager.capture_chance(fresh)
    var baseline_chance := CreatureManager.capture_chance(without_memory)
    _check(remembered_chance < baseline_chance, "Tests_48/T24 : la cible qui se souvient du sceau doit devenir effectivement plus difficile à capturer")

func _test_witnesses_can_disagree() -> void:
    GameState.reset_new_game()
    FieldMemoryRuntime.prepare_party()
    _check(GameState.party.size() >= 2, "Mémoire supplément : deux Veilleurs sont requis")
    if GameState.party.size() < 2:
        return
    var supporter: Dictionary = GameState.party[0]
    var opponent: Dictionary = GameState.party[1]
    supporter["convictions"] = {"solidarity": 3, "security": -2, "mercy": 3, "openness": 2, "pragmatism": -1, "justice": 1}
    opponent["convictions"] = {"solidarity": -3, "security": 3, "mercy": -3, "openness": -2, "pragmatism": 2, "justice": -1}
    var result := FieldMemoryRuntime.record_resource_choice("prepc_shared_event", "aid", "aider les survivants")
    _check(bool(result.get("applied", false)), "Mémoire supplément : un événement partagé doit créer une mémoire de terrain")
    var reactions: Dictionary = result.get("reactions", {})
    var first: Dictionary = reactions.get(str(supporter.get("id", "")), {})
    var second: Dictionary = reactions.get(str(opponent.get("id", "")), {})
    _check(not first.is_empty() and not second.is_empty(), "Mémoire supplément : les deux témoins doivent recevoir leur propre interprétation")
    _check(int(first.get("score", 0)) > 0 and int(second.get("score", 0)) < 0, "Mémoire supplément : deux témoins du même fait doivent pouvoir conclure en sens opposé")

func _test_remembered_enemy_survival_and_death_rules() -> void:
    RemanenceRuntime.reset_new_game()
    var survivor := {"id": 8, "species_id": "traque_suie", "name": "Survivant", "hp": 12, "max_hp": 20}
    var survivor_id := RemanenceRuntime.prepare_enemy(survivor, "premier_voile")
    RemanenceRuntime.note_encounter(survivor, "premier_voile")
    RemanenceRuntime.record_enemy_event(survivor, "survived_combat", {"region_id": "premier_voile"})
    RemanenceRuntime.record_enemy_event(survivor, "forced_retreat", {"region_id": "premier_voile"})
    var survivor_record := RemanenceRuntime.entity_state(survivor_id)
    _check(int(survivor_record.get("score", 0)) > 0, "Rémanence supplément : survivre et forcer une retraite doit laisser une preuve mémorielle")
    _check(RemanenceRuntime.recent_events(survivor_id, 4).size() >= 3, "Rémanence supplément : la chronologie doit conserver rencontre, survie et fuite")

    var doomed := {"id": 1, "species_id": "hungry_ghoul", "name": "Éphémère", "hp": 10, "max_hp": 10}
    GameState.battle_enemies = [doomed]
    RemanenceCombatBridge._on_new_game_reset()
    RemanenceCombatBridge._begin_current_combat()
    var doomed_id := str(doomed.get("remanence_id", ""))
    doomed["hp"] = 0
    RemanenceCombatBridge._scan_enemy_changes()
    RemanenceCombatBridge._finish_current_combat(true, "victory")
    var dead_record := RemanenceRuntime.entity_state(doomed_id)
    _check(str(dead_record.get("status", "")) == "dead", "Rémanence supplément : une mort immédiate doit fermer l'identité active")
    _check(str(dead_record.get("stage", "")) == "normal", "Rémanence supplément : un ennemi mort dès sa première rencontre ne doit pas évoluer post-mortem")

func _test_lost_limb_survives_adaptation() -> void:
    RemanenceRuntime.reset_new_game()
    var director: Node = RemanenceCombatBridge.world_director
    if director == null:
        _check(false, "Rémanence supplément : le directeur mondial est requis")
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
    _check(RemanenceRuntime.add_adaptation(entity_id, "guard_old_wound"), "Rémanence supplément : l'ennemi vétéran doit pouvoir apprendre à protéger son ancienne plaie")
    var returned := {"id": 8, "species_id": "traque_suie", "name": "Ancien mutilé revenu", "hp": 20, "max_hp": 20}
    director.call("apply_entity_memory_to_enemy", returned, entity_id)
    _check((returned.get("dismembered_parts", []) as Array).has("arm_right"), "Rémanence supplément : une adaptation ne doit jamais recréer un membre perdu")
    _check(str((returned.get("anatomy_part_states", {}) as Dictionary).get("arm_right", "")) == "lost", "Rémanence supplément : l'état anatomique perdu doit survivre à l'adaptation")
    _check(str(returned.get("protected_anatomy_part", "")) == "arm_right", "Rémanence supplément : l'adaptation peut protéger la plaie restante sans annuler la mutilation")

func _test_autosave_backup_recovery() -> void:
    SaveManager.delete_slot(SaveManager.AUTOSAVE_SLOT)
    GameState.gold = 444
    _check(SaveManager.autosave("prepc_a"), "Sauvegarde supplément : la première autosauvegarde doit réussir")
    GameState.gold = 555
    _check(SaveManager.autosave("prepc_b"), "Sauvegarde supplément : la seconde autosauvegarde doit créer un état courant et un secours")
    var autosave_path := "user://litd_autosave.json"
    var corrupt := FileAccess.open(autosave_path, FileAccess.WRITE)
    _check(corrupt != null, "Sauvegarde supplément : le test doit pouvoir simuler une interruption/corruption")
    if corrupt != null:
        corrupt.store_string("{corrupted_autosave")
        corrupt.flush()
        corrupt.close()
    GameState.gold = 1
    _check(SaveManager.load_game(SaveManager.AUTOSAVE_SLOT), "Sauvegarde supplément : une autosauvegarde corrompue doit pouvoir reprendre depuis le secours cohérent")
    _check(GameState.gold == 444, "Sauvegarde supplément : la reprise doit restaurer l'état valide précédent")
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
