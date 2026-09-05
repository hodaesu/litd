extends Node

const HybridDungeonGenerator := preload("res://scripts/core/hybrid_dungeon_generator.gd")

const MOBILE_SEEDS := 1500
const PC_SEEDS := 750

var failures: Array[String] = []
var generated_rooms := 0
var mobile_approach_rooms := 0
var pc_approach_rooms := 0
var pc_rooms_above_mobile_visual_cap := 0

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    RemanenceRuntime.reset_new_game()
    _seed_pressure_scars()
    _simulate_profile("mobile", MOBILE_SEEDS, 4, 2)
    _simulate_profile("pc", PC_SEEDS, 8, 4)
    _check(generated_rooms >= 20000, "RoomPersistenceMass : la simulation doit couvrir au moins vingt mille projections de salles réelles")
    _check(mobile_approach_rooms == MOBILE_SEEDS, "RoomPersistenceMass : chaque seed mobile doit conserver la salle d'approche")
    _check(pc_approach_rooms == PC_SEEDS, "RoomPersistenceMass : chaque seed PC doit conserver la salle d'approche")
    _check(pc_rooms_above_mobile_visual_cap > 0, "RoomPersistenceMass : le profil PC doit pouvoir conserver plus de quatre cicatrices visibles sans modifier le contrat mobile")
    _finish()

func _seed_pressure_scars() -> void:
    var common := {"graph_key":"approach","region_id":"act_i"}
    RemanenceRuntime.create_world_scar("stress.approach.corpse", "persistent_corpse", "regional", common.merged({
        "owner_kind":"watcher",
        "owner_name":"Veilleur de stress",
        "body_snapshot":{"persistent_injuries":[{"id":"leg_fracture","severity":"critical"}]},
        "summary":"Un corps mémoriel demeure dans la salle d'approche."
    }, true))
    RemanenceRuntime.create_world_scar("stress.approach.nemesis", "nemesis_mark", "historical", common.merged({
        "protected":true,
        "summary":"Une marque de Némésis traverse la pierre."
    }, true))
    RemanenceRuntime.create_world_scar("stress.approach.shortcut", "opened_shortcut", "regional", common.merged({
        "summary":"Un raccourci ouvert lors d'une expédition antérieure reste praticable."
    }, true))
    RemanenceRuntime.create_world_scar("stress.approach.burn", "burned_area", "local", common.merged({
        "summary":"Une zone brûlée conserve sa fonction de danger."
    }, true))
    RemanenceRuntime.create_world_scar("stress.approach.blood1", "old_blood", "trace", common.merged({"summary":"Trace de sang A."}, true))
    RemanenceRuntime.create_world_scar("stress.approach.blood2", "old_blood", "trace", common.merged({"summary":"Trace de sang B."}, true))

func _simulate_profile(device_profile: String, seed_count: int, visible_cap: int, interactive_cap: int) -> void:
    for seed_index in range(seed_count):
        var generator: RefCounted = HybridDungeonGenerator.new()
        var seed_value: int = 100000 + seed_index * 7919 + (5000000 if device_profile == "pc" else 0)
        var result: Dictionary = generator.call("generate", seed_value, "first_veil_crypts", {
            "visit_kind":"revisit",
            "device_profile":device_profile,
            "zone_id":"first_veil_crypts",
            "region_id":"act_i"
        })
        _check(bool(result.get("success", false)), "RoomPersistenceMass : génération invalide pour %s seed %d" % [device_profile, seed_value])
        if not bool(result.get("success", false)):
            continue
        var validation: Dictionary = result.get("validation", {})
        _check(bool(validation.get("valid", false)), "RoomPersistenceMass : la projection ne doit jamais casser la solvabilité du graphe")
        _check(bool(validation.get("physical_retreat_supported", false)), "RoomPersistenceMass : la retraite physique doit rester possible après projection")
        var layout: Array = result.get("layout", [])
        generated_rooms += layout.size()
        var approach_found := false
        for room_value: Variant in layout:
            if not (room_value is Dictionary):
                continue
            var room: Dictionary = room_value
            _check(bool(room.get("hand_authored_geometry", false)), "RoomPersistenceMass : aucune projection ne doit créer de géométrie procédurale")
            _check(str(room.get("geometry_policy", "")) == "immutable_authored", "RoomPersistenceMass : la politique de géométrie authored doit rester immuable")
            _check(bool(room.get("persistence_projection_ready", false)), "RoomPersistenceMass : chaque salle hybride doit traverser l'assembleur de Rémanence")
            var projection: Dictionary = room.get("persistence_projection", {})
            _check(int(projection.get("active_scars", 0)) <= visible_cap, "RoomPersistenceMass : dépassement du budget visible %s" % device_profile)
            _check(int(projection.get("interactive_scars", 0)) <= interactive_cap, "RoomPersistenceMass : dépassement du budget interactif %s" % device_profile)
            if str(room.get("graph_key", "")) == "approach":
                approach_found = true
                _check((room.get("environment_tags", []) as Array).has("corpse_memory"), "RoomPersistenceMass : le cadavre prioritaire doit survivre à la pression de budget")
                _check((room.get("environment_tags", []) as Array).has("nemesis_trace"), "RoomPersistenceMass : la trace de Némésis protégée doit survivre à la pression de budget")
                _check(str(room.get("remanence_route_state", "")) == "opened_shortcut", "RoomPersistenceMass : le raccourci persistant doit rester fonctionnel")
                if device_profile == "pc" and int(projection.get("active_scars", 0)) > 4:
                    pc_rooms_above_mobile_visual_cap += 1
        _check(approach_found, "RoomPersistenceMass : la salle d'approche est absente pour %s seed %d" % [device_profile, seed_value])
        if device_profile == "mobile" and approach_found:
            mobile_approach_rooms += 1
        elif device_profile == "pc" and approach_found:
            pc_approach_rooms += 1

        if seed_index % 250 == 0:
            var mirror_generator: RefCounted = HybridDungeonGenerator.new()
            var mirror: Dictionary = mirror_generator.call("generate", seed_value, "first_veil_crypts", {
                "visit_kind":"revisit",
                "device_profile":device_profile,
                "zone_id":"first_veil_crypts",
                "region_id":"act_i"
            })
            _check(_layout_signature(result.get("layout", [])) == _layout_signature(mirror.get("layout", [])), "RoomPersistenceMass : un même seed doit produire la même signature de salles et de Rémanence")

func _layout_signature(layout: Array) -> String:
    var rows: Array[String] = []
    for room_value: Variant in layout:
        if not (room_value is Dictionary):
            continue
        var room: Dictionary = room_value
        var projection: Dictionary = room.get("persistence_projection", {})
        rows.append("%s|%s|%s|%d|%d" % [
            str(room.get("graph_key", "")),
            str(room.get("template_id", "")),
            str(room.get("room_state", "")),
            int(projection.get("active_scars", 0)),
            int(projection.get("interactive_scars", 0))
        ])
    return ";".join(rows)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_ROOM_PERSISTENCE_MASS_SMOKE_OK rooms=%d mobile=%d pc=%d" % [generated_rooms, MOBILE_SEEDS, PC_SEEDS])
        get_tree().quit(0)
        return
    for failure: String in failures.slice(0, mini(40, failures.size())):
        push_error("VEILLEURS_ROOM_PERSISTENCE_MASS_SMOKE: " + failure)
    print("VEILLEURS_ROOM_PERSISTENCE_MASS_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
