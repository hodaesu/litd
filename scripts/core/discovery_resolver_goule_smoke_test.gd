extends Node
const Policy = preload("res://scripts/core/knowledge_policies/goule_odeur_sang_policy.gd")
const Resolver = preload("res://scripts/core/discovery_resolver.gd")
var failures: Array[String] = []
var lookup: Dictionary = {}
var hypothesis: Dictionary = {}

func run() -> void:
    var strong := _resolve(_obs("E1","C1",1,"WATCHER_A",true,"NEAR","WATCHER_B",false,"NEAR","IG1"))
    _check(strong == "STRONG", "comparable bleeding support strong")
    var weak := _resolve(_obs("E2","C1",2,"WATCHER_A",true,"CONTACT","WATCHER_B",false,"FAR","IG2"))
    _check(weak == "WEAK", "closest caps to weak")
    var contra := _resolve(_obs("E3","C2",1,"WATCHER_A",false,"NEAR","WATCHER_B",true,"NEAR","IG3"))
    _check(contra == "MODERATE", "comparable healthy contradicts")
    _resolve(_obs("E4","C2",2,"WATCHER_A",true,"NEAR","WATCHER_B",false,"NEAR","IG4"))
    _check(str(hypothesis.get("status","")) == "PROBABLE", "three supports across two combats reach probable")
    var before := lookup.size()
    _resolve(_obs("E4B","C2",3,"WATCHER_A",true,"NEAR","WATCHER_B",false,"NEAR","IG4"))
    _check(lookup.size() == before, "same independence group dedupes evidence")
    _check(str(hypothesis.get("status","")) != "REFUTED", "one exception does not refute tendency")
    _finish()

func _resolve(observation: Dictionary) -> String:
    var assessments := Policy.evaluate(observation)
    var result := Resolver.resolve_observation(observation, assessments, hypothesis, lookup)
    for value: Variant in result.get("new_evidence_records", []):
        var evidence: Dictionary = value
        lookup[str(evidence.get("evidence_id",""))] = evidence
    hypothesis = (result.get("hypothesis_after", {}) as Dictionary).duplicate(true)
    var rows: Array = result.get("new_evidence_records", []) if result.get("new_evidence_records", []) is Array else []
    return "" if rows.is_empty() else str((rows[0] as Dictionary).get("strength",""))

func _obs(event_id:String, combat_id:String, sequence:int, chosen_id:String, chosen_bleed:bool, chosen_dist:String, other_id:String, other_bleed:bool, other_dist:String, group:String) -> Dictionary:
    return {
        "observation_id":"OBSR_%s" % event_id,
        "event_id":event_id,
        "event_type":"combat.target_selected",
        "subject_entity_id":"ENT_ENEMY_GOULE_AFFAMEE",
        "observer_id":"WATCHER_C",
        "independence_group":group,
        "logical_time":{"combat_id":combat_id,"sequence":sequence},
        "perceived_features":{
            "chosen_target_id":chosen_id,
            "candidate_targets":[
                {"target_id":chosen_id,"bleeding_visible":chosen_bleed,"distance_band":chosen_dist,"accessible":true},
                {"target_id":other_id,"bleeding_visible":other_bleed,"distance_band":other_dist,"accessible":true}
            ]
        }
    }

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("DISCOVERY_RESOLVER_GOULE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    get_tree().quit(1)
