extends Node

const SESSION_SCRIPT := preload("res://scripts/core/veilleurs_tactical_session_v062.gd")
const DUNGEON_SCRIPT := preload("res://scripts/core/veilleurs_dungeon_slice_runtime_v062.gd")
const ULTIMATE_STATE_SCRIPT := preload("res://scripts/core/veilleurs_ultimate_state_runtime.gd")
const AISHA_ID := "ENT_WATCHER_AISHA"
const TARGET_ID := "ENT_ENEMY_GOULE_AFFAMEE"
const SAVE_PATH := "user://veilleurs_v062_hemocorde_smoke.json"

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    RemanenceRuntime.reset_new_game()
    var state_runtime: VeilleursUltimateStateRuntime = ULTIMATE_STATE_SCRIPT.new() as VeilleursUltimateStateRuntime
    _check(state_runtime.charges_for_level(15) == 0, "ultimate locked before level 16")
    _check(state_runtime.charges_for_level(16) == 1, "level 16 grants one charge")
    _check(state_runtime.charges_for_level(32) == 2, "level 32 grants two charges")
    _check(state_runtime.charges_for_level(48) == 3, "level 48 grants three charges")

    var invalid_session: VeilleursTacticalSessionV062 = SESSION_SCRIPT.new() as VeilleursTacticalSessionV062
    add_child(invalid_session)
    _check(bool(invalid_session.start_first_combat().get("ok", false)), "invalid-prerequisite session starts")
    _check(bool(invalid_session.configure_watcher_progression(AISHA_ID, 16, "hemocorde", true).get("ok", false)), "Aisha Hemocorde progression configures")
    _move_aisha_to_contact(invalid_session.runtime, TARGET_ID)
    _check(bool(invalid_session.note_vascular_knowledge(TARGET_ID, "torso", 3).get("ok", false)), "vascular knowledge can be recorded")
    var invalid_result := invalid_session.resolve_ultimate(AISHA_ID, TARGET_ID, "hemocorde")
    _check(not bool(invalid_result.get("ok", false)) and str(invalid_result.get("reason", "")) == "target_not_compromised_enough", "ultimate refuses an insufficiently compromised target")
    var invalid_aisha: Dictionary = invalid_session.runtime.combatants[AISHA_ID]
    var invalid_state: Dictionary = invalid_aisha.get("ultimate_state", {})
    _check(int((invalid_state.get("charges", {}) as Dictionary).get("hemocorde", 0)) == 1, "failed activation does not consume charge")
    invalid_session.queue_free()

    var session: VeilleursTacticalSessionV062 = SESSION_SCRIPT.new() as VeilleursTacticalSessionV062
    add_child(session)
    _check(bool(session.start_first_combat().get("ok", false)), "v0.6.2 tactical session starts")
    _check(bool(session.configure_watcher_progression(AISHA_ID, 32, "hemocorde", true).get("ok", false)), "level 32 Hemocorde configures with two charges")
    _check(_move_aisha_for_observation(session.runtime, TARGET_ID), "Aisha reaches observation range")
    var observe := session.resolve_skill(AISHA_ID, TARGET_ID, "AÏ-HÉM-06", "torso", 1)
    _check(bool(observe.get("ok", false)), "Ligne vasculaire resolves through canonical skill runtime")
    var observed_target: Dictionary = session.runtime.combatants[TARGET_ID]
    _check(int((observed_target.get("vascular_known_zones", {}) as Dictionary).get("torso", 0)) >= 2, "Ligne vasculaire creates real vascular knowledge")
    _check(_move_aisha_to_contact(session.runtime, TARGET_ID), "Aisha reaches Hemocorde contact range")
    _compromise_target(session, TARGET_ID, 0.30)
    var ready := session.ultimate_status(AISHA_ID, TARGET_ID, "hemocorde")
    _check(bool(ready.get("available", false)) and int(ready.get("charges_remaining", 0)) == 2, "Le Dernier Battement becomes available only on compromised known physiology")

    var first := session.resolve_ultimate(AISHA_ID, TARGET_ID, "hemocorde")
    _check(bool(first.get("ok", false)), "Le Dernier Battement resolves")
    _check(str(first.get("ultimate_name", "")) == "Le Dernier Battement", "ultimate identity remains canonical")
    _check(str(first.get("commit_state", "")) == "ULTIMATE_RESOLVE", "charge commits at authoritative resolve state")
    _check(bool(first.get("circulatory_collapse", false)), "ultimate creates circulatory collapse")
    _check(int(first.get("charges_remaining", -1)) == 1, "first resolution consumes exactly one level-32 charge")
    _check((first.get("presentation", {}) as Dictionary).get("signature", "") == "silence_then_heartbeat", "resolver exposes presentation contract without using it for mechanics")

    var same_encounter := session.ultimate_status(AISHA_ID, TARGET_ID, "hemocorde")
    _check(not bool(same_encounter.get("available", false)) and str(same_encounter.get("reason", "")) == "ultimate_already_used_this_encounter", "same ultimate cannot be used twice in one encounter while a charge remains")

    _check(session.save_snapshot(SAVE_PATH), "v0.6.2 active combat snapshot saves")
    var restored: VeilleursTacticalSessionV062 = SESSION_SCRIPT.new() as VeilleursTacticalSessionV062
    add_child(restored)
    _check(restored.load_snapshot(SAVE_PATH), "v0.6.2 active combat snapshot restores")
    var restored_aisha: Dictionary = restored.runtime.combatants[AISHA_ID]
    var restored_state: Dictionary = restored_aisha.get("ultimate_state", {})
    _check(int((restored_state.get("charges", {}) as Dictionary).get("hemocorde", 0)) == 1, "ultimate charge survives save/load")
    _check(bool((restored_state.get("encounters_used", {}) as Dictionary).get("hemocorde@veilleurs_v062_first_combat", false)), "encounter usage survives save/load")

    var aftermath := restored.watcher_aftermath()
    var dungeon: VeilleursDungeonSliceRuntimeV062 = DUNGEON_SCRIPT.new() as VeilleursDungeonSliceRuntimeV062
    _check(bool(dungeon.start().get("ok", false)), "Khar-Sen v0.6.2 state starts")
    var persist_result := dungeon.complete_current("cleared", {"watcher_aftermath": aftermath})
    _check(bool(persist_result.get("ok", false)) and int(persist_result.get("watcher_state_persisted", 0)) == 4, "Khar-Sen captures four-Watcher aftermath including ultimate state")
    var dungeon_copy: VeilleursDungeonSliceRuntimeV062 = DUNGEON_SCRIPT.new() as VeilleursDungeonSliceRuntimeV062
    _check(dungeon_copy.deserialize(dungeon.serialize()), "Khar-Sen v0.6.2 serializes Watcher state")
    var persisted_aisha: Dictionary = dungeon_copy.watcher_state.get(AISHA_ID, {})
    _check(int(((persisted_aisha.get("ultimate_state", {}) as Dictionary).get("charges", {}) as Dictionary).get("hemocorde", 0)) == 1, "remaining dungeon charge survives Khar-Sen serialization")

    var next_session: VeilleursTacticalSessionV062 = SESSION_SCRIPT.new() as VeilleursTacticalSessionV062
    add_child(next_session)
    var second_encounter := _single_ghoul_encounter("SMOKE_HEMOCORDE_02")
    _check(bool(next_session.start_authored_encounter(second_encounter, "khar_sen:SMOKE_HEMOCORDE_02", "khar_sen", dungeon_copy.watcher_state).get("ok", false)), "second authored encounter restores Watcher expedition state")
    _check(_move_aisha_to_contact(next_session.runtime, TARGET_ID), "Aisha reaches contact in second encounter")
    _check(bool(next_session.note_vascular_knowledge(TARGET_ID, "torso", 3).get("ok", false)), "second encounter records new target knowledge")
    _compromise_target(next_session, TARGET_ID, 0.30)
    var second_ready := next_session.ultimate_status(AISHA_ID, TARGET_ID, "hemocorde")
    _check(bool(second_ready.get("available", false)) and int(second_ready.get("charges_remaining", 0)) == 1, "remaining charge is reusable in a different encounter")
    var second := next_session.resolve_ultimate(AISHA_ID, TARGET_ID, "hemocorde")
    _check(bool(second.get("ok", false)) and int(second.get("charges_remaining", -1)) == 0, "second encounter consumes final level-32 dungeon charge")

    var boss_session: VeilleursTacticalSessionV062 = SESSION_SCRIPT.new() as VeilleursTacticalSessionV062
    add_child(boss_session)
    _check(bool(boss_session.start_first_combat().get("ok", false)), "boss-floor session starts")
    _check(bool(boss_session.configure_watcher_progression(AISHA_ID, 16, "hemocorde", true).get("ok", false)), "boss-floor Aisha progression configures")
    _check(_move_aisha_to_contact(boss_session.runtime, TARGET_ID), "Aisha reaches boss test target")
    _check(bool(boss_session.note_vascular_knowledge(TARGET_ID, "torso", 3).get("ok", false)), "boss vascular knowledge recorded")
    var boss_target: Dictionary = boss_session.runtime.combatants[TARGET_ID]
    boss_target["boss"] = true
    boss_target["hp"] = maxi(1, int(round(float(boss_target.get("max_hp", 1)) * 0.15)))
    boss_session.runtime.combatants[TARGET_ID] = boss_target
    boss_session.apply_bleeding(TARGET_ID, 8, 2)
    var boss_result := boss_session.resolve_ultimate(AISHA_ID, TARGET_ID, "hemocorde")
    _check(bool(boss_result.get("ok", false)), "Hemocorde resolves against compromised boss physiology")
    _check(bool(boss_result.get("boss_floor_applied", false)) and int((boss_session.runtime.combatants[TARGET_ID] as Dictionary).get("hp", 0)) >= 1, "boss survives decisive collapse at explicit floor")
    _check(not bool(boss_result.get("fatal_collapse", true)), "boss cannot receive nonboss terminal collapse")

    session.delete_snapshot(SAVE_PATH)
    session.queue_free()
    restored.queue_free()
    next_session.queue_free()
    boss_session.queue_free()
    _finish()

func _compromise_target(session: VeilleursTacticalSessionV062, target_id: String, hp_ratio: float) -> void:
    var target: Dictionary = session.runtime.combatants[target_id]
    target["hp"] = maxi(1, int(round(float(target.get("max_hp", 1)) * hp_ratio)))
    var body: VeilleursBodyComponent = target.get("body") as VeilleursBodyComponent
    if body != null:
        body.apply_trauma("torso", 80, 0, 3)
    session.runtime.combatants[target_id] = target
    session.apply_bleeding(target_id, 8, 2)

func _move_aisha_for_observation(runtime: VeilleursTacticalCombatRuntimeV2, target_id: String) -> bool:
    if runtime.grid.distance(AISHA_ID, target_id) <= 4:
        return true
    var path: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2)]
    return _follow_path(runtime, path) and runtime.grid.distance(AISHA_ID, target_id) <= 4

func _move_aisha_to_contact(runtime: VeilleursTacticalCombatRuntimeV2, target_id: String) -> bool:
    if runtime.grid.distance(AISHA_ID, target_id) <= 1:
        return true
    var target_position := runtime.grid.position_of(target_id)
    var desired := Vector2i(target_position.x - 1, target_position.y)
    var current := runtime.grid.position_of(AISHA_ID)
    var safety := 0
    while current != desired and safety < 20:
        safety += 1
        var candidates: Array[Vector2i] = []
        if current.x < desired.x:
            candidates.append(current + Vector2i(1, 0))
        elif current.x > desired.x:
            candidates.append(current + Vector2i(-1, 0))
        if current.y < desired.y:
            candidates.append(current + Vector2i(0, 1))
        elif current.y > desired.y:
            candidates.append(current + Vector2i(0, -1))
        candidates.append(current + Vector2i(0, -1))
        candidates.append(current + Vector2i(0, 1))
        var moved := false
        for candidate: Vector2i in candidates:
            if runtime.grid.inside(candidate) and not runtime.grid.occupied(candidate) and runtime.grid.move(AISHA_ID, candidate):
                moved = true
                break
        if not moved:
            return false
        current = runtime.grid.position_of(AISHA_ID)
    return runtime.grid.distance(AISHA_ID, target_id) <= 1

func _follow_path(runtime: VeilleursTacticalCombatRuntimeV2, path: Array[Vector2i]) -> bool:
    for cell: Vector2i in path:
        if runtime.grid.position_of(AISHA_ID) == cell:
            continue
        if runtime.grid.occupied(cell) or not runtime.grid.move(AISHA_ID, cell):
            return false
    return true

func _single_ghoul_encounter(template_id: String) -> Dictionary:
    return {
        "template_id": template_id,
        "objective": "survive",
        "counterplay": "Test controlled Hemocorde encounter",
        "composition": [{"definition_id": TARGET_ID}]
    }

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V062_HEMOCORDE_ULTIMATE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V062_HEMOCORDE: " + failure)
    print("VEILLEURS_V062_HEMOCORDE_ULTIMATE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
