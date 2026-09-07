extends Node

const EnemyAIRuntime := preload("res://scripts/core/veilleurs_enemy_ai_runtime.gd")

var failures: Array[String] = []
var ai: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    ai = EnemyAIRuntime.new()
    _test_t33_delie_prioritizes_wounded_only_if_accessible()
    _test_t34_porte_signe_loses_gesture_actions_and_replans()
    _test_t35_archivist_four_families_break_perfect_counter()
    _finish()

func _test_t33_delie_prioritizes_wounded_only_if_accessible() -> void:
    var enemy := {
        "name": "Délié Affamé",
        "accessible_positions": [0, 1]
    }
    var heroes := [
        {"id":"front_healthy","name":"Front sain","combat_position":0,"hp":20,"max_hp":20,"persistent_injuries":[]},
        {"id":"front_wounded","name":"Front blessé","combat_position":1,"hp":10,"max_hp":20,"persistent_injuries":[{"id":"deep_wound"}]},
        {"id":"rear_critical","name":"Arrière critique","combat_position":3,"hp":1,"max_hp":20,"persistent_injuries":[{"id":"fracture_leg"}],"bleeding":true}
    ]
    var target: Dictionary = ai.call("select_target", enemy, heroes)
    _check(bool(target.get("accessible", false)), "Tests_48/T33 : le Délié doit sélectionner une cible réellement accessible")
    _check(int(target.get("index", -1)) == 1, "Tests_48/T33 : il peut privilégier le blessé accessible sans cibler le blessé arrière inaccessible")
    _check(str((target.get("hero", {}) as Dictionary).get("id", "")) == "front_wounded", "Tests_48/T33 : l'accessibilité doit primer sur la simple faiblesse en PV")

func _test_t34_porte_signe_loses_gesture_actions_and_replans() -> void:
    var enemy := {
        "name": "Porte-Signe",
        "hp": 20,
        "max_hp": 20,
        "dismembered_parts": ["hand_left"]
    }
    var actions := [
        {"id":"sign_command","name":"Ordre des mains","required_functions":["gesture"]},
        {"id":"step_back","name":"Repli silencieux","required_functions":["mobility"]},
        {"id":"body_guard","name":"Garde corporelle","required_functions":[]}
    ]
    var available: Array = ai.call("available_actions", enemy, actions)
    var available_ids: Array[String] = []
    for value: Variant in available:
        if value is Dictionary:
            available_ids.append(str((value as Dictionary).get("id", "")))
    _check(not available_ids.has("sign_command"), "Tests_48/T34 : les capacités exigeant les mains/gestes doivent disparaître quand la fonction est perdue")
    _check(available_ids.has("step_back") or available_ids.has("body_guard"), "Tests_48/T34 : les actions n'exigeant pas les mains doivent rester disponibles")
    var plan: Dictionary = ai.call("plan_porte_signe", enemy, actions)
    _check(bool(plan.get("ok", false)), "Tests_48/T34 : le Porte-Signe mutilé doit pouvoir construire un nouveau plan")
    _check(bool(plan.get("replanned", false)), "Tests_48/T34 : la perte fonctionnelle doit provoquer une replanification IA")
    _check(str(plan.get("reason", "")) == "hands_unavailable_replan", "Tests_48/T34 : la raison de la replanification doit être explicite")
    _check(str((plan.get("action", {}) as Dictionary).get("id", "")) != "sign_command", "Tests_48/T34 : l'IA ne doit pas sélectionner une action gestuelle devenue physiquement impossible")

func _test_t35_archivist_four_families_break_perfect_counter() -> void:
    var archivist := {"name":"Archiviste de Version","observed_action_families":[]}
    var one: Dictionary = ai.call("observe_action_family", archivist, "attack")
    _check(bool(one.get("perfect_counter", false)), "Tests_48/T35 : avec une seule famille connue, l'Archiviste peut encore produire une réponse ciblée")
    ai.call("observe_action_family", archivist, "guard")
    ai.call("observe_action_family", archivist, "support")
    var saturated: Dictionary = ai.call("observe_action_family", archivist, "movement")
    _check(int(saturated.get("observed_family_count", 0)) == 4, "Tests_48/T35 : quatre familles distinctes doivent être mémorisées sans être fusionnées artificiellement")
    _check(bool(saturated.get("saturated", false)), "Tests_48/T35 : la quatrième famille doit saturer la réponse unique de l'Archiviste")
    _check(not bool(saturated.get("perfect_counter", true)), "Tests_48/T35 : aucune contre-réponse parfaite unique ne doit exister après saturation")
    _check(float(saturated.get("counter_confidence", 1.0)) < 1.0, "Tests_48/T35 : la confiance de contre doit devenir partielle")
    _check(str(saturated.get("response_family", "")) == "mixed_partial", "Tests_48/T35 : l'IA doit passer à une réponse mixte/partielle plutôt qu'à une omniscience")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_ENEMY_AI_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_ENEMY_AI_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_ENEMY_AI_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
