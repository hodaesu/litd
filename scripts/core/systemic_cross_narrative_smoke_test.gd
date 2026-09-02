extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    GameState.current_screen = "expedition"
    await _frames(2)
    CampaignState.current_chapter_id = "chapter_02_before_fall"

    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "protect_lhaor_basin"), "The Lhaor choice must be recorded")
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.dhor_khal_bridge_two_valleys", "restore_grain_bridge"), "The grain bridge choice must be recorded")
    await _frames(1)

    var scene_id := "cross.food.local_security_and_grain_bridge"
    _check(SystemicCrossNarrativeRuntime.pending_scene_count() == 1, "A new systemic crossing must queue exactly one sanctuary scene")
    _check(not SystemicCrossNarrativeRuntime.scene_seen(scene_id), "A queued sanctuary scene must not count as seen before returning")
    _check(SystemicCrossNarrativeRuntime.next_scene_title() == "Le grain et les toiles", "The queued scene must expose its human title without a new UI meter")

    GameState.request_screen("sanctuary")
    await _frames(2)
    _check(SystemicCrossNarrativeRuntime.scene_seen(scene_id), "Returning to the sanctuary must present the queued consequence scene")
    _check(SystemicCrossNarrativeRuntime.pending_scene_count() == 0, "One sanctuary entry must consume only the presented scene")
    _check(_log_contains("SCÈNE AU SANCTUAIRE"), "The existing log must surface the sanctuary scene instead of requiring a new screen")
    _check(_log_contains("Le grain et les toiles"), "The sanctuary log must preserve the scene title")

    var narrative_snapshot := SystemicCrossNarrativeRuntime.serialize()
    SystemicCrossNarrativeRuntime.reset_new_game()
    SystemicCrossNarrativeRuntime.deserialize(narrative_snapshot)
    _check(SystemicCrossNarrativeRuntime.scene_seen(scene_id), "Save restore must preserve seen sanctuary scenes")
    _check(SystemicCrossNarrativeRuntime.pending_scene_count() == 0, "A restored seen scene must not be queued again")
    GameState.current_screen = "expedition"
    GameState.request_screen("sanctuary")
    await _frames(2)
    _check(SystemicCrossNarrativeRuntime.recent_scene_summaries(4).size() == 1, "Re-entering the sanctuary must not replay a seen scene")

    GameState.reset_new_game()
    GameState.current_screen = "expedition"
    await _frames(2)
    CampaignState.current_chapter_id = "chapter_02_before_fall"
    _set_hero_hp("aurelien", 0)
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "split_below_threshold"), "Distributed seed choice must be recorded")
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.dhor_khal_bridge_two_valleys", "distribute_material_local_repairs"), "Distributed repair choice must be recorded")
    await _frames(1)
    var filtered := SystemicCrossNarrativeRuntime.resolved_scene("cross.food.distributed_risk_and_local_repairs")
    _check(not _dialogue_has_speaker(filtered, "hero.aurelien"), "A dead hero must never speak in a sanctuary consequence scene")
    _check(_dialogue_has_speaker(filtered, "hero.marec"), "A living eligible hero must still be able to speak")

    GameState.reset_new_game()
    GameState.current_screen = "expedition"
    await _frames(2)
    CampaignState.current_chapter_id = "chapter_02_before_fall"
    _check(SystemicCrossRuntime.record_contextual_choice("quest.litd1.lhaor_seeds_that_remain", "protect_lhaor_basin"), "A prior contextual choice is required before a named death consequence")
    var death_context := {"name": "Iria Sen", "cause": "le convoi médical a été retardé par la saturation du passage"}
    _check(SystemicCrossRuntime.record_external_trigger("contextual_named_death", death_context), "The named death trigger must be accepted")
    await _frames(1)
    var death_scene := SystemicCrossNarrativeRuntime.resolved_scene("cross.relationship.named_death_after_difficult_choice")
    _check(str(death_scene.get("title", "")) == "Iria Sen", "A named death scene must use the person's actual name")
    _check(str(death_scene.get("closing", "")).contains("saturation du passage"), "A named death scene must keep the material cause instead of a moral verdict")

    GameState.reset_new_game()
    await _frames(1)
    _check(SystemicCrossNarrativeRuntime.pending_scene_count() == 0, "A genuine new game must clear pending narrative scenes")
    _check(SystemicCrossNarrativeRuntime.recent_scene_summaries().is_empty(), "A genuine new game must clear narrative scene history")
    _finish()

func _dialogue_has_speaker(scene: Dictionary, speaker_id: String) -> bool:
    for value in scene.get("dialogue", []):
        var line: Dictionary = value if value is Dictionary else {}
        if str(line.get("speaker_id", "")) == speaker_id:
            return true
    return false

func _set_hero_hp(hero_id: String, hp: int) -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value if hero_value is Dictionary else {}
        if str(hero.get("id", "")) == hero_id:
            hero["hp"] = hp
            return

func _log_contains(fragment: String) -> bool:
    for line in GameState.log_lines:
        if line.contains(fragment):
            return true
    return false

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("SYSTEMIC_CROSS_NARRATIVE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("SYSTEMIC_CROSS_NARRATIVE_SMOKE: " + failure)
    print("SYSTEMIC_CROSS_NARRATIVE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
