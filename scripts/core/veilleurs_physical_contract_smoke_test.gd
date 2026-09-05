extends Node

const PhysicalRules = preload("res://scripts/core/combat_physical_rules.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_disabled_limb_locks_only_required_skill()
    _test_construct_rejects_hemocord_bleeding()
    _test_dismemberment_requires_all_physical_conditions()
    _test_broken_armor_exposes_zone()
    _test_blunt_plate_transmits_trauma_without_perforation()
    await _test_fracture_roundtrip_preserves_context()
    _test_stabilization_stops_worsening_without_healing()
    _test_critical_extraction_requires_carrier_and_applies_penalties()
    _finish()

func _test_disabled_limb_locks_only_required_skill() -> void:
    var actor := {
        "id": "injured_actor",
        "hp": 20,
        "dismembered_parts": ["weapon_arm"],
        "critically_disabled_parts": []
    }
    var requiring_arm := {"id": "weapon_cut", "required_parts": ["weapon_arm"], "effect": "attack"}
    var independent := {"id": "voice_order", "required_parts": [], "effect": "support"}
    var blocked := PhysicalRules.skill_availability(actor, requiring_arm)
    var usable := PhysicalRules.skill_availability(actor, independent)
    _check(not bool(blocked.get("usable", true)), "Tests_48/T07 : une compétence exigeant le membre hors fonction doit être indisponible")
    _check(str(blocked.get("reason", "")) == "required_function_unavailable", "Tests_48/T07 : le verrou doit expliquer la fonction corporelle manquante")
    _check(bool(usable.get("usable", false)), "Tests_48/T07 : une compétence indépendante du membre perdu doit rester jouable")

func _test_construct_rejects_hemocord_bleeding() -> void:
    var construct := {"id": "construct", "physiology": "construct", "hp": 30}
    var result := PhysicalRules.physiology_compatibility(construct, ["hémocorde", "hemorrhage", "bleed"])
    _check(not bool(result.get("allowed", true)), "Tests_48/T08 : un Construct ne doit pas recevoir saignement/hémorragie par Hémocorde")
    _check(is_zero_approx(float(result.get("multiplier", 1.0))), "Tests_48/T08 : l'effet sanguin incompatible doit être annulé plutôt que simulé comme une vraie hémorragie")
    var organic := {"id": "organic", "physiology": "organic", "hp": 30}
    _check(bool(PhysicalRules.physiology_compatibility(organic, "bleed").get("allowed", false)), "Tests_48/T08 : la règle physiologique ne doit pas désactiver le saignement sur une cible organique compatible")

func _test_dismemberment_requires_all_physical_conditions() -> void:
    var part := {"id": "weapon_arm", "severable": true, "finisher_only": false, "tags": ["weapon"]}
    var valid_context := {
        "impact_type": "cutting",
        "target_zone": "weapon_arm",
        "energy": "high",
        "required_energy": "high",
        "severity": "critical",
        "gravity_compatible": true,
        "angle_compatible": true
    }
    _check(bool(PhysicalRules.dismemberment_compatibility(part, valid_context).get("allowed", false)), "Tests_48/T09 : impact, zone, énergie et gravité compatibles doivent autoriser le démembrement")

    var wrong_impact := valid_context.duplicate(true)
    wrong_impact["impact_type"] = "piercing"
    _check(not bool(PhysicalRules.dismemberment_compatibility(part, wrong_impact).get("allowed", true)), "Tests_48/T09 : un impact incompatible doit interdire le démembrement")
    var wrong_zone := valid_context.duplicate(true)
    wrong_zone["target_zone"] = "support_leg"
    _check(not bool(PhysicalRules.dismemberment_compatibility(part, wrong_zone).get("allowed", true)), "Tests_48/T09 : une zone différente doit interdire le démembrement de ce membre")
    var weak_energy := valid_context.duplicate(true)
    weak_energy["energy"] = "low"
    _check(not bool(PhysicalRules.dismemberment_compatibility(part, weak_energy).get("allowed", true)), "Tests_48/T09 : une énergie insuffisante doit interdire le démembrement")
    var bad_gravity := valid_context.duplicate(true)
    bad_gravity["gravity_compatible"] = false
    _check(not bool(PhysicalRules.dismemberment_compatibility(part, bad_gravity).get("allowed", true)), "Tests_48/T09 : une configuration de gravité incompatible doit interdire le démembrement")

func _test_broken_armor_exposes_zone() -> void:
    var plate := {
        "id": "chest_plate",
        "zones": ["torso"],
        "material": "plate",
        "protection": 30.0,
        "durability": 1,
        "max_durability": 20,
        "state": "intact"
    }
    var first_hit := PhysicalRules.resolve_localized_armor_hit(plate, {"zone": "torso", "impact_type": "cutting", "energy": 10.0, "durability_factor": 1.0})
    _check(bool(first_hit.get("broken_after", false)), "Tests_48/T10 : une pièce dont la durabilité tombe à zéro doit passer à l'état brisé")
    _check(bool(first_hit.get("exposed", false)), "Tests_48/T10 : la zone doit devenir exposée dès que la pièce est brisée")
    var broken_piece: Dictionary = first_hit.get("armor_after", {})
    var second_hit := PhysicalRules.resolve_localized_armor_hit(broken_piece, {"zone": "torso", "impact_type": "cutting", "energy": 10.0})
    _check(bool(second_hit.get("broken_before", false)), "Tests_48/T10 : l'état brisé doit être relu au coup suivant")
    _check(is_zero_approx(float(second_hit.get("absorbed", -1.0))), "Tests_48/T10 : une armure brisée ne doit pas continuer à absorber à pleine valeur")

func _test_blunt_plate_transmits_trauma_without_perforation() -> void:
    var plate := {
        "id": "test_plate",
        "zones": ["torso"],
        "material": "plate",
        "protection": 100.0,
        "durability": 100,
        "max_durability": 100
    }
    var result := PhysicalRules.resolve_localized_armor_hit(plate, {"zone": "torso", "impact_type": "blunt", "energy": 50.0})
    _check(not bool(result.get("perforated", true)), "Tests_48/T11 : un choc contondant modéré sur plaque ne doit pas exiger de perforation")
    _check(float(result.get("trauma_transmitted", 0.0)) > 0.0, "Tests_48/T11 : la plaque doit pouvoir transmettre du trauma au corps malgré l'absence de perforation")
    _check(float(result.get("absorbed", 0.0)) > 0.0, "Tests_48/T11 : une partie de l'énergie doit néanmoins être absorbée par la plaque")

func _test_fracture_roundtrip_preserves_context() -> void:
    GameState.reset_new_game()
    await get_tree().process_frame
    _check(not GameState.party.is_empty(), "Tests_48/T12 : le round-trip nécessite au moins un Veilleur")
    if GameState.party.is_empty():
        return
    var hero: Dictionary = GameState.party[0]
    PersistentInjuryRuntime.prepare_character(hero)
    var applied := PersistentInjuryRuntime.apply_injury(hero, "fracture_leg", "critical", {
        "zone": "support_leg",
        "treatment": "splinted",
        "sequela": "limited_stride",
        "cause": "crushing_impact"
    })
    _check(not applied.is_empty(), "Tests_48/T12 : la fracture persistante doit être créée")

    var slot := 2
    SaveManager.delete_slot(slot)
    _check(SaveManager.save_game(slot), "Tests_48/T12 : le snapshot contenant la fracture doit être sauvegardable")
    hero["persistent_injuries"] = []
    _check(SaveManager.load_game(slot), "Tests_48/T12 : le snapshot de fracture doit être rechargeable")
    var restored: Dictionary = GameState.party[0]
    var injuries: Array = restored.get("persistent_injuries", [])
    _check(not injuries.is_empty(), "Tests_48/T12 : la fracture doit survivre au rechargement")
    if not injuries.is_empty():
        var fracture: Dictionary = injuries[0]
        _check(str(fracture.get("id", "")) == "fracture_leg", "Tests_48/T12 : l'identité de la fracture doit rester identique")
        _check(str(fracture.get("zone", "")) == "support_leg", "Tests_48/T12 : la zone de fracture doit être conservée")
        _check(str(fracture.get("severity", "")) == "critical", "Tests_48/T12 : la gravité doit être conservée")
        _check(str(fracture.get("treatment", "")) == "splinted", "Tests_48/T12 : le traitement doit être conservé")
        _check(str(fracture.get("sequela", "")) == "limited_stride", "Tests_48/T12 : la séquelle doit être conservée")
    SaveManager.delete_slot(slot)

func _test_stabilization_stops_worsening_without_healing() -> void:
    var patient := {"id": "stabilized_patient", "hp": 12, "max_hp": 20, "persistent_injuries": []}
    var injury := PersistentInjuryRuntime.apply_injury(patient, "fracture_leg", "serious", {"zone": "support_leg"})
    _check(not injury.is_empty(), "Tests_48/T13 : une fracture sérieuse doit pouvoir être créée")
    _check(PersistentInjuryRuntime.stabilize_in_field(patient, "fracture_leg"), "Tests_48/T13 : la fracture doit pouvoir être stabilisée sur le terrain")
    for _index in range(4):
        PersistentInjuryRuntime.close_expedition([patient])
    var injuries: Array = patient.get("persistent_injuries", [])
    _check(injuries.size() == 1, "Tests_48/T13 : stabiliser ne doit pas guérir ni supprimer la lésion")
    if injuries.size() == 1:
        var stabilized: Dictionary = injuries[0]
        _check(str(stabilized.get("severity", "")) == "serious", "Tests_48/T13 : une fracture stabilisée ne doit pas s'aggraver en critique")
        _check(bool(stabilized.get("stabilized", false)), "Tests_48/T13 : le marqueur de stabilisation doit persister")
        _check(str(stabilized.get("treatment", "")) == "field_stabilized", "Tests_48/T13 : le traitement doit indiquer la stabilisation plutôt qu'une guérison")

func _test_critical_extraction_requires_carrier_and_applies_penalties() -> void:
    var patient := {"id": "critical_patient", "hp": 4, "max_hp": 20, "persistent_injuries": []}
    PersistentInjuryRuntime.apply_injury(patient, "fracture_leg", "critical", {"zone": "support_leg"})
    var carrier := {"id": "carrier", "hp": 20, "max_hp": 20}
    var applied := PersistentInjuryRuntime.apply_critical_extraction_carry(patient, carrier)
    _check(bool(applied.get("ok", false)), "Tests_48/T14 : un allié valide doit pouvoir porter le blessé critique vers l'extraction")
    _check(bool(patient.get("being_carried", false)) and bool(patient.get("actions_locked", false)), "Tests_48/T14 : le blessé critique porté doit rester attaché au porteur et ne pas agir normalement")
    _check(str(patient.get("carried_by", "")) == "carrier", "Tests_48/T14 : l'identité du porteur doit être explicite")
    var penalties: Dictionary = carrier.get("carry_penalties", {})
    _check(float(penalties.get("movement_speed", 0.0)) < 0.0, "Tests_48/T14 : le portage doit appliquer une pénalité de mobilité")
    _check(int(penalties.get("rank_change_cost", 0)) > 0, "Tests_48/T14 : le portage doit augmenter le coût de repositionnement")
    var invalid_carrier := {"id": "downed_carrier", "hp": 0, "max_hp": 20}
    _check(not bool(PersistentInjuryRuntime.critical_extraction_plan(patient, invalid_carrier).get("ok", true)), "Tests_48/T14 : un allié hors combat ne doit pas pouvoir porter le blessé")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_PHYSICAL_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_PHYSICAL_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_PHYSICAL_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
