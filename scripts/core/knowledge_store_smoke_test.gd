extends Node
const Store = preload("res://scripts/core/knowledge_store.gd")
var failures: Array[String] = []

func run() -> void:
    _test_batch_and_replay()
    _test_bounded_and_save()
    _test_forbidden_atomic()
    _finish()

func _test_batch_and_replay() -> void:
    var store = Store.new()
    var rows: Array = []
    for observer: String in ["WATCHER_A","WATCHER_B","WATCHER_C"]:
        rows.append(_row(_obs("E1",1,observer), _result("EVID_SHARED","PROBABLE",2,true)))
    var first := store.commit_event_batch("E1",1,"ENT_ENEMY_GOULE_AFFAMEE",rows)
    _check(bool(first.get("ok",false)), "batch commit")
    _check(store.active_observations("ENT_ENEMY_GOULE_AFFAMEE").size() == 3, "3 observer records")
    _check(store.evidence_by_id.size() == 1, "same evidence stored once")
    var before := JSON.stringify(store.serialize())
    var replay := store.commit_event_batch("E1",1,"ENT_ENEMY_GOULE_AFFAMEE",rows)
    _check(bool(replay.get("deduplicated",false)), "replay deduped")
    _check(before == JSON.stringify(store.serialize()), "replay idempotent")

func _test_bounded_and_save() -> void:
    var store = Store.new()
    for i in range(10):
        var seq := i + 1
        var eid := "B%d" % seq
        store.commit_event_batch(eid,seq,"ENT_ENEMY_GOULE_AFFAMEE",[_row(_obs(eid,seq,"WATCHER_A"),_result("EV%d"%seq,"HYPOTHESIS",1,false))])
    _check(store.active_observations("ENT_ENEMY_GOULE_AFFAMEE").size() == 8, "active observations bounded to 8")
    _check(store.evidence_by_id.size() == 10, "evidence persists")
    var payload := store.serialize()
    var restored = Store.new()
    restored.deserialize(payload)
    _check(JSON.stringify(payload) == JSON.stringify(restored.serialize()), "serialize deserialize stable")

func _test_forbidden_atomic() -> void:
    var store = Store.new()
    var bad := _obs("BAD",1,"WATCHER_A")
    bad["ai_reason"] = "hidden"
    var report := store.commit_event_batch("BAD",1,"ENT_ENEMY_GOULE_AFFAMEE",[_row(bad,_result("BAD_EVID","HYPOTHESIS",1,false))])
    _check(not bool(report.get("ok",true)), "forbidden field blocks batch")
    _check(store.observations_by_id.is_empty() and store.evidence_by_id.is_empty(), "no partial write")

func _obs(event_id:String, sequence:int, observer:String) -> Dictionary:
    return {
        "observation_id":"OBSR_%s_%s" % [event_id,observer],
        "event_id":event_id,
        "subject_entity_id":"ENT_ENEMY_GOULE_AFFAMEE",
        "logical_time":{"sequence":sequence},
        "observer_id":observer
    }

func _result(evidence_id:String, status:String, level:int, unlock:bool) -> Dictionary:
    return {
        "accepted":true,
        "new_evidence_records":[{
            "evidence_id":evidence_id,
            "hypothesis_id":"HYP_GOULE_AFFAMEE_01",
            "direction":"SUPPORT",
            "strength":"STRONG"
        }],
        "hypothesis_after":{
            "hypothesis_id":"HYP_GOULE_AFFAMEE_01",
            "subject_entity_id":"ENT_ENEMY_GOULE_AFFAMEE",
            "status":status,
            "supporting_evidence_ids":[evidence_id],
            "contradicting_evidence_ids":[],
            "neutral_evidence_ids":[],
            "status_history":[]
        },
        "knowledge_projection":{
            "archive_level":level,
            "unlock_ids":["UNLOCK_GOULE_AFFAMEE_TARGET_VULNERABLE_HINT"] if unlock else []
        }
    }

func _row(observation:Dictionary, result:Dictionary) -> Dictionary:
    return {"observation":observation,"resolution_result":result}

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("KNOWLEDGE_STORE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    get_tree().quit(1)
