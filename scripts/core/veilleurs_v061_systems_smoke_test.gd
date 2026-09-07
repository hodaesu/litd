extends Node

const RUNTIME_V2_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v2.gd")
const AUTHORED_RUNTIME_SCRIPT := preload("res://scripts/core/veilleurs_authored_encounter_runtime.gd")
const SESSION_V2_SCRIPT := preload("res://scripts/core/veilleurs_tactical_session_v2.gd")
const DUNGEON_SCRIPT := preload("res://scripts/core/veilleurs_dungeon_slice_runtime.gd")
const ENCOUNTER_DIRECTOR_SCRIPT := preload("res://scripts/core/veilleurs_encounter_director.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    RemanenceRuntime.reset_new_game()
    var runtime: VeilleursTacticalCombatRuntimeV2 = RUNTIME_V2_SCRIPT.new() as VeilleursTacticalCombatRuntimeV2
    _check(bool(runtime.setup_first_combat().get("ok", false)), "runtime v2 initializes")
    var coverage := runtime.behavior_coverage()
    _check(int(coverage.get("skills", 0)) == 180 and bool(coverage.get("complete", false)), "all 180 Watcher skills have behavior coverage")
    var actions: Dictionary = coverage.get("actions", {})
    _check(actions.has("attack") and actions.has("guard") and actions.has("observe") and actions.has("psychological") and actions.has("passive_modifier"), "behavior coverage spans authored action families")
    var balance: Dictionary = runtime.content_db.combat_constants.get("v061_balance", {})
    _check(int((runtime.combatants["ENT_ENEMY_GOULE_AFFAMEE"] as Dictionary).get("weapon_power", 0)) == int(balance.get("enemy_weapon_power", 42)), "runtime v2 consumes authored balance reference")

    _check(runtime.grid.move("ENT_WATCHER_SAHEN", Vector2i(1, 1)), "Sahen moves for skill smoke")
    _check(runtime.grid.move("ENT_ENEMY_GOULE_AFFAMEE", Vector2i(2, 1)), "Ghoul moves to Sahen")
    var impact := runtime.resolve_skill("ENT_WATCHER_SAHEN", "ENT_ENEMY_GOULE_AFFAMEE", "SK_SAHEN_BRISEUR_LIGNES_01", "torso", 1)
    _check(bool(impact.get("hit", false)) and str(impact.get("status_applied", "")) == "STAGGER", "impact skill causes real STAGGER")

    var guard := runtime.resolve_skill("ENT_WATCHER_SAHEN", "ENT_WATCHER_SAHEN", "SK_SAHEN_GARDIEN_MARTIAL_01", "torso", 1)
    _check(int(guard.get("guard_delta", 0)) > 0 and int((runtime.combatants["ENT_WATCHER_SAHEN"] as Dictionary).get("guard_bonus", 0)) > 0, "guard skill changes combat state")

    var observe := runtime.resolve_skill("ENT_WATCHER_MIRA", "ENT_ENEMY_ECORCHEUSE", "SK_MIRA_OEIL_VEILLEUR_01", "head", 1)
    _check(int(observe.get("knowledge_reveal", 0)) >= 1 and (runtime.combatants["ENT_ENEMY_ECORCHEUSE"] as Dictionary).has("observed_by"), "observation persists tactical knowledge")

    var psych := runtime.resolve_skill("ENT_WATCHER_YSRA", "ENT_ENEMY_FOUISSEUSE", "SK_YSRA_PAROLE_BRISE_01", "head", 1)
    _check(int(psych.get("resolve_delta", 0)) < 0 and str(psych.get("status_applied", "")) == "DOUBT", "psychological skill pressures resolve")

    var passive := runtime.resolve_skill("ENT_WATCHER_MIRA", "ENT_WATCHER_MIRA", "SK_MIRA_OEIL_VEILLEUR_02", "torso", 1)
    _check((passive.get("passive_effect", {}) as Dictionary).get("profile", "") == "observe", "passive skill exposes a mechanical payload")

    var enemy_row: Dictionary = runtime.combatants["ENT_ENEMY_ECORCHEUSE"]
    enemy_row["remanence_stage"] = "veteran"
    enemy_row["adaptations"] = ["pressure_wounded"]
    runtime.combatants["ENT_ENEMY_ECORCHEUSE"] = enemy_row
    var sahen_row: Dictionary = runtime.combatants["ENT_WATCHER_SAHEN"]
    sahen_row["hp"] = 20
    runtime.combatants["ENT_WATCHER_SAHEN"] = sahen_row
    var ai_decision: Dictionary = runtime.enemy_ai.decide(runtime, "ENT_ENEMY_ECORCHEUSE")
    _check(str(ai_decision.get("target", "")) == "ENT_WATCHER_SAHEN" and bool(ai_decision.get("memory_used", false)), "AI v3 uses veteran memory against wounded Watcher")
    _check(str(ai_decision.get("zone", "")) in ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"], "AI v3 selects a body zone")

    runtime.next_round()
    _check(not ((runtime.combatants["ENT_WATCHER_SAHEN"] as Dictionary).get("statuses", {}) as Dictionary).has("GUARDED"), "round decay removes one-turn guard state")

    var encounter_director: VeilleursEncounterDirector = ENCOUNTER_DIRECTOR_SCRIPT.new() as VeilleursEncounterDirector
    var encounter := encounter_director.next_encounter("GOULES", "LOW", 1, 76101)
    _check(not encounter.is_empty() and str(encounter.get("template_id", "")) != "", "encounter director materializes authored encounter")
    _check(encounter_director.serialize().get("recent_templates", []).size() == 1, "encounter director keeps bounded recent history")

    var authored: VeilleursAuthoredEncounterRuntime = AUTHORED_RUNTIME_SCRIPT.new() as VeilleursAuthoredEncounterRuntime
    var authored_setup := authored.setup_authored_encounter(encounter)
    _check(bool(authored_setup.get("ok", false)), "authored encounter composition launches on tactical grid")
    _check((authored_setup.get("enemies", []) as Array).size() == (encounter.get("composition", []) as Array).size(), "every authored encounter member receives a runtime combatant")
    _check(authored.alive_ids("enemy").size() == (encounter.get("composition", []) as Array).size(), "authored encounter starts with full living enemy roster")

    var rem_session: VeilleursTacticalSessionV2 = SESSION_V2_SCRIPT.new() as VeilleursTacticalSessionV2
    add_child(rem_session)
    _check(bool(rem_session.start_first_combat().get("ok", false)), "v0.6.1 Remanence session initializes")
    var tracked_enemy: Dictionary = rem_session.runtime.combatants["ENT_ENEMY_GOULE_AFFAMEE"]
    var tracked_id := str(tracked_enemy.get("remanence_id", ""))
    _check(tracked_id != "", "enemy receives persistent Remanence identity at encounter start")
    var before_score := int(RemanenceRuntime.entity_state(tracked_id).get("score", 0))
    rem_session.finish("retreat")
    var after_state := RemanenceRuntime.entity_state(tracked_id)
    _check(int(after_state.get("score", 0)) >= before_score + 2, "forced retreat writes weighted Remanence progression")
    rem_session.queue_free()

    var dungeon: VeilleursDungeonSliceRuntime = DUNGEON_SCRIPT.new() as VeilleursDungeonSliceRuntime
    _check(dungeon.load_errors.is_empty(), "Khar-Sen slice validates")
    var start := dungeon.start()
    _check(bool(start.get("ok", false)) and str((start.get("node", {}) as Dictionary).get("node_id", "")) == "KHAR_01", "Khar-Sen starts at authored entry")
    _check(bool(dungeon.choose_next("KHAR_02").get("ok", false)), "Khar-Sen enters first combat street")
    _check(not dungeon.active_encounter.is_empty(), "combat node receives one of the 64 authored encounters")
    dungeon.complete_current("victory")
    _check(bool(dungeon.choose_next("KHAR_04").get("ok", false)), "branch can take corpse-field route")
    dungeon.complete_current("victory_with_mutilation")
    _check(RemanenceRuntime.world_scars.size() >= 1, "costly victory creates persistent world scar")
    _check(bool(dungeon.choose_next("KHAR_05").get("ok", false)), "slice reaches memory node")
    dungeon.complete_current("cleared")
    _check(bool(dungeon.choose_next("KHAR_06").get("ok", false)), "slice reaches authored route choice")
    _check(bool(dungeon.choose_next("KHAR_08").get("ok", false)), "slice supports non-combat branch")
    dungeon.complete_current("cleared")
    _check(bool(dungeon.choose_next("KHAR_09").get("ok", false)), "slice reaches objective")
    dungeon.complete_current("victory")
    _check(bool(dungeon.progress_summary().get("objective_reached", false)), "Khar-Sen objective is reachable")
    var dungeon_copy: VeilleursDungeonSliceRuntime = DUNGEON_SCRIPT.new() as VeilleursDungeonSliceRuntime
    _check(dungeon_copy.deserialize(dungeon.serialize()), "Khar-Sen slice state serializes")
    _check(str(dungeon_copy.progress_summary().get("current_node", "")) == "KHAR_09", "restored slice preserves current node")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V061_SYSTEMS_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V061_SYSTEMS: " + failure)
    print("VEILLEURS_V061_SYSTEMS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
