extends Node

const CheckpointRuntime := preload("res://scripts/core/veilleurs_preboss_checkpoint_runtime.gd")

var failures: Array[String] = []
var checkpoint: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    checkpoint = CheckpointRuntime.new()
    _test_t48_preboss_checkpoint_preserves_all_critical_state()
    _finish()

func _test_t48_preboss_checkpoint_preserves_all_critical_state() -> void:
    var source := {
        "seed": "WATCHERS_PREBOSS_0042",
        "room_id": "act_v_preboss_63",
        "injuries": {
            "nayra": [{"id":"fracture_forearm","zone":"arm_right","severity":"serious","stabilized":true,"sequela":"reduced_guard"}],
            "tarek": [{"id":"deep_cut_leg","zone":"leg_left","severity":"serious","stabilized":false}]
        },
        "corpse_states": {
            "corpse_guard_01": {"id":"corpse_guard_01","pose_seed":1122,"burned":true,"can_reanimate":false,"position":{"rank":1}},
            "corpse_memorial_02": {"id":"corpse_memorial_02","pose_seed":7788,"burned":false,"can_reanimate":true,"position":{"rank":3}}
        },
        "terrain_state": {
            "destroyed_doors": ["door_west"],
            "dead_zones": ["vein_zone_2", "vein_zone_4"],
            "shortcuts": ["lower_archive"],
            "stable_light_zones": ["north_lamp", "east_brazier"]
        },
        "memorial_entities": {
            "mem_traque_01": {"species":"Traque-Suie","stage":"elite","wounds":["eye_left_lost"],"shared_history":true,"kills":1},
            "nemesis_censeur_02": {"species":"Censeur Fendu","stage":"nemesis","shared_history":true,"escapes":3}
        },
        "species_knowledge": {
            "Traque-Suie": {"level":5,"proofs":["observation","corpse_analysis","recruitment"]},
            "Archiviste de Version": {"level":3,"proofs":["observation","survival"]}
        }
    }
    var result: Dictionary = checkpoint.call("round_trip", source)
    _check(bool(result.get("identical", false)), "Tests_48/T48 : le checkpoint pré-boss doit restaurer sans différence tous les champs critiques")
    var restored: Dictionary = result.get("restored", {})
    _check(str(restored.get("seed", "")) == str(source.get("seed", "")), "Tests_48/T48 : le seed doit rester strictement identique")
    _check(str(restored.get("room_id", "")) == str(source.get("room_id", "")), "Tests_48/T48 : la salle pré-boss doit rester strictement identique")
    _check(bool(checkpoint.call("values_equivalent", restored.get("injuries", {}), source.get("injuries", {}))), "Tests_48/T48 : blessures, stabilisation et séquelles doivent survivre au checkpoint")
    _check(bool(checkpoint.call("values_equivalent", restored.get("corpse_states", {}), source.get("corpse_states", {}))), "Tests_48/T48 : identité, pose et transformation des cadavres doivent survivre au checkpoint")
    _check(bool(checkpoint.call("values_equivalent", restored.get("terrain_state", {}), source.get("terrain_state", {}))), "Tests_48/T48 : portes, zones mortes, raccourcis et lumière stabilisée doivent survivre au checkpoint")
    _check(bool(checkpoint.call("values_equivalent", restored.get("memorial_entities", {}), source.get("memorial_entities", {}))), "Tests_48/T48 : ennemis mémoriels et Némésis doivent rester identiques")
    _check(bool(checkpoint.call("values_equivalent", restored.get("species_knowledge", {}), source.get("species_knowledge", {}))), "Tests_48/T48 : la connaissance collective confirmée doit rester identique")

    var captured: Dictionary = result.get("captured", {})
    var mutated_source: Dictionary = source
    mutated_source["room_id"] = "mutated_after_capture"
    var terrain: Dictionary = mutated_source.get("terrain_state", {})
    terrain["destroyed_doors"] = ["different_door"]
    mutated_source["terrain_state"] = terrain
    _check(str(captured.get("room_id", "")) == "act_v_preboss_63", "Tests_48/T48 : le snapshot doit être profond et indépendant des mutations postérieures")
    _check((captured.get("terrain_state", {}) as Dictionary).get("destroyed_doors", []) == ["door_west"], "Tests_48/T48 : le terrain capturé ne doit pas être réécrit par une mutation de la source")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_PREBOSS_CHECKPOINT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_PREBOSS_CHECKPOINT_SMOKE: " + failure)
    print("VEILLEURS_PREBOSS_CHECKPOINT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
