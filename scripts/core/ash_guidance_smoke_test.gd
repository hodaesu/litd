extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _test_policy()
    await _test_trail_runtime()
    if failures.is_empty():
        print("ASH_GUIDANCE_SMOKE_OK")
        get_tree().quit(0)
    else:
        for failure: String in failures:
            push_error("ASH_GUIDANCE_SMOKE: %s" % failure)
        print("ASH_GUIDANCE_SMOKE_FAILED: %d" % failures.size())
        get_tree().quit(1)

func _test_policy() -> void:
    var policy := AshGuidancePolicy.new()
    _expect(policy.boss_room_id == "fv_boss", "Le boss du Premier Voile doit être fv_boss")
    var route: Dictionary = policy.route_to_boss("fv_entry", ["p1_guard", "p1_trap"])
    _expect(bool(route.get("found", false)), "Une route publique vers le boss doit exister depuis l'entrée")
    _expect(str(route.get("next_room_id", "")) in ["p1_guard", "p1_trap"], "Le premier souffle doit viser une sortie réellement accessible")
    _expect(not (route.get("path", []) as Array).has("p1_secret"), "La route de guidage ne doit jamais emprunter un secret caché")

    var entry_proximity: float = policy.boss_proximity("fv_entry")
    var gate_proximity: float = policy.boss_proximity("p4_gate")
    _expect(gate_proximity > entry_proximity, "La cendre du boss doit rougir à mesure que le joueur descend")
    _expect(policy.boss_proximity("fv_boss") >= 0.99, "La salle du boss doit atteindre l'incandescence maximale")

    var grey: Color = policy.color_for("boss", 0.0)
    var boss_near: Color = policy.color_for("boss", 1.0)
    var quest_near: Color = policy.color_for("quest", 1.0)
    _expect(absf(grey.r - grey.b) < 0.08, "La couleur lointaine doit rester grise")
    _expect(boss_near.r > boss_near.b * 2.0, "Le guidage boss proche doit devenir rouge")
    _expect(quest_near.b > quest_near.r * 1.2, "Le guidage quête proche doit devenir bleu")

func _test_trail_runtime() -> void:
    var trail := AshGuidanceTrail.new()
    trail.name = "SmokeAshGuidanceTrail"
    add_child(trail)
    await get_tree().process_frame

    trail.guide_to_world_position(Vector3(0.0, 0.0, -12.0), "boss", -1.0, 0.82)
    var hidden_snapshot: Dictionary = trail.snapshot()
    _expect(not bool(hidden_snapshot.get("wisps_emitting", true)), "Définir un objectif ne doit pas afficher la cendre automatiquement")
    _expect(trail.request_guidance(20.0), "Une demande explicite doit révéler un objectif valide")
    trail._process(1.0)
    var boss_snapshot: Dictionary = trail.snapshot()
    _expect(str(boss_snapshot.get("objective_kind", "")) == "boss", "Le runtime doit mémoriser le mode boss")
    _expect(bool(boss_snapshot.get("wisps_emitting", false)), "Les volutes doivent être émises lorsqu'un objectif existe")
    _expect(float(boss_snapshot.get("proximity", 0.0)) > 0.75, "La proximité de route doit piloter l'intensité du boss")

    trail.guide_to_world_position(Vector3(3.0, 0.0, 0.0), "quest", 48.0)
    _expect(not bool(trail.snapshot().get("wisps_emitting", true)), "Changer d’objectif doit masquer la cendre jusqu’à la prochaine demande")
    trail.request_guidance(20.0)
    trail.set_emotional_context(0.0, 0.0, 0.0)
    trail._process(1.0)
    var quest_snapshot: Dictionary = trail.snapshot()
    var quest_color: Color = quest_snapshot.get("color", Color.WHITE)
    var stable_direction: Vector3 = quest_snapshot.get("direction", Vector3.ZERO)
    _expect(str(quest_snapshot.get("objective_kind", "")) == "quest", "Un objectif de quête doit remplacer proprement le guidage boss")
    _expect(quest_color.b > quest_color.r, "Une quête proche doit tirer la cendre vers le bleu")

    trail.set_emotional_context(0.90, 0.0, 0.0)
    trail._process(1.0)
    var fearful: Dictionary = trail.snapshot()
    _expect(str(fearful.get("emotion", "")) == "fearful", "Une peur élevée doit rendre la cendre hésitante")
    _expect(float(fearful.get("fear", 0.0)) > 0.85, "La peur du groupe doit atteindre le directeur de cendres")
    _expect((fearful.get("direction", Vector3.ZERO) as Vector3).dot(stable_direction) > 0.99, "La peur ne doit pas inverser la direction de l'objectif")

    trail.set_emotional_context(0.0, 0.96, 0.0)
    trail._process(1.0)
    var danger: Dictionary = trail.snapshot()
    _expect(str(danger.get("emotion", "")) == "danger", "Un danger majeur doit produire un souffle brutal")
    _expect(float(danger.get("danger", 0.0)) > 0.90, "Le niveau de danger doit être conservé dans l'état visuel")
    _expect((danger.get("direction", Vector3.ZERO) as Vector3).dot(stable_direction) > 0.99, "Le danger ne doit pas détourner le guidage")

    trail.set_emotional_context(0.0, 0.0, 0.96)
    trail._process(1.0)
    var safe: Dictionary = trail.snapshot()
    _expect(str(safe.get("emotion", "")) == "safe", "Un lieu sûr doit apaiser le mouvement de la cendre")
    _expect(float(safe.get("safety", 0.0)) > 0.90, "Le contexte sûr doit atteindre le directeur de cendres")
    _expect((safe.get("direction", Vector3.ZERO) as Vector3).dot(stable_direction) > 0.99, "Le calme ne doit pas détourner le guidage")

    trail._process(21.0)
    var expired: Dictionary = trail.snapshot()
    _expect(not bool(expired.get("wisps_emitting", true)), "La cendre doit disparaître automatiquement à la fin de sa durée")

    trail.clear_emotional_overrides()
    trail.clear_guidance()
    var cleared: Dictionary = trail.snapshot()
    _expect(not bool(cleared.get("wisps_emitting", true)), "Effacer l'objectif doit arrêter les volutes")
    trail.queue_free()

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
