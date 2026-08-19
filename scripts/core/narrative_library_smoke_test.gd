extends Node

var failures: Array[String] = []

func run() -> void:
    _check(not NarrativeLibrary.data.is_empty(), "NarrativeLibrary must load its cross-media data")
    _check(not NarrativeLibrary.folklore_data.is_empty(), "NarrativeLibrary must load its worldwide folklore atlas")
    _check(not NarrativeLibrary.dialogue_data.is_empty(), "NarrativeLibrary must load its dialogue and staging library")
    _check(NarrativeLibrary.quality_axes().size() >= 10, "NarrativeLibrary must expose the sidequest quality axes")
    var rules := NarrativeLibrary.originality_rules()
    _check(rules.get("forbidden", []).size() >= 5, "Originality rules must explicitly forbid recognizable copying")
    _check(rules.get("required", []).size() >= 5, "Originality rules must require synthesis and distance")

    var folklore_coverage := NarrativeLibrary.folklore_coverage()
    _check(int(folklore_coverage.get("regions", 0)) >= 28, "Worldwide folklore atlas must cover many distinct cultural regions")
    _check(int(folklore_coverage.get("reference_clusters", 0)) >= 200, "Worldwide folklore atlas must expose a broad reference corpus")
    _check(int(folklore_coverage.get("narrative_forms", 0)) >= 25, "Worldwide folklore atlas must include many narrative forms")
    _check(int(folklore_coverage.get("motif_families", 0)) >= 40, "Worldwide folklore atlas must include many motif families")
    _check(NarrativeLibrary.folklore_access_level("indigenous_australia") == "community_review_required", "Sensitive Indigenous traditions must require cultural review")
    _check(NarrativeLibrary.folklore_access_level("indigenous_north_america") == "community_review_required", "North American Indigenous traditions must not be treated as generic public-domain fantasy")
    var cultural_rules := NarrativeLibrary.folklore_cultural_protocol()
    _check(cultural_rules.get("access_levels", {}).has("restricted_do_not_adapt"), "Folklore atlas must support a do-not-adapt access level")
    _check(NarrativeLibrary.folklore_design_rules().size() >= 7, "Folklore atlas must expose extraction rules rather than reusable plots")

    var dialogue_coverage := NarrativeLibrary.dialogue_coverage()
    _check(int(dialogue_coverage.get("quality_axes", 0)) >= 12, "Dialogue library must expose rigorous quality axes")
    _check(int(dialogue_coverage.get("dialogue_techniques", 0)) >= 35, "Dialogue library must expose a broad craft vocabulary")
    _check(int(dialogue_coverage.get("staging_techniques", 0)) >= 15, "Dialogue library must connect text to staging")
    _check(int(dialogue_coverage.get("scene_patterns", 0)) >= 8, "Dialogue library must expose reusable abstract scene patterns")
    _check(int(dialogue_coverage.get("public_domain_families", 0)) >= 10, "Dialogue library must cover diverse public-domain traditions")
    _check(int(dialogue_coverage.get("public_domain_references", 0)) >= 75, "Dialogue library must expose a substantial public-domain reading corpus")
    _check(int(dialogue_coverage.get("modern_reference_only", 0)) >= 6, "Dialogue library must distinguish modern reference-only craft study")
    _check(not NarrativeLibrary.dialogue_technique("subtext_gap").is_empty(), "Dialogue library must expose subtext technique")
    _check(not NarrativeLibrary.dialogue_technique("objective_and_tactic").is_empty(), "Dialogue library must expose playable objectives and tactics")
    _check(not NarrativeLibrary.staging_technique("implied_stage_action").is_empty(), "Dialogue library must expose implied stage action")
    _check(NarrativeLibrary.dialogue_voice_fields().size() >= 12, "Dialogue library must support distinct character voice design")
    _check(NarrativeLibrary.dialogue_production_checklist().size() >= 12, "Dialogue library must expose a production checklist")
    var dialogue_rules := NarrativeLibrary.dialogue_originality_protocol()
    _check(str(dialogue_rules.get("stored_text_policy", "")) == "metadata_and_abstract_techniques_only", "Dialogue library must never store source excerpts")
    _check(dialogue_rules.get("forbidden", []).size() >= 6, "Dialogue library must explicitly reject recognizable imitation")
    var modern_policy := NarrativeLibrary.dialogue_modern_reference_policy()
    _check("Aucun texte" in str(modern_policy.get("policy", "")), "Modern references must stay high-level and text-free")

    GameState.reset_new_game()
    ExpeditionManager.reset_to_full_resupply()
    AshlandsRuntime.current_zone_id = "zone_02_village_ravage"
    await _frames(2)
    var survivor_choice := FieldEncounterRuntime.resolve_choice("c01_village_survivors", "full_aid")
    _check(bool(survivor_choice.get("applied", false)), "Narrative smoke requires the survivor branch")
    AshlandsRuntime.current_zone_id = "c03_abandoned_relay"
    var survivor_return := FieldEncounterRuntime.resolve_return("c03_survivor_outpost")
    _check(bool(survivor_return.get("applied", false)), "Narrative smoke requires the chapter III return")

    var iven := CommunityRuntime.quest_definition("q_iven_erased_days")
    var yoren := CommunityRuntime.quest_definition("q_yoren_false_exit")
    _check(not iven.is_empty() and not yoren.is_empty(), "Both emergent sidequests must exist")
    _check(NarrativeLibrary.quest_devices(iven).size() >= 3, "Iven's quest must synthesize several narrative mechanisms")
    _check(NarrativeLibrary.quest_devices(yoren).size() >= 3, "Yoren's quest must synthesize several narrative mechanisms")
    for device_id in NarrativeLibrary.quest_devices(iven):
        _check(not NarrativeLibrary.device(device_id).is_empty(), "Iven must only reference known narrative mechanisms")
    for device_id in NarrativeLibrary.quest_devices(yoren):
        _check(not NarrativeLibrary.device(device_id).is_empty(), "Yoren must only reference known narrative mechanisms")

    var iven_offer := NarrativeLibrary.quest_state_text(iven, "offered")
    var iven_active := NarrativeLibrary.quest_state_text(iven, "active")
    var iven_done := NarrativeLibrary.quest_state_text(iven, "completed")
    _check(iven_offer != iven_active and iven_active != iven_done, "Quest narration must change with quest state")
    _check(iven_offer.length() > 100 and iven_active.length() > 100 and iven_done.length() > 100, "Quest state narration must be substantial rather than a task label")
    _check(NarrativeLibrary.quest_reframe(iven).length() > 100, "Iven's quest must contain a real recontextualization")
    _check(NarrativeLibrary.quest_dramatic_question(yoren).length() > 80, "Yoren's quest must expose a dramatic question")

    _check(CommunityRuntime.accept_quest("q_yoren_false_exit"), "Yoren's quest must be accept-able")
    _check(Chapter03Runtime.collect_evidence("ev_purge_protocol"), "Yoren's story must resolve through existing chapter III evidence")
    await _frames(1)
    _check(_quest_state("q_yoren_false_exit") == "completed", "Yoren's narrative quest must complete through actual campaign evidence")

    _finish()

func _quest_state(quest_id: String) -> String:
    for entry in CommunityRuntime.quest_entries():
        if str(entry.get("id", "")) == quest_id:
            return str(entry.get("state", ""))
    return ""

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("NARRATIVE_LIBRARY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("NARRATIVE_LIBRARY_SMOKE: " + failure)
    print("NARRATIVE_LIBRARY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
