extends Node

const DB_SCRIPT := preload("res://scripts/core/content_db.gd")
const RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime.gd")
const SESSION_SCRIPT := preload("res://scripts/core/veilleurs_tactical_session.gd")
const SAVE_SCRIPT := preload("res://scripts/core/veilleurs_tactical_save_bridge.gd")
const BODY_SCRIPT := preload("res://scripts/core/veilleurs_body_component.gd")
const SKILL_RESOURCE_SCRIPT := preload("res://scripts/core/veilleurs_skill_definition.gd")
const ENTITY_RESOURCE_SCRIPT := preload("res://scripts/core/veilleurs_entity_definition.gd")
const HYBRID_SCRIPT := preload("res://scripts/core/veilleurs_hybrid_generation_bridge.gd")
const REFUGE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_runtime.gd")
const UI_SCENE := preload("res://scenes/veilleurs/v06_tactical_combat.tscn")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    RemanenceRuntime.reset_new_game()

    var db: VeilleursContentDB = DB_SCRIPT.new() as VeilleursContentDB
    db.reload()
    var summary := db.summary()
    _check(summary.get("load_errors", []).is_empty(), "ContentDB v0.6 must load without errors")
    _check(int(summary.get("watchers", 0)) == 4, "ContentDB must expose four Watchers")
    _check(int(summary.get("enemies", 0)) == 24, "ContentDB must expose 24 enemies")
    _check(int(summary.get("skills", 0)) == 180, "ContentDB must expand 180 Watcher skills")
    var grid_contract: Dictionary = summary.get("grid", {}) as Dictionary
    _check(int(grid_contract.get("width", 0)) == 6 and int(grid_contract.get("height", 0)) == 5, "Tactical grid contract must be 6x5")

    var expected_ids := ["ENT_WATCHER_SAHEN", "ENT_WATCHER_MIRA", "ENT_WATCHER_NAREM", "ENT_WATCHER_YSRA"]
    var expected_names := ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"]
    for index in range(expected_ids.size()):
        var watcher := db.watcher(expected_ids[index])
        _check(str(watcher.get("name_fr", "")) == expected_names[index], "Watcher identity mismatch: %s" % expected_ids[index])
        _check(db.skills_for(expected_ids[index]).size() == 45, "%s must own 45 skills" % expected_names[index])
    _check(db.watcher("nayra_orun").is_empty(), "Legacy VS001 identity must not leak into v0.6 ContentDB")

    var sahen_resource: VeilleursEntityDefinition = ENTITY_RESOURCE_SCRIPT.from_dictionary(db.watcher("ENT_WATCHER_SAHEN"))
    _check(sahen_resource.entity_id == "ENT_WATCHER_SAHEN", "EntityDefinition conversion must preserve stable ID")
    var shoulder_resource: VeilleursSkillDefinition = SKILL_RESOURCE_SCRIPT.from_dictionary(db.skill("SK_SAHEN_BRISEUR_LIGNES_01"))
    _check(shoulder_resource.name_fr == "Épaule en avant", "SkillDefinition conversion must preserve authored name")

    var runtime: VeilleursTacticalCombatRuntime = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntime
    var setup := runtime.setup_first_combat()
    _check(bool(setup.get("ok", false)), "First tactical combat must initialize")
    _check(runtime.grid.position_of("ENT_WATCHER_MIRA") == Vector2i(0, 0), "Mira must start at her authored grid cell")
    _check(runtime.grid.position_of("ENT_WATCHER_SAHEN") == Vector2i(0, 1), "Sahen must start at his authored grid cell")
    _check(runtime.grid.position_of("ENT_ENEMY_GOULE_AFFAMEE") == Vector2i(5, 1), "Hungry Ghoul must start opposite the Watchers")

    var sahen_row: Dictionary = runtime.combatants["ENT_WATCHER_SAHEN"]
    sahen_row["hp"] = 30
    var sahen_body: VeilleursBodyComponent = sahen_row.get("body") as VeilleursBodyComponent
    sahen_body.apply_trauma("left_arm", 60)
    runtime.combatants["ENT_WATCHER_SAHEN"] = sahen_row
    var predator_decision := runtime.enemy_ai.decide(runtime, "ENT_ENEMY_GOULE_AFFAMEE")
    _check(str(predator_decision.get("target", "")) == "ENT_WATCHER_SAHEN", "Predator AI must prefer the visibly wounded Watcher when tactically plausible")
    _check(str(predator_decision.get("reason", "")) in ["exploit_wounded_target", "close_distance"], "Predator AI decision must remain readable")

    _check(runtime.grid.move("ENT_WATCHER_SAHEN", Vector2i(1, 1)), "Sahen must be movable on the 6x5 grid")
    _check(runtime.grid.move("ENT_ENEMY_GOULE_AFFAMEE", Vector2i(2, 1)), "Test Ghoul must be movable to contact range")
    var hit := runtime.resolve_skill("ENT_WATCHER_SAHEN", "ENT_ENEMY_GOULE_AFFAMEE", "SK_SAHEN_BRISEUR_LIGNES_01", "torso", 1)
    _check(bool(hit.get("ok", false)) and bool(hit.get("hit", false)), "Sahen's first authored skill must resolve a forced hit")
    _check(int(hit.get("damage", 0)) > 0, "A damaging authored skill must deal damage")
    _check((hit.get("body", {}) as Dictionary).get("state", "") != "", "Hit must update six-zone body state")

    var observe := runtime.resolve_skill("ENT_WATCHER_MIRA", "ENT_ENEMY_ECORCHEUSE", "SK_MIRA_OEIL_VEILLEUR_01", "head", 1)
    _check(bool(observe.get("non_damage", false)), "Mira Observer must resolve as information, not fake damage")
    _check(int(observe.get("knowledge_reveal", 0)) >= 1, "Mira Observer must reveal tactical knowledge")

    var body: VeilleursBodyComponent = BODY_SCRIPT.new({"head":70,"torso":140,"left_arm":90,"right_arm":90,"left_leg":100,"right_leg":100}) as VeilleursBodyComponent
    var sever := body.apply_trauma("left_arm", 95, 4, 3)
    _check(bool(sever.get("severed", false)), "Compatible L5 arm trauma must allow dismemberment")
    _check(not bool(body.functional_flags().get("can_use_two_handed", true)), "Losing one arm must disable two-handed use")
    var body_copy: VeilleursBodyComponent = BODY_SCRIPT.new() as VeilleursBodyComponent
    body_copy.deserialize(body.serialize())
    _check((body_copy.serialize().get("missing_parts", []) as Array).has("left_arm"), "Missing limb must survive serialization")

    var before_enemy := runtime.grid.position_of("ENT_ENEMY_ECORCHEUSE")
    var enemy_action := runtime.enemy_step("ENT_ENEMY_ECORCHEUSE")
    var after_enemy := runtime.grid.position_of("ENT_ENEMY_ECORCHEUSE")
    _check(bool(enemy_action.get("ok", false)), "Enemy AI v2 must produce an action")
    _check(before_enemy != after_enemy or str(enemy_action.get("action", "")) in ["attack", "hold"], "Enemy AI must approach, attack or explicitly hold")

    var support_runtime: VeilleursTacticalCombatRuntime = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntime
    _check(bool(support_runtime.setup_first_combat(["ENT_ENEMY_CHIRURGIEN_NOIR", "ENT_ENEMY_MARAUDEUR", "ENT_ENEMY_TIREUR"]).get("ok", false)), "Support AI test encounter must initialize")
    var marauder: Dictionary = support_runtime.combatants["ENT_ENEMY_MARAUDEUR"]
    marauder["hp"] = 20
    support_runtime.combatants["ENT_ENEMY_MARAUDEUR"] = marauder
    var support_decision := support_runtime.enemy_ai.decide(support_runtime, "ENT_ENEMY_CHIRURGIEN_NOIR")
    _check(str(support_decision.get("target", "")) == "ENT_ENEMY_MARAUDEUR", "Support AI must recognize a critically wounded adjacent ally")
    _check(str(support_decision.get("action", "")) == "support", "Chirurgien noir must choose bounded support when the ally is adjacent and critical")

    var serialized := runtime.serialize()
    var restored: VeilleursTacticalCombatRuntime = RUNTIME_SCRIPT.new() as VeilleursTacticalCombatRuntime
    _check(restored.deserialize(serialized), "Tactical combat must deserialize")
    _check(restored.grid.snapshot() == runtime.grid.snapshot(), "Grid must survive tactical serialization")
    _check(restored.combatants.size() == runtime.combatants.size(), "Combatant roster must survive tactical serialization")

    var hybrid: VeilleursHybridGenerationBridge = HYBRID_SCRIPT.new() as VeilleursHybridGenerationBridge
    _check(hybrid.load_errors.is_empty(), "Hybrid bridge must validate all authored encounter references")
    _check(hybrid.encounter_count() == 64, "Hybrid bridge must expose exactly 64 authored encounters")
    var memorial_template := hybrid.encounter("ENC_V06_049")
    _check(str(memorial_template.get("archetype", "")) == "mixed_memory" and bool(memorial_template.get("memoriel_allowed", false)), "Mixed-memory encounter must reserve a Mémoriel slot")
    var generated_low := hybrid.generate_encounter("GOULES", "LOW", 1, 60601)
    _check(not generated_low.is_empty() and bool(generated_low.get("escape_route_required", false)), "Generated encounter must retain a viable retreat route")
    _check(not str(generated_low.get("counterplay", "")).is_empty(), "Generated encounter must expose authored counterplay")
    var dungeon_plan := hybrid.generate_plan("DUNGEON_ASH_RUINS", 60601)
    _check(not dungeon_plan.is_empty(), "Hybrid generation must produce an authored/procedural dungeon plan")
    _check(int(dungeon_plan.get("room_count", 0)) >= 10 and int(dungeon_plan.get("room_count", 0)) <= 18, "Ash Ruins must respect authored room bounds")
    _check((dungeon_plan.get("rooms", []) as Array).size() == int(dungeon_plan.get("room_count", 0)), "Hybrid plan must materialize every room")

    var refuge: VeilleursRefugeRuntime = REFUGE_SCRIPT.new() as VeilleursRefugeRuntime
    _check(refuge.recruit_slots() == 6, "Refuge must begin with six recruit slots")
    refuge.add_rewards(1000, 100, 0)
    var quarters_upgrade := refuge.upgrade("BUILDING_QUARTERS")
    _check(bool(quarters_upgrade.get("ok", false)) and refuge.recruit_slots() == 8, "Quarters upgrade must increase recruit slots to eight")
    var refuge_copy: VeilleursRefugeRuntime = REFUGE_SCRIPT.new() as VeilleursRefugeRuntime
    refuge_copy.deserialize(refuge.serialize())
    _check(refuge_copy.current_level("BUILDING_QUARTERS") == 2, "Refuge state must survive serialization")

    var ui: VeilleursTacticalUI = UI_SCENE.instantiate() as VeilleursTacticalUI
    add_child(ui)
    ui.bind_snapshot({"runtime":runtime.serialize()})
    _check(ui.touch_contract_ok(), "Touch UI must expose 30 cells, six body zones and four large skill slots")
    _check(ui.cell_buttons.size() == 30, "Touch UI grid must contain exactly 30 cells")

    var session: Node = SESSION_SCRIPT.new()
    add_child(session)
    var session_setup: Dictionary = session.call("start_first_combat")
    _check(bool(session_setup.get("ok", false)), "Tactical session must start first combat")
    var session_snapshot: Dictionary = session.call("serialize")
    var session_copy: Node = SESSION_SCRIPT.new()
    add_child(session_copy)
    session_copy.call("deserialize", session_snapshot)
    _check(bool(session_copy.call("is_active")), "Tactical session must restore as active")
    _check((session_copy.call("snapshot") as Dictionary).get("runtime", {}) != {}, "Restored session must contain runtime state")
    _check(bool(session.call("save_snapshot")), "Tactical session must write a checksum save")
    var disk_copy: Node = SESSION_SCRIPT.new()
    add_child(disk_copy)
    _check(bool(disk_copy.call("load_snapshot")), "Tactical session must reload its checksum save")
    _check(bool(disk_copy.call("delete_snapshot")), "Tactical QA save must be removable")

    var save_bridge: VeilleursTacticalSaveBridge = SAVE_SCRIPT.new() as VeilleursTacticalSaveBridge
    save_bridge.clear()
    _check(save_bridge.save_session(session), "Playable tactical save bridge must atomically save combat plus Remanence")
    var bridge_copy: Node = SESSION_SCRIPT.new()
    add_child(bridge_copy)
    _check(save_bridge.load_into(bridge_copy), "Playable tactical save bridge must restore the active combat")
    _check((bridge_copy.call("snapshot") as Dictionary).get("runtime", {}) != {}, "Bridge-restored session must contain tactical runtime")
    _check(save_bridge.clear(), "Playable tactical save must be removable")

    var finish: Dictionary = session.call("finish", "resolved")
    _check(bool(finish.get("ok", false)), "Finishing combat must succeed")
    _check(RemanenceRuntime.event_timeline.size() >= 6, "First combat must write encounter and resolution events to Remanence")

    ui.queue_free()
    session.queue_free()
    session_copy.queue_free()
    disk_copy.queue_free()
    bridge_copy.queue_free()
    db.free()
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V06_TACTICAL_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V06_TACTICAL_SMOKE: " + failure)
    print("VEILLEURS_V06_TACTICAL_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
