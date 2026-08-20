extends Node

func _ready() -> void:
    HUDDirector.clear_transient()
    HUDDirector.consume_journal_backlog()
    HUDDirector.set_reduced_motion(false)
    HUDDirector.set_screen_context("exploration")
    assert(HUDDirector.disclosure_level == HUDDirector.LEVEL_WORLD_ONLY)

    var guidance := HUDDirector.request_world_guidance(
        "ash_cloister",
        ["cendre", "lanternes"],
        {"strength": "subtle"}
    )
    assert(str(guidance.get("decision", "")) == "world_cue")
    assert(str(guidance.get("channel", "")) == "cendre")
    assert(bool(guidance.get("hud_marker", true)) == false)

    var inspection_info := HUDDirector.route_event(
        "hud_smoke_ancient_text",
        "INFORMATION",
        HUDDirector.LEVEL_INSPECTION,
        {"title": "Texte ancien", "text": "À lire plus tard"}
    )
    assert(str(inspection_info.get("decision", "")) == "journal_silent")
    assert(HUDDirector.journal_backlog_count() == 1)

    var critical := HUDDirector.route_event(
        "hud_smoke_critical_hp",
        "CRITICAL",
        HUDDirector.LEVEL_DANGER,
        {"title": "Blessure critique", "text": "Darius est en danger"}
    )
    assert(str(critical.get("decision", "")) == "present")
    assert(HUDDirector.has_critical_event())

    var low_priority := HUDDirector.route_event(
        "hud_smoke_lore_during_danger",
        "INFORMATION",
        HUDDirector.LEVEL_DANGER,
        {"title": "Archive", "text": "Nouvelle entrée"}
    )
    assert(str(low_priority.get("decision", "")) == "journal_silent")
    assert(HUDDirector.journal_backlog_count() == 2)

    var statuses := HUDDirector.summarize_statuses(["bleed", "guard", "stun", "rupture", "fear"])
    assert(statuses["visible"].size() == 2)
    assert(int(statuses["overflow"]) == 3)
    assert(str(statuses["overflow_label"]) == "+3")

    assert(HUDDirector.request_action("capture_ghoul", true) == "confirm_required")
    assert(HUDDirector.request_action("capture_ghoul", true) == "execute")

    HUDDirector.set_reduced_motion(true)
    var motion := HUDDirector.motion_profile()
    assert(float(motion["appearance_seconds"]) == 0.0)
    assert(bool(motion["loop"]) == false)

    HUDDirector.clear_transient()
    HUDDirector.set_screen_context("combat")
    assert(HUDDirector.disclosure_level == HUDDirector.LEVEL_DECISION)

    print("HUD_DIRECTOR_SMOKE_OK")
    get_tree().quit()
