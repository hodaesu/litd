extends Node

var failures: Array[String] = []

class Probe:
    extends Node3D
    var id := ""
    var kind := EnvironmentInteractionContract.KIND_GENERIC
    var salience := ""

    func interaction_descriptor(_actor: Object = null) -> Dictionary:
        return EnvironmentInteractionContract.descriptor(
            "probe:%s" % id,
            kind,
            "Probe %s" % id,
            "INTERAGIR",
            true,
            "",
            false,
            {},
            salience
        )

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(
        EnvironmentInteractionContract.descriptor("door", EnvironmentInteractionContract.KIND_DOOR, "Porte", "OUVRIR").get("salience") == EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "doors default to immediate salience"
    )
    _check(
        EnvironmentInteractionContract.descriptor("mechanism", EnvironmentInteractionContract.KIND_MECHANISM, "Levier", "ACTIVER").get("salience") == EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "mechanisms default to immediate salience"
    )
    _check(
        EnvironmentInteractionContract.descriptor("resource", EnvironmentInteractionContract.KIND_RESOURCE, "Ressource", "RÉCOLTER").get("salience") == EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "resources default to contextual salience"
    )
    _check(
        EnvironmentInteractionContract.descriptor("corpse", EnvironmentInteractionContract.KIND_CORPSE, "Corps", "EXAMINER").get("salience") == EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "corpses default to contextual salience"
    )
    _check(
        EnvironmentInteractionContract.descriptor("curiosity", EnvironmentInteractionContract.KIND_CURIOSITY, "Trace", "EXAMINER").get("salience") == EnvironmentInteractionContract.SALIENCE_INSPECT,
        "curiosities default to inspect salience"
    )
    _check(
        EnvironmentInteractionContract.descriptor("generic", EnvironmentInteractionContract.KIND_GENERIC, "Objet", "INTERAGIR").get("salience") == EnvironmentInteractionContract.SALIENCE_CONTEXTUAL,
        "generic interactions remain contextual for backwards compatibility"
    )

    var authored := Probe.new()
    authored.id = "authored"
    authored.kind = EnvironmentInteractionContract.KIND_CURIOSITY
    authored.salience = EnvironmentInteractionContract.SALIENCE_IMMEDIATE
    add_child(authored)
    var authored_descriptor := EnvironmentInteractionContract.describe(authored)
    _check(
        authored_descriptor.get("salience") == EnvironmentInteractionContract.SALIENCE_IMMEDIATE,
        "authored salience override survives descriptor normalization"
    )

    var invalid := EnvironmentInteractionContract.descriptor(
        "invalid",
        EnvironmentInteractionContract.KIND_CURIOSITY,
        "Trace",
        "EXAMINER",
        true,
        "",
        false,
        {},
        "loud"
    )
    _check(
        invalid.get("salience") == EnvironmentInteractionContract.SALIENCE_INSPECT,
        "invalid salience falls back to the semantic kind default"
    )

    var controller := ExplorationPartyController.new()
    add_child(controller)
    controller.interaction_distance = 2.4

    var immediate_score := controller._interaction_candidate_score(1.2, 0.82, EnvironmentInteractionContract.SALIENCE_IMMEDIATE)
    var contextual_score := controller._interaction_candidate_score(1.2, 0.82, EnvironmentInteractionContract.SALIENCE_CONTEXTUAL)
    var inspect_score := controller._interaction_candidate_score(1.2, 0.82, EnvironmentInteractionContract.SALIENCE_INSPECT)
    _check(immediate_score > contextual_score, "immediate salience wins a close geometric tie")
    _check(contextual_score > inspect_score, "contextual salience wins a close geometric tie over inspect")

    var clear_contextual := controller._interaction_candidate_score(0.65, 0.98, EnvironmentInteractionContract.SALIENCE_CONTEXTUAL)
    var weak_immediate := controller._interaction_candidate_score(2.25, 0.28, EnvironmentInteractionContract.SALIENCE_IMMEDIATE)
    _check(
        clear_contextual > weak_immediate,
        "salience remains a light bias and cannot override a clearly better spatial target"
    )

    var curiosity := Probe.new()
    curiosity.id = "only-curiosity"
    curiosity.kind = EnvironmentInteractionContract.KIND_CURIOSITY
    add_child(curiosity)
    var only_choice := controller._choose_interaction_candidate([
        {
            "target": curiosity,
            "distance": 1.0,
            "alignment": 0.9,
            "salience": EnvironmentInteractionContract.SALIENCE_INSPECT,
            "score": controller._interaction_candidate_score(1.0, 0.9, EnvironmentInteractionContract.SALIENCE_INSPECT),
        }
    ])
    _check(only_choice == curiosity, "inspect-tier interactions remain reachable when they are the relevant target")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("INTERACTION_SALIENCE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("INTERACTION_SALIENCE_FAIL: %s" % failure)
    get_tree().quit(1)
