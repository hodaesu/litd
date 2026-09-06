extends Node

const CONTENT_SCRIPT := preload("res://scripts/core/veilleurs_content_runtime.gd")
const PRESENTER_SCRIPT := preload("res://scripts/ui/veilleurs_refuge_archive_presenter.gd")

func _ready() -> void:
    var content := CONTENT_SCRIPT.new() as VeilleursContentRuntime
    add_child(content)
    var presenter := PRESENTER_SCRIPT.new() as VeilleursRefugeArchivePresenter
    presenter.bind(content)

    var report := presenter.validation_report()
    assert(bool(report.get("ok", false)))
    assert(int(report.get("touch_target_min_points", 0)) >= 48)

    var phone := presenter.layout_profile(390.0, "touch")
    assert(str(phone.get("name", "")) == "phone")
    assert(int(phone.get("persistent_side_panels", -1)) == 0)
    assert(bool(phone.get("safe_area_required", false)))
    assert(int(phone.get("touch_target_min_points", 0)) >= 48)

    var tablet := presenter.layout_profile(820.0, "touch")
    assert(str(tablet.get("name", "")) == "tablet")
    assert(int(tablet.get("persistent_side_panels", 0)) == 1)

    var desktop := presenter.layout_profile(1440.0, "mouse_keyboard")
    assert(str(desktop.get("name", "")) == "desktop")
    assert(int(desktop.get("persistent_side_panels", 0)) == 2)

    var controller := presenter.layout_profile(1440.0, "controller")
    assert(str(controller.get("name", "")) == "controller")
    assert(not bool(controller.get("pointer_dependency", true)))

    var candidate := content.create_rally_candidate({
        "species_id": "delie_affame",
        "name": "Délié Affamé",
        "persistent_injuries": [{"id": "fracture_leg", "severity": "serious"}],
        "anatomy_part_states": {"leg_left": "critical"}
    }, "I", {"posture": "épuisé", "relation": "méfiance", "volonte": "brisée"})
    var rally_view := presenter.rally_view(candidate)
    assert(not bool(rally_view.get("show_capture_percentage", true)))
    assert(not bool(rally_view.get("capture_is_recruitment", true)))
    assert(bool(rally_view.get("confirmation_required", false)))
    assert(not bool(rally_view.get("boss_recruitment_available", true)))
    assert(str((rally_view.get("observable_state", {}) as Dictionary).get("volonte", "")) == "brisée")

    var rallied := content.resolve_rally_candidate(str(candidate.get("rally_id", "")), true, {"story_eligible": true})
    assert(bool(rallied.get("recruited", false)))
    var refuge := presenter.refuge_view()
    assert(int(refuge.get("capacity", 0)) == 4)
    assert(int(refuge.get("used", 0)) == 1)
    assert((refuge.get("cards", []) as Array).size() == 1)
    var card: Dictionary = (refuge.get("cards", []) as Array)[0]
    assert(str(card.get("injury_summary", "")).contains("1 blessure"))
    assert(str(card.get("relationship_summary", "")).contains("Confiance"))

    var unknown := presenter.archive_entity_view("enemy:unknown:01")
    assert(str(unknown.get("knowledge_state", "")) == "UNKNOWN")
    assert(bool(unknown.get("unknown_is_explicit", false)))
    content.record_archive_hook("enemy:known:01", "knowledge_observed", {"species_id": "delie_affame"})
    var observed := presenter.archive_entity_view("enemy:known:01")
    assert(str(observed.get("knowledge_label", "")) == "Observé")
    assert(presenter.primary_sections() == ["identite_connaissance", "corps", "combat", "histoire", "traces"])

    content.record_boss_phase_observed("le_copiste", 1)
    var boss_view := presenter.boss_archive_view("le_copiste")
    assert((boss_view.get("observed_phases", []) as Array) == [1])
    assert(bool(boss_view.get("unseen_phase_reveal_forbidden", false)))

    print("VEILLEURS_REFUGE_ARCHIVE_PRESENTER_SMOKE_OK")
    get_tree().quit(0)
