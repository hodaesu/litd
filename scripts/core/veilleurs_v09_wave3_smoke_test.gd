extends Node

const SLICE_SCRIPT := preload("res://scripts/core/veilleurs_vertical_slice_runtime_v09.gd")
const TACTICAL_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v09.gd")
const SAVE_SCRIPT := preload("res://scripts/core/veilleurs_vertical_slice_save_v09.gd")
const BODY_SCRIPT := preload("res://scripts/core/veilleurs_body_component.gd")
const QA_SCENE := preload("res://scenes/veilleurs/v09_vertical_slice_qa.tscn")

const DUNGEONS: Array[String] = [
    "DUNGEON_KHAR_SEN",
    "DUNGEON_SEUIL_ERODE",
    "DUNGEON_CLOITRE_VOIX",
    "DUNGEON_JARDIN_MUES",
    "DUNGEON_TRIBUNAL_CENDRES",
    "DUNGEON_ARCHIVES_AVEUGLES"
]

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    RemanenceRuntime.reset_new_game()
    var nemesis_id := _seed_nemesis()
    _check(nemesis_id != "", "Nemesis fixture receives persistent identity")

    for dungeon_id: String in DUNGEONS:
        var probe: VeilleursVerticalSliceRuntimeV09 = SLICE_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09
        var start_probe: Dictionary = probe.start_dungeon(dungeon_id, 9090)
        _check(bool(start_probe.get("ok", false)), "All six production dungeons start: %s" % dungeon_id)

    var slice: VeilleursVerticalSliceRuntimeV09 = SLICE_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09
    _check(bool(slice.start_dungeon("DUNGEON_KHAR_SEN", 9091).get("ok", false)), "Khar-Sen v0.9 starts")
    _check(_advance_to_encounter(slice), "Khar-Sen reaches a standard combat node")
    var setup: Dictionary = slice.launch_current_encounter()
    _check(bool(setup.get("ok", false)), "First v0.9 authored encounter launches")
    _check(bool(setup.get("nemesis_injected", false)), "Eligible Nemesis is injected into a later authored encounter")
    var returning_runtime_id := _runtime_id_for_remanence(slice.combat, nemesis_id)
    _check(returning_runtime_id != "", "Injected Nemesis preserves its Remanence ID")
    if returning_runtime_id != "":
        var returning_row: Dictionary = slice.combat.combatants[returning_runtime_id]
        var returning_body: VeilleursBodyComponent = returning_row.get("body") as VeilleursBodyComponent
        _check(returning_body != null and (returning_body.serialize().get("missing_parts", []) as Array).has("left_arm"), "Returning Nemesis preserves missing limb")

    var sahen: Dictionary = slice.combat.combatants["ENT_WATCHER_SAHEN"]
    var sahen_body: VeilleursBodyComponent = sahen.get("body") as VeilleursBodyComponent
    sahen_body.apply_trauma("right_arm", 95, 4, 3)
    sahen["hp"] = maxi(1, int(sahen.get("max_hp", 1)) - 55)
    var persisted_hp := int(sahen["hp"])
    slice.combat.combatants["ENT_WATCHER_SAHEN"] = sahen

    var submission_target := returning_runtime_id
    if submission_target == "":
        var active_before: Array[String] = slice.combat.alive_ids("enemy")
        submission_target = active_before[0] if not active_before.is_empty() else ""
    _check(submission_target != "", "A living enemy exists for nonlethal submission")
    if submission_target != "":
        _prepare_submission_victory(slice.combat, submission_target)
        var submit: Dictionary = slice.combat.attempt_subdue(submission_target)
        _check(bool(submit.get("ok", false)) and bool(submit.get("subdued", false)), "Vulnerable enemy is subdued without RNG")
        _check(int((slice.combat.combatants[submission_target] as Dictionary).get("hp", 0)) > 0, "Subdued enemy remains alive")
        _check(slice.combat.alive_ids("enemy").is_empty(), "Subdued enemies no longer block tactical victory")

    var first_result: Dictionary = slice.resolve_active_combat("victory")
    _check(bool(first_result.get("ok", false)), "Submission victory resolves into campaign")
    _check(slice.recruitment_options().size() >= 1 and slice.recruitment_options().size() <= 3, "Real subdued survivor creates bounded recruitment options")
    if not slice.recruitment_options().is_empty():
        var spare: Dictionary = slice.resolve_recruitment_decision(0, "spare")
        _check(bool(spare.get("ok", false)), "A subdued living enemy can be spared")
        var spared_id := str((spare.get("candidate", {}) as Dictionary).get("remanence_id", ""))
        if spared_id != "":
            var events: Array[Dictionary] = RemanenceRuntime.recent_events(spared_id, 1)
            _check(not events.is_empty() and str(events[0].get("type", "")) == "was_spared", "Spare decision becomes a real Remanence event")
        _resolve_remaining_candidates(slice)

    _check(_advance_to_encounter(slice), "Khar-Sen reaches a second combat node")
    var second_setup: Dictionary = slice.launch_current_encounter()
    _check(bool(second_setup.get("ok", false)), "Second authored encounter launches")
    var sahen_second: Dictionary = slice.combat.combatants["ENT_WATCHER_SAHEN"]
    var sahen_second_body: VeilleursBodyComponent = sahen_second.get("body") as VeilleursBodyComponent
    _check(int(sahen_second.get("hp", -1)) == persisted_hp, "Watcher HP persists between expedition combats")
    _check(sahen_second_body != null and (sahen_second_body.serialize().get("missing_parts", []) as Array).has("right_arm"), "Watcher mutilation persists between expedition combats")

    var save_bridge: VeilleursVerticalSliceSaveV09 = SAVE_SCRIPT.new() as VeilleursVerticalSliceSaveV09
    save_bridge.clear()
    _check(save_bridge.save_slice(slice), "Full v0.9 vertical slice writes checksum save")
    var restored: VeilleursVerticalSliceRuntimeV09 = SLICE_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09
    _check(save_bridge.load_into(restored), "Full v0.9 vertical slice restores checksum save")
    _check(restored.combat != null and restored.combat_kind == "authored", "Active authored combat survives v0.9 save/load")
    _check((restored.expedition_watcher_state.get("ENT_WATCHER_SAHEN", {}) as Dictionary).has("body"), "Expedition injury state survives save/load")
    save_bridge.clear()

    var retreat_slice: VeilleursVerticalSliceRuntimeV09 = SLICE_SCRIPT.new() as VeilleursVerticalSliceRuntimeV09
    _check(bool(retreat_slice.start_dungeon("DUNGEON_KHAR_SEN", 9092).get("ok", false)), "Retreat gate fixture starts")
    _check(_advance_to_encounter(retreat_slice), "Retreat gate reaches combat")
    _check(bool(retreat_slice.launch_current_encounter().get("ok", false)), "Retreat gate combat launches")
    var retreat_result: Dictionary = retreat_slice.resolve_active_combat("retreat")
    _check(bool(retreat_result.get("ok", false)), "Retreat resolves")
    _check(retreat_slice.recruitment_options().is_empty(), "Retreat never exposes recruitment candidates")

    var boss: VeilleursTacticalCombatRuntimeV09 = TACTICAL_SCRIPT.new() as VeilleursTacticalCombatRuntimeV09
    _check(bool(boss.setup_boss_combat("ENT_BOSS_GARDIEN_SEUIL", {"region_id":"dungeon_seuil_erode"}).get("ok", false)), "Boss v0.9 combat starts")
    var boss_submit: Dictionary = boss.attempt_subdue("ENT_BOSS_GARDIEN_SEUIL")
    _check(not bool(boss_submit.get("ok", false)) and str(boss_submit.get("reason", "")) == "boss_not_subduable", "Bosses can never be submitted")
    var boss_row: Dictionary = boss.combatants["ENT_BOSS_GARDIEN_SEUIL"]
    boss_row["hp"] = int(round(float(boss_row.get("max_hp", 1)) * 0.65))
    boss.combatants["ENT_BOSS_GARDIEN_SEUIL"] = boss_row
    boss.next_round()
    var phase_pending: Dictionary = boss.boss_phase_snapshot()
    _check(int(phase_pending.get("phase", 0)) == 1 and int(phase_pending.get("pending_phase", 0)) == 2, "70 percent threshold telegraphs phase 2 before applying it")
    boss.next_round()
    _check(int(boss.boss_phase_snapshot().get("phase", 0)) == 2, "Phase 2 applies one round after telegraph")
    boss_row = boss.combatants["ENT_BOSS_GARDIEN_SEUIL"]
    boss_row["hp"] = int(round(float(boss_row.get("max_hp", 1)) * 0.30))
    boss.combatants["ENT_BOSS_GARDIEN_SEUIL"] = boss_row
    boss.next_round()
    _check(int(boss.boss_phase_snapshot().get("pending_phase", 0)) == 3, "35 percent threshold telegraphs phase 3")
    boss.next_round()
    _check(int(boss.boss_phase_snapshot().get("phase", 0)) == 3, "Phase 3 applies one round after telegraph")

    var qa: Node = QA_SCENE.instantiate()
    add_child(qa)
    await get_tree().process_frame
    _check(qa != null and qa is VeilleursVerticalSliceQAV09, "Unified six-dungeon QA scene instantiates")
    _check(qa.get_node_or_null("SubmissionControl") != null, "QA scene exposes nonlethal submission control")
    qa.queue_free()
    _finish()

func _seed_nemesis() -> String:
    var source := {"id":"ENT_ENEMY_GOULE_AFFAMEE", "species_id":"ENT_ENEMY_GOULE_AFFAMEE", "name":"La Revenante"}
    var remanence_id := RemanenceRuntime.prepare_enemy(source, "dungeon_khar_sen")
    var body: VeilleursBodyComponent = BODY_SCRIPT.new({"head":70,"torso":140,"left_arm":90,"right_arm":90,"left_leg":100,"right_leg":100}) as VeilleursBodyComponent
    body.apply_trauma("left_arm", 95, 4, 3)
    var state: Dictionary = RemanenceRuntime.entities.get(remanence_id, {})
    state["stage"] = "nemesis"
    state["score"] = 20
    state["encounters"] = 4
    state["major_events"] = 1
    state["status"] = "active"
    state["protected"] = true
    state["body_snapshot"] = {"persistent_injuries":["left_arm"], "body_state":body.serialize(), "hp":100, "max_hp":160}
    RemanenceRuntime.entities[remanence_id] = state
    return remanence_id

func _prepare_submission_victory(runtime: Variant, target_id: String) -> void:
    for enemy_id: String in runtime.alive_ids("enemy"):
        var row: Dictionary = runtime.combatants[enemy_id]
        if enemy_id == target_id:
            row["hp"] = maxi(1, int(round(float(row.get("max_hp", 1)) * 0.25)))
            row["resolve_current"] = mini(20, int(row.get("resolve_current", 20)))
        else:
            row["hp"] = 0
        runtime.combatants[enemy_id] = row

func _advance_to_encounter(slice: VeilleursVerticalSliceRuntimeV09) -> bool:
    for _step in range(32):
        if not slice.campaign.dungeon.active_encounter.is_empty():
            return true
        var node_id := slice.campaign.dungeon.current_node
        var flags: Dictionary = slice.campaign.dungeon.node_flags.get(node_id, {})
        if not bool(flags.get("completed", false)):
            var resolved: Dictionary = slice.campaign.resolve_current_node("cleared", {})
            if not bool(resolved.get("ok", false)):
                return false
        var next_nodes: Array[String] = slice.campaign.dungeon.available_next()
        if next_nodes.is_empty():
            return false
        var entered: Dictionary = slice.enter_next(next_nodes[0])
        if not bool(entered.get("ok", false)):
            return false
    return false

func _runtime_id_for_remanence(runtime: Variant, remanence_id: String) -> String:
    if runtime == null:
        return ""
    for id_value: Variant in runtime.combatants.keys():
        var runtime_id := str(id_value)
        var row: Dictionary = runtime.combatants[runtime_id]
        if str(row.get("remanence_id", "")) == remanence_id:
            return runtime_id
    return ""

func _resolve_remaining_candidates(slice: VeilleursVerticalSliceRuntimeV09) -> void:
    var options: Array[Dictionary] = slice.recruitment_options()
    for index in range(options.size()):
        if bool((options[index] as Dictionary).get("resolved", false)):
            continue
        slice.resolve_recruitment_decision(index, "leave")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V09_WAVE3_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V09_WAVE3: " + failure)
    print("VEILLEURS_V09_WAVE3_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
