extends Node

const DOCTRINE_SCRIPT := preload("res://scripts/core/veilleurs_enemy_doctrine_runtime.gd")
const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v08.gd")
const AUTHORED_SCRIPT := preload("res://scripts/core/veilleurs_authored_encounter_runtime_v08.gd")
const SLICE_SCRIPT := preload("res://scripts/core/veilleurs_vertical_slice_runtime_v08.gd")

const DUNGEONS: Array[String] = [
    "DUNGEON_KHAR_SEN",
    "DUNGEON_SEUIL_ERODE",
    "DUNGEON_CLOITRE_VOIX",
    "DUNGEON_JARDIN_MUES",
    "DUNGEON_TRIBUNAL_CENDRES",
    "DUNGEON_ARCHIVES_AVEUGLES"
]

const BOSSES: Array[String] = [
    "ENT_BOSS_GARDIEN_SEUIL",
    "ENT_BOSS_CHOEUR_FENDU",
    "ENT_BOSS_MERE_MUES",
    "ENT_BOSS_JUGE_SANS_VISAGE",
    "ENT_BOSS_ARCHIVISTE_AVEUGLE"
]

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    RemanenceRuntime.reset_new_game()
    _test_doctrines_and_real_skills()
    _test_duplicate_authored_instances()
    _test_remanence_promotion()
    _test_boss_mechanics()
    _test_six_dungeon_flow()
    _finish()

func _test_doctrines_and_real_skills() -> void:
    var doctrine: VeilleursEnemyDoctrineRuntime = DOCTRINE_SCRIPT.new() as VeilleursEnemyDoctrineRuntime
    _check(doctrine.load_errors.is_empty(), "24-enemy doctrine data loads")
    _check(str(doctrine.doctrine("ENT_ENEMY_GOULE_AFFAMEE").get("doctrine", "")) == "predator", "Hungry Ghoul exposes predator doctrine")
    _check(str(doctrine.doctrine("ENT_ENEMY_CHIRURGIEN_NOIR").get("doctrine", "")) == "cruel_support", "Black Surgeon exposes support doctrine")

    var runtime: VeilleursTacticalCombatRuntimeV08 = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntimeV08
    var setup := runtime.setup_first_combat(["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_TIREUR"], "khar_sen")
    _check(bool(setup.get("ok", false)), "Wave 2 tactical runtime initializes")
    _check(str((runtime.combatants["ENT_ENEMY_GOULE_AFFAMEE"] as Dictionary).get("remanence_id", "")) != "", "enemy receives Remanence identity at combat start")
    _check(runtime.set_enemy_level("ENT_ENEMY_GOULE_AFFAMEE", 50), "test Ghoul reaches full skill unlock")
    _check(runtime.set_enemy_tree("ENT_ENEMY_GOULE_AFFAMEE", "TREE_GOULE_AFFAMEE_ODEUR_SANG"), "test Ghoul selects authored hunter tree")
    _check(runtime.grid.move("ENT_ENEMY_GOULE_AFFAMEE", Vector2i(1, 0)), "Ghoul enters tactical range")
    var nayra: Dictionary = runtime.combatants["ENT_WATCHER_NAYRA"]
    nayra["hp"] = 25
    var nayra_body: VeilleursBodyComponent = nayra.get("body") as VeilleursBodyComponent
    nayra_body.apply_trauma("left_arm", 55)
    runtime.combatants["ENT_WATCHER_NAYRA"] = nayra
    var action := runtime.enemy_step("ENT_ENEMY_GOULE_AFFAMEE")
    _check(bool(action.get("ok", false)), "doctrine enemy produces action")
    _check(bool(action.get("generated_skill", false)), "enemy action resolves through one of the 1,080 real enemy skills")
    _check(str(action.get("skill_id", "")).begins_with("SK_GOULE_AFFAMEE_ODEUR_SANG"), "Ghoul uses skill from its locked personal tree")
    _check(bool(action.get("doctrine_used", false)), "doctrine layer participates in skill selection")

func _test_duplicate_authored_instances() -> void:
    var authored: VeilleursAuthoredEncounterRuntimeV08 = AUTHORED_SCRIPT.new() as VeilleursAuthoredEncounterRuntimeV08
    var encounter := {
        "template_id":"WAVE2_DUPLICATE_GHOULES",
        "objective":"survive",
        "counterplay":"Break the pack",
        "composition":[
            {"definition_id":"ENT_ENEMY_GOULE_AFFAMEE"},
            {"definition_id":"ENT_ENEMY_GOULE_AFFAMEE"}
        ]
    }
    var setup := authored.setup_authored_encounter(encounter, "khar_sen")
    _check(bool(setup.get("ok", false)), "authored Wave 2 encounter launches")
    _check(authored.combatants.has("ENT_ENEMY_GOULE_AFFAMEE#02"), "duplicate enemy receives stable runtime instance ID")
    _check(str((authored.combatants["ENT_ENEMY_GOULE_AFFAMEE"] as Dictionary).get("chosen_tree", "")) != "", "first duplicate keeps a production skill tree")
    _check(str((authored.combatants["ENT_ENEMY_GOULE_AFFAMEE#02"] as Dictionary).get("chosen_tree", "")) != "", "second duplicate keeps the same definition's 45-skill pool")
    _check(str((authored.combatants["ENT_ENEMY_GOULE_AFFAMEE#02"] as Dictionary).get("remanence_id", "")) != str((authored.combatants["ENT_ENEMY_GOULE_AFFAMEE"] as Dictionary).get("remanence_id", "")), "duplicate instances receive distinct Remanence identities")

func _test_remanence_promotion() -> void:
    RemanenceRuntime.reset_new_game()
    var runtime: VeilleursTacticalCombatRuntimeV08 = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntimeV08
    _check(bool(runtime.setup_first_combat(["ENT_ENEMY_ECORCHEUSE"], "khar_sen").get("ok", false)), "Remanence promotion combat starts")
    var row: Dictionary = runtime.combatants["ENT_ENEMY_ECORCHEUSE"]
    var rem_id := str(row.get("remanence_id", ""))
    _check(rem_id != "", "promotion candidate has persistent identity")
    var source := {"remanence_id":rem_id, "id":"ENT_ENEMY_ECORCHEUSE", "species_id":"ENT_ENEMY_ECORCHEUSE", "name":"Écorcheuse"}
    for _i in range(3):
        RemanenceRuntime.note_encounter(source, "khar_sen")
    for _i in range(3):
        RemanenceRuntime.record_event(rem_id, "killed_watcher", {"region_id":"khar_sen"})
    for _i in range(2):
        RemanenceRuntime.record_event(rem_id, "major_mutilation", {"region_id":"khar_sen"})
    runtime.remanence_bridge.refresh_enemy(runtime, "ENT_ENEMY_ECORCHEUSE")
    row = runtime.combatants["ENT_ENEMY_ECORCHEUSE"]
    _check(str(row.get("remanence_stage", "")) == "nemesis", "lived events can promote an enemy to Nemesis without hidden player data")
    _check(RemanenceRuntime.add_adaptation(rem_id, "pressure_wounded"), "Nemesis accepts bounded learned adaptation")
    runtime.remanence_bridge.refresh_enemy(runtime, "ENT_ENEMY_ECORCHEUSE")
    _check(((runtime.combatants["ENT_ENEMY_ECORCHEUSE"] as Dictionary).get("adaptations", []) as Array).has("pressure_wounded"), "learned adaptation re-enters tactical combat")

func _test_boss_mechanics() -> void:
    for boss_id: String in BOSSES:
        var runtime: VeilleursTacticalCombatRuntimeV08 = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntimeV08
        var context := {"region_id":"boss_test", "campaign_flags":["SPARED_MEMORIAL", "LEFT_SURVIVOR", "TOOK_RELIC"], "countermeasure":""}
        var setup := runtime.setup_boss_combat(boss_id, context)
        _check(bool(setup.get("ok", false)), "%s boss combat initializes" % boss_id)
        runtime.next_round()
        _check(not runtime.last_boss_mechanics.is_empty(), "%s applies mechanical rule at round boundary" % boss_id)
        _check(str(runtime.last_boss_mechanics.get("mechanic", "")) != "", "%s boss mechanic is explicit" % boss_id)
        if boss_id == "ENT_BOSS_GARDIEN_SEUIL":
            var locked: Array = runtime.last_boss_rule.get("locked_cells", [])
            _check(not locked.is_empty(), "Gardien locks authored tactical cells")
            if not locked.is_empty():
                var coords: Array = locked[0]
                _check(not runtime.can_move_to(Vector2i(int(coords[0]), int(coords[1]))), "Gardien locked cell is mechanically impassable")

func _test_six_dungeon_flow() -> void:
    for index in range(DUNGEONS.size()):
        var dungeon_id := DUNGEONS[index]
        var slice: VeilleursVerticalSliceRuntimeV08 = SLICE_SCRIPT.new() as VeilleursVerticalSliceRuntimeV08
        var start := slice.start_dungeon(dungeon_id, 80800 + index)
        _check(bool(start.get("ok", false)), "%s starts through generic Wave 2 slice" % dungeon_id)
        _check(_reach_encounter(slice), "%s reaches a materialized encounter" % dungeon_id)
        if slice.campaign.dungeon.active_encounter.is_empty():
            continue
        var launch := slice.launch_current_encounter({"campaign_flags":["SPARED_MEMORIAL"]})
        _check(bool(launch.get("ok", false)), "%s encounter launches into tactical runtime" % dungeon_id)
        if not bool(launch.get("ok", false)):
            continue
        _check(slice.combat != null and (slice.combat.alive_ids("watcher") as Array).size() == 4, "%s tactical encounter contains four canonical Watchers" % dungeon_id)
        if index == 0:
            var payload := slice.serialize()
            var restored: VeilleursVerticalSliceRuntimeV08 = SLICE_SCRIPT.new() as VeilleursVerticalSliceRuntimeV08
            _check(restored.deserialize(payload), "active Khar-Sen Wave 2 combat survives campaign serialization")
            _check(restored.combat != null and restored.combat_node_id != "", "restored vertical slice preserves active combat node")
            var resolution := restored.resolve_active_combat("retreat")
            _check(bool(resolution.get("ok", false)), "retreat returns combat consequences to Khar-Sen campaign runtime")
            var recruit_context := {"knowledge_level":3, "respect":2, "shared_event":1, "fear":0, "condition_flags":_recruit_flags_for_first_enemy(resolution)}
            var recruit := restored.attempt_recruit_from_last(0, recruit_context)
            _check(bool(recruit.get("ok", false)), "living enemy can pass deterministic recruitment after authored conditions")
        else:
            var resolution := slice.resolve_active_combat("retreat")
            _check(bool(resolution.get("ok", false)), "%s returns tactical outcome to dungeon progression" % dungeon_id)

func _reach_encounter(slice: VeilleursVerticalSliceRuntimeV08) -> bool:
    for _i in range(32):
        if not slice.campaign.dungeon.active_encounter.is_empty():
            return true
        var next_nodes := slice.campaign.dungeon.available_next()
        if next_nodes.is_empty():
            return false
        var step := slice.enter_next(str(next_nodes[0]))
        if not bool(step.get("ok", false)):
            return false
    return false

func _recruit_flags_for_first_enemy(resolution: Dictionary) -> Array[String]:
    var enemies: Array = resolution.get("enemy_aftermath", [])
    if enemies.is_empty():
        return []
    var family := str((enemies[0] as Dictionary).get("family", ""))
    match family:
        "GOULES":
            return ["fed_without_exploitation", "wound_treated_or_bleeding_stopped"]
        "PORTE_CENDRES":
            return ["leader_defeated", "guard_broken_then_spared"]
        "ECHOS":
            return ["pattern_varied", "identity_named"]
        "PARASITES":
            return ["host_stabilized", "contamination_contained"]
        "BETES_ALTEREES":
            return ["isolated_without_execution", "territory_respected"]
        "HUMAINS_DEVOYES":
            return ["weapon_lowered_after_advantage", "shared_enemy_event"]
        _:
            return []

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V08_WAVE2_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V08_WAVE2: " + failure)
    print("VEILLEURS_V08_WAVE2_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
