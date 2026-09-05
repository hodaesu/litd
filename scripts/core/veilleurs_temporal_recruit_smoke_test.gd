extends Node

const ScarAging := preload("res://scripts/core/veilleurs_scar_aging_runtime.gd")
const CorpseState := preload("res://scripts/core/corpse_state_runtime.gd")
const MemorialRecruit := preload("res://scripts/core/veilleurs_memorial_recruit_runtime.gd")
const VeilleursCapture := preload("res://scripts/core/veilleurs_capture_runtime.gd")

const REGION_ID := "act_i"
const ZONE_ID := "first_veil_crypts"
const RELIC_ID := "relic:nayra_serment_001"

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    _test_temporal_aging()
    await get_tree().process_frame
    _test_former_nemesis_recruitment()
    _finish()

func _test_temporal_aging() -> void:
    GameState.reset_new_game()
    RemanenceRuntime.reset_new_game()
    var world_director: Node = RemanenceCombatBridge.world_director
    _check(world_director != null, "Vieillissement : le directeur mondial doit être disponible")
    if world_director == null:
        return

    var watcher := {
        "id":"nayra_orun",
        "name":"Nayra Orun",
        "hp":0,
        "max_hp":100,
        "persistent_injuries":[{"id":"fatal_thoracic_wound","severity":"critical"}],
        "body_state":{"thorax":"fatal"},
        "dismembered_parts":[]
    }
    var watcher_corpse_id := str(world_director.call("create_corpse_scar", watcher, false, {
        "region_id": REGION_ID,
        "zone_id": ZONE_ID,
        "combat_id":"aging_watcher_death"
    }))
    var enemy_corpse_id := RemanenceRuntime.create_world_scar("accord.pillars.center", "persistent_corpse", "local", {
        "region_id":REGION_ID,
        "zone_id":ZONE_ID,
        "owner_kind":"enemy",
        "owner_id":"mem:aging_enemy:000001",
        "owner_name":"Goule oubliée",
        "body_snapshot":{"persistent_injuries":[],"body_state":{},"dismembered_parts":[]}
    })
    var blood_id := RemanenceRuntime.create_world_scar("accord.gallery.memorial_floor", "old_blood", "trace", {
        "region_id":REGION_ID,
        "zone_id":ZONE_ID,
        "summary":"Une mare de sang marque encore le sol."
    })
    var burn_id := RemanenceRuntime.create_world_scar("accord.pillars.center", "burned_area", "local", {
        "region_id":REGION_ID,
        "zone_id":ZONE_ID,
        "summary":"La pierre a noirci sous le feu."
    })
    var object_id := RemanenceRuntime.create_world_scar("e2e.nayra.relic", "major_item_removed", "regional", {
        "region_id":REGION_ID,
        "zone_id":ZONE_ID,
        "object_id":RELIC_ID,
        "summary":"La relique de Nayra a quitté le lieu de sa mort."
    })

    _check(watcher_corpse_id != "" and enemy_corpse_id != "", "Vieillissement : les deux corps doivent posséder une trace persistante")
    _check(str(ScarAging.presentation_for_scar(RemanenceRuntime.world_scars.get(blood_id, {})).get("representation", "")) == "wet_blood", "Vieillissement : le sang doit commencer frais")
    _check(str(ScarAging.presentation_for_scar(RemanenceRuntime.world_scars.get(burn_id, {})).get("representation", "")) == "fresh_burn", "Vieillissement : la brûlure doit commencer récente")
    _check(str(CorpseState.reconstruct(enemy_corpse_id).get("representation", "")) == "fresh_body", "Vieillissement : un cadavre récent doit réutiliser son corps")

    RemanenceRuntime.advance_expedition_cycle()
    RemanenceRuntime.advance_expedition_cycle()
    _check(RemanenceRuntime.run_index == 2, "Vieillissement : deux expéditions doivent mener au seuil weathered")
    _check(str(RemanenceRuntime.world_scars.get(blood_id, {}).get("age_stage", "")) == "weathered", "Vieillissement : le sang doit être weathered après deux expéditions")
    _check(str(ScarAging.presentation_for_scar(RemanenceRuntime.world_scars.get(blood_id, {})).get("representation", "")) == "darkened_blood", "Vieillissement : le sang doit noircir")
    _check(str(ScarAging.presentation_for_scar(RemanenceRuntime.world_scars.get(burn_id, {})).get("representation", "")) == "weathered_soot", "Vieillissement : la brûlure doit devenir une suie vieillie")
    _check(str(CorpseState.reconstruct(enemy_corpse_id).get("representation", "")) == "decomposed_body", "Vieillissement : le corps doit entrer en décomposition")

    var visit_one: Dictionary = world_director.call("visit_scar", watcher_corpse_id)
    var visit_two: Dictionary = world_director.call("visit_scar", watcher_corpse_id)
    _check(bool(visit_one.get("ok", false)) and bool(visit_two.get("ok", false)), "Vieillissement : le corps du Veilleur doit pouvoir être revisité")
    _check(bool(visit_two.get("great_remanence", false)), "Vieillissement : deux visites après deux expéditions doivent permettre une Grande Rémanence")

    for _index in range(3):
        RemanenceRuntime.advance_expedition_cycle()
    _check(RemanenceRuntime.run_index == 5, "Vieillissement : cinq expéditions doivent mener au stade remnant")
    var skeletal := CorpseState.reconstruct(enemy_corpse_id)
    _check(str(skeletal.get("representation", "")) == "skeletal_remains", "Vieillissement : un corps ordinaire doit devenir des ossements à cinq expéditions")
    _check(bool(skeletal.get("use_proxy_model", false)), "Vieillissement : les ossements doivent utiliser un proxy sans resimuler le ragdoll")
    _check(not CorpseState.can_absorb(enemy_corpse_id) and not CorpseState.can_reanimate(enemy_corpse_id), "Vieillissement : des ossements ne doivent plus être assimilables ou réanimables comme un corps frais")
    var watcher_grave := CorpseState.reconstruct(watcher_corpse_id)
    _check(str(watcher_grave.get("representation", "")) == "memorial_grave", "Vieillissement : une Grande Rémanence de Veilleur doit pouvoir devenir une tombe mémorielle")
    _check(str(ScarAging.presentation_for_scar(RemanenceRuntime.world_scars.get(blood_id, {})).get("representation", "")) == "dry_stain", "Vieillissement : le sang doit devenir une tache sèche")
    _check(str(ScarAging.presentation_for_scar(RemanenceRuntime.world_scars.get(burn_id, {})).get("representation", "")) == "fire_scar", "Vieillissement : la brûlure doit devenir une cicatrice du feu")

    var moved := ScarAging.relocate_persistent_object(object_id, "accord.vault.cache", {
        "room_id":"vault",
        "carrier_id":"mem:former_nemesis",
        "reason":"carried_away"
    })
    _check(moved, "Vieillissement : une relique persistante doit pouvoir changer de lieu sans perdre son identité")
    var moved_payload: Dictionary = RemanenceRuntime.world_scars.get(object_id, {}).get("payload", {})
    _check(str(moved_payload.get("object_location_anchor", "")) == "accord.vault.cache", "Vieillissement : la nouvelle ancre de la relique doit être mémorisée")
    _check(bool(RemanenceRuntime.world_scars.get(object_id, {}).get("protected", false)), "Vieillissement : une relique déplacée doit être protégée de la compression ordinaire")

    for _index in range(5):
        RemanenceRuntime.advance_expedition_cycle()
    _check(RemanenceRuntime.run_index == 10, "Vieillissement : dix expéditions doivent atteindre le seuil d'archive")
    _check(not RemanenceRuntime.world_scars.has(enemy_corpse_id), "Vieillissement : un cadavre ordinaire non protégé doit être compressé en trace après dix expéditions")
    _check(not RemanenceRuntime.world_scars.has(blood_id), "Vieillissement : le sang ancien doit finir par disparaître de la scène active")
    _check(not RemanenceRuntime.world_scars.has(burn_id), "Vieillissement : une brûlure locale ordinaire doit pouvoir devenir une trace archivée")
    _check(RemanenceRuntime.world_scars.has(watcher_corpse_id), "Vieillissement : une Grande Rémanence de Veilleur protégée doit survivre au seuil d'archive")
    _check(str(CorpseState.reconstruct(watcher_corpse_id).get("representation", "")) == "memorial_grave", "Vieillissement : la tombe mémorielle doit rester reconstructible à long terme")
    _check(RemanenceRuntime.world_scars.has(object_id), "Vieillissement : la trace d'une relique déplacée doit survivre tant que son histoire n'est pas résolue")
    _check(_archived_type_exists("old_blood") and _archived_type_exists("burned_area") and _archived_type_exists("persistent_corpse"), "Vieillissement : les traces comprimées doivent rester présentes dans l'archive")

func _test_former_nemesis_recruitment() -> void:
    SaveManager.delete_qa_snapshot()
    GameState.reset_new_game()
    RemanenceRuntime.reset_new_game()
    CreatureManager.reset_new_game(26090524)
    ContentScopeDirector.grant_capability("capture")
    GameState.essence = 100
    GameState.party = _watchers()

    var enemy := {
        "id":1,
        "species_id":"hungry_ghoul",
        "name":"La Gueule Fendue",
        "hp":1,
        "max_hp":24,
        "damage":[2,4],
        "captured":false,
        "persistent_injuries":[{"id":"fracture_forearm","severity":"critical","functional_effect":"grip_impaired"}],
        "body_state":{"left_arm":"fractured"},
        "dismembered_parts":[]
    }
    var entity_id := _promote_to_nemesis(enemy)
    _check(entity_id != "", "Ancien Némésis : l'ennemi doit posséder une identité persistante")
    _check(str(RemanenceRuntime.entity_state(entity_id).get("stage", "")) == "nemesis", "Ancien Némésis : l'ennemi doit être un vrai Némésis avant le recrutement")
    RemanenceRuntime.sync_body_snapshot(enemy)

    var result := VeilleursCapture.attempt(enemy, 1)
    _check(bool(result.get("success", false)), "Ancien Némésis : la capture contrôlée doit réussir")
    _check(bool(result.get("memory_preserved", false)), "Ancien Némésis : le recrutement doit préserver explicitement sa Rémanence")
    _check(str(result.get("historical_stage", "")) == "nemesis", "Ancien Némésis : son stade hostile historique doit rester Némésis")
    _check(str(result.get("allied_status", "")) == "former_nemesis", "Ancien Némésis : son nouveau statut doit être ancien Némésis")
    _check(CreatureManager.captured_creatures.size() == 1, "Ancien Némésis : la recrue doit rester un auxiliaire unique")

    var creature: Dictionary = CreatureManager.captured_creatures[0]
    _check(str(creature.get("source_remanence_id", "")) == entity_id, "Ancien Némésis : l'auxiliaire doit conserver exactement le même ID mémoriel")
    _check(bool(creature.get("former_nemesis", false)), "Ancien Némésis : le titre historique doit être conservé sur la recrue")
    _check(_has_injury(creature, "fracture_forearm"), "Ancien Némésis : la fracture acquise comme ennemi doit survivre au recrutement")
    _check((creature.get("killed_watcher_ids", []) as Array).has("nayra_orun"), "Ancien Némésis : la mort de Nayra ne doit pas être effacée par le recrutement")
    var tarek_relation: Dictionary = (creature.get("remanence_relationships", {}) as Dictionary).get("tarek_senn", {})
    _check(int(tarek_relation.get("resentment", 0)) > 0, "Ancien Némésis : Tarek doit conserver du ressentiment lié à la mort de Nayra")
    _check(int(tarek_relation.get("trust", 99)) == 0, "Ancien Némésis : le recrutement ne doit pas créer artificiellement de confiance")

    var remanence_record := RemanenceRuntime.entity_state(entity_id)
    _check(str(remanence_record.get("status", "")) == "recruited", "Ancien Némésis : l'individu doit sortir du pool hostile")
    _check(str(remanence_record.get("stage", "")) == "former_nemesis", "Ancien Némésis : le runtime doit distinguer l'ancien Némésis du Némésis hostile")
    _check(str(remanence_record.get("historical_stage", "")) == "nemesis", "Ancien Némésis : l'historique hostile doit rester consultable")

    var family_reaction := MemorialRecruit.family_reaction(creature, {
        "species_id":"hungry_ghoul",
        "name":"Goule affamée de sa meute"
    })
    _check(bool(family_reaction.get("applies", false)), "Ancien Némésis : revenir parmi sa propre espèce doit produire une réaction")
    _check(bool(family_reaction.get("telegraphed", false)), "Ancien Némésis : la réaction de sa famille doit être lisible avant ses conséquences")
    _check(str(family_reaction.get("reaction", "")) == "recognition_shock", "Ancien Némésis : son ancienne espèce doit reconnaître un ancien Némésis")
    _check(not bool(family_reaction.get("betrayal", true)) and not bool(family_reaction.get("random_betrayal_allowed", true)), "Ancien Némésis : aucune trahison aléatoire injuste ne doit être possible")
    _check(bool(family_reaction.get("ally_keeps_player_control", false)), "Ancien Némésis : le joueur doit garder le contrôle de l'allié malgré l'hésitation narrative")

    _check(SaveManager.save_qa_snapshot(), "Ancien Némésis : la sauvegarde doit accepter toute son histoire alliée")
    GameState.reset_new_game()
    await get_tree().process_frame
    await get_tree().process_frame
    _check(SaveManager.load_qa_snapshot(), "Ancien Némésis : le snapshot doit se recharger")
    var loaded := CreatureManager.get_creature(str(creature.get("instance_id", "")))
    _check(not loaded.is_empty() and bool(loaded.get("former_nemesis", false)), "Ancien Némésis : son statut doit survivre au rechargement")
    _check(_has_injury(loaded, "fracture_forearm"), "Ancien Némésis : ses blessures doivent survivre au rechargement")
    _check(str(RemanenceRuntime.entity_state(entity_id).get("status", "")) == "recruited", "Ancien Némésis : son identité alliée doit survivre au rechargement")

    var world_director: Node = RemanenceCombatBridge.world_director
    var death_scar := MemorialRecruit.create_memorial_death_scar(loaded, world_director, {
        "region_id":REGION_ID,
        "zone_id":ZONE_ID,
        "combat_id":"former_nemesis_falls"
    })
    _check(death_scar != "", "Ancien Némésis : sa mort comme allié doit créer un cadavre mémoriel prioritaire")
    if death_scar != "":
        var scar: Dictionary = RemanenceRuntime.world_scars.get(death_scar, {})
        var payload: Dictionary = scar.get("payload", {})
        _check(bool(scar.get("protected", false)) and str(scar.get("severity", "")) == "historical", "Ancien Némésis : le cadavre d'un ancien Némésis allié doit être historique et protégé")
        _check(bool(payload.get("former_ally", false)) and bool(payload.get("former_nemesis", false)), "Ancien Némésis : le cadavre doit raconter les deux vies de l'individu")
    SaveManager.delete_qa_snapshot()

func _promote_to_nemesis(enemy: Dictionary) -> String:
    for encounter_index in range(4):
        RemanenceRuntime.note_encounter(enemy, REGION_ID, {
            "zone_id":ZONE_ID,
            "combat_id":"former_nemesis_%d" % encounter_index,
            "summary":"Rencontre persistante avec La Gueule Fendue."
        })
    var entity_id := str(enemy.get("remanence_id", ""))
    RemanenceRuntime.record_event(entity_id, "survived_combat", {"region_id":REGION_ID,"zone_id":ZONE_ID})
    RemanenceRuntime.record_event(entity_id, "major_mutilation", {"region_id":REGION_ID,"zone_id":ZONE_ID,"object_id":"forearm"})
    RemanenceRuntime.record_event(entity_id, "capture_escaped", {"region_id":REGION_ID,"zone_id":ZONE_ID})
    RemanenceRuntime.record_event(entity_id, "forced_retreat", {"region_id":REGION_ID,"zone_id":ZONE_ID})
    RemanenceRuntime.record_event(entity_id, "killed_watcher", {"region_id":REGION_ID,"zone_id":ZONE_ID,"hero_id":"nayra_orun","summary":"La Gueule Fendue abat Nayra Orun."})
    RemanenceRuntime.record_event(entity_id, "relic_taken", {"region_id":REGION_ID,"zone_id":ZONE_ID,"hero_id":"nayra_orun","object_id":RELIC_ID})
    RemanenceRuntime.record_event(entity_id, "great_remanence", {"region_id":REGION_ID,"zone_id":ZONE_ID})
    return entity_id

func _watchers() -> Array[Dictionary]:
    return [
        {"id":"nayra_orun","name":"Nayra Orun","hp":0,"max_hp":100,"relationships":{}},
        {"id":"tarek_senn","name":"Tarek Senn","hp":100,"max_hp":100,"relationships":{"nayra_orun":{"trust":80,"admiration":60,"mistrust":0,"resentment":0}}},
        {"id":"aisha_maren","name":"Aïsha Maren","hp":100,"max_hp":100,"relationships":{"nayra_orun":{"trust":45,"admiration":30,"mistrust":0,"resentment":0}}},
        {"id":"idris_vael","name":"Idris Vael","hp":100,"max_hp":100,"relationships":{"nayra_orun":{"trust":25,"admiration":20,"mistrust":0,"resentment":0}}}
    ]

func _archived_type_exists(scar_type: String) -> bool:
    for value: Variant in RemanenceRuntime.archived_scars:
        if value is Dictionary and str((value as Dictionary).get("type", "")) == scar_type:
            return true
    return false

func _has_injury(character: Dictionary, injury_id: String) -> bool:
    for value: Variant in character.get("persistent_injuries", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == injury_id:
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    GameState.battle_enemies = []
    SaveManager.delete_qa_snapshot()
    if failures.is_empty():
        print("VEILLEURS_TEMPORAL_RECRUIT_SMOKE_OK aging_2_5_10=true former_nemesis=true family_memory=true death_memory=true")
        get_tree().quit(0)
        return
    for failure: String in failures.slice(0, mini(80, failures.size())):
        push_error("VEILLEURS_TEMPORAL_RECRUIT_SMOKE: " + failure)
    print("VEILLEURS_TEMPORAL_RECRUIT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)