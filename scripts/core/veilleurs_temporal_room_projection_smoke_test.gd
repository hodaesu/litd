extends Node

const RoomPersistenceAssembler := preload("res://scripts/core/veilleurs_room_persistence_assembler.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GameState.reset_new_game()
    RemanenceRuntime.reset_new_game()
    await get_tree().process_frame

    var corpse_id := RemanenceRuntime.create_world_scar("accord.pillars.center", "persistent_corpse", "local", {
        "owner_kind":"enemy",
        "owner_id":"mem:projection_ghoul:000001",
        "owner_name":"Goule de projection",
        "body_snapshot":{"persistent_injuries":[],"body_state":{},"dismembered_parts":[]}
    })
    var burn_id := RemanenceRuntime.create_world_scar("accord.pillars.center", "burned_area", "local", {
        "summary":"Une combustion ancienne a marqué la pierre."
    })
    var relic_id := RemanenceRuntime.create_world_scar("accord.gallery.memorial_floor", "major_item_removed", "regional", {
        "object_id":"relic:projection_unique",
        "summary":"Une relique unique a été emportée."
    })
    _check(corpse_id != "" and burn_id != "" and relic_id != "", "Projection temporelle : les trois cicatrices doivent être créées")

    for _index in range(5):
        RemanenceRuntime.advance_expedition_cycle()

    var room := {
        "id":"projection_room",
        "template_id":"projection_template",
        "graph_key":"projection",
        "scar_anchors":["accord.pillars.center", "accord.gallery.memorial_floor"],
        "environment_tags":[]
    }
    var assembler: RefCounted = RoomPersistenceAssembler.new()
    var result: Dictionary = assembler.call("assemble_room", room, {}, {"device_profile":"mobile"})
    _check(bool(result.get("ok", false)), "Projection temporelle : l'assembleur réel doit accepter la salle")
    var projected: Dictionary = result.get("room", {})
    var tags: Array = projected.get("environment_tags", [])
    _check(tags.has("corpse_bones"), "Projection temporelle : le rendu doit recevoir le tag d'ossements à cinq expéditions")
    _check(tags.has("burn_scar"), "Projection temporelle : le rendu doit recevoir la cicatrice de feu vieillie")
    _check(tags.has("object_missing_history"), "Projection temporelle : l'absence historique de la relique doit être projetée")

    var temporal: Array = projected.get("remanence_temporal_presentations", [])
    _check(temporal.size() >= 3, "Projection temporelle : les présentations temporelles doivent être exposées à la salle")
    _check(_has_representation(temporal, "skeletal_remains"), "Projection temporelle : skeletal_remains doit être directement consommable par le rendu")
    _check(_has_representation(temporal, "fire_scar"), "Projection temporelle : fire_scar doit être directement consommable par le rendu")
    _check(_has_representation(temporal, "historic_absence"), "Projection temporelle : historic_absence doit être directement consommable par l'UI")

    var corpses: Array = projected.get("persistent_corpses", [])
    _check(corpses.size() == 1, "Projection temporelle : le corps vieilli doit rester reconstructible une seule fois")
    if not corpses.is_empty():
        var corpse: Dictionary = corpses[0]
        _check(str(corpse.get("representation", "")) == "skeletal_remains", "Projection temporelle : la reconstruction doit demander le proxy osseux")
        _check(bool(corpse.get("use_proxy_model", false)) and not bool(corpse.get("resimulate_ragdoll", true)), "Projection temporelle : le mobile doit utiliser un proxy sans ragdoll")

    var projection: Dictionary = projected.get("persistence_projection", {})
    _check(int(projection.get("temporal_presentations", 0)) >= 3, "Projection temporelle : le résumé doit comptabiliser les états temporels")
    _check(str(projection.get("device_profile", "")) == "mobile", "Projection temporelle : le profil mobile doit rester explicite")

    _finish()

func _has_representation(values: Array, representation: String) -> bool:
    for value: Variant in values:
        if value is Dictionary and str((value as Dictionary).get("representation", "")) == representation:
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_TEMPORAL_ROOM_PROJECTION_SMOKE_OK bones=true burn=true relic_absence=true mobile_proxy=true")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_TEMPORAL_ROOM_PROJECTION_SMOKE: " + failure)
    print("VEILLEURS_TEMPORAL_ROOM_PROJECTION_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)