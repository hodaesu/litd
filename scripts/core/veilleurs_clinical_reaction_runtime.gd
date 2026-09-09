extends Node

const mathilde_RETURN_BLADE := "MA-ENT-04"
const mathilde_SWEEP_REACTION := "MA-ENT-13"
const aurelien_DEFLECTION := "AU-ANA-04"
const aurelien_MUSCLE_REFLEX := "AU-ANA-13"
const aurelien_REFLEX_HAND := "AU-SUT-04"
const aurelien_IMMEDIATE_INTERVENTION := "AU-SUT-13"
const aurelien_BLOOD_RETURN := "AÏ-HÉM-04"
const aurelien_REFLEX_POINT := "AÏ-HÉM-13"

signal reaction_resolved(actor_id: String, skill_id: String, result: Dictionary)

func refresh_passive_states(party: Array, enemies: Array) -> void:
    var Mathilde := _hero(party, "Mathilde")
    if not Mathilde.is_empty():
        Mathilde["entaille_bleed_maintenance"] = _has_skill(Mathilde, "MA-ENT-03")
        Mathilde["entaille_injured_precision"] = _has_skill(Mathilde, "MA-ENT-07")
        Mathilde["entaille_mobility_priority"] = _has_skill(Mathilde, "MA-ENT-11")
        Mathilde["entaille_weakness_hunter"] = _has_skill(Mathilde, "MA-ENT-15")
        if bool(Mathilde.get("entaille_weakness_hunter", false)):
            for enemy_value: Variant in enemies:
                if enemy_value is Dictionary:
                    var enemy: Dictionary = enemy_value
                    var weak_part := _most_injured_part(enemy)
                    if weak_part != "":
                        enemy["mathilde_auto_weakness_part"] = weak_part

    var Aurélien := _hero(party, "Aurélien")
    if Aurélien.is_empty():
        return
    Aurélien["anatomy_precision_passive"] = _has_skill(Aurélien, "AU-ANA-03")
    Aurélien["anatomy_bestiarity_passive"] = _has_skill(Aurélien, "AU-ANA-07")
    Aurélien["anatomy_locomotor_priority"] = _has_skill(Aurélien, "AU-ANA-11")
    Aurélien["all_wounds_speak"] = _has_skill(Aurélien, "AU-ANA-15")
    Aurélien["field_stabilization_passive"] = _has_skill(Aurélien, "AU-SUT-03")
    Aurélien["material_saving_passive"] = _has_skill(Aurélien, "AU-SUT-07")
    Aurélien["function_preservation_passive"] = _has_skill(Aurélien, "AU-SUT-11")
    Aurélien["war_medicine_active"] = _has_skill(Aurélien, "AU-SUT-15")

    if bool(Aurélien.get("all_wounds_speak", false)):
        for enemy_value: Variant in enemies:
            if enemy_value is Dictionary:
                _reveal_visible_lesions(Aurélien, enemy_value)
    if bool(Aurélien.get("war_medicine_active", false)):
        for ally_value: Variant in party:
            if ally_value is Dictionary:
                var ally: Dictionary = ally_value
                ally["war_medicine_priority_score"] = _medical_priority_score(ally)

func before_enemy_damage(enemy: Dictionary, target: Dictionary, damage: int, round_index: int, party: Array) -> Dictionary:
    var result := {"damage": maxi(1, damage), "reaction": {}}
    var Aurélien := _hero(party, "Aurélien")
    if Aurélien.is_empty() or not _reaction_available(Aurélien, round_index) or not _adjacent(Aurélien, target):
        return result

    var current_ratio := _hp_ratio(target)
    var projected_hp := maxi(0, int(target.get("hp", 0)) - damage)
    var projected_ratio := float(projected_hp) / float(maxi(1, int(target.get("max_hp", 1))))
    # L'urgence médicale conserve la réaction d'Aurélien pour l'après-impact.
    if _has_skill(Aurélien, aurelien_IMMEDIATE_INTERVENTION) and current_ratio > 0.25 and projected_ratio <= 0.25:
        return result
    if not _has_skill(Aurélien, aurelien_DEFLECTION):
        return result

    var prevented := clampi(int(round(float(damage) * 0.25)), 1, 6)
    result["damage"] = maxi(1, damage - prevented)
    var reaction := {
        "ok": true,
        "actor_id": "Aurélien",
        "skill_id": aurelien_DEFLECTION,
        "target_id": str(target.get("id", "")),
        "enemy_id": str(enemy.get("id", "")),
        "prevented_damage": prevented,
        "round": round_index
    }
    _consume_reaction(Aurélien, round_index, aurelien_DEFLECTION)
    result["reaction"] = reaction
    reaction_resolved.emit("Aurélien", aurelien_DEFLECTION, reaction.duplicate(true))
    return result

func after_enemy_hit(enemy: Dictionary, target: Dictionary, hp_before: int, bleeding_before: int, round_index: int, party: Array) -> Dictionary:
    var Aurélien := _hero(party, "Aurélien")
    if Aurélien.is_empty() or not _reaction_available(Aurélien, round_index) or not _adjacent(Aurélien, target):
        return {}

    var hp_after := int(target.get("hp", 0))
    var max_hp := maxi(1, int(target.get("max_hp", 1)))
    var crossed_critical := hp_before > int(round(float(max_hp) * 0.25)) and hp_after <= int(round(float(max_hp) * 0.25)) and hp_after > 0
    if crossed_critical and _has_skill(Aurélien, aurelien_IMMEDIATE_INTERVENTION):
        var injury_id := _stabilize_best_injury(target)
        var bleed_before_reaction := int(target.get("bleeding", 0))
        target["bleeding"] = maxi(0, bleed_before_reaction - (4 if _has_skill(Aurélien, "AU-SUT-03") else 3))
        target["transportable"] = true
        if _has_skill(Aurélien, "AU-SUT-11"):
            target["function_preserved_until_rest"] = true
        var critical_result := {
            "ok": true,
            "actor_id": "Aurélien",
            "skill_id": aurelien_IMMEDIATE_INTERVENTION,
            "target_id": str(target.get("id", "")),
            "enemy_id": str(enemy.get("id", "")),
            "stabilized_injury": injury_id,
            "bleeding_before": bleed_before_reaction,
            "bleeding_after": int(target.get("bleeding", 0)),
            "round": round_index
        }
        _consume_reaction(Aurélien, round_index, aurelien_IMMEDIATE_INTERVENTION)
        reaction_resolved.emit("Aurélien", aurelien_IMMEDIATE_INTERVENTION, critical_result.duplicate(true))
        return critical_result

    var bleeding_after := int(target.get("bleeding", 0))
    if bleeding_after - bleeding_before >= 3 and _has_skill(Aurélien, aurelien_REFLEX_HAND):
        var reduction := 3 if _has_skill(Aurélien, "AU-SUT-03") else 2
        target["bleeding"] = maxi(0, bleeding_after - reduction)
        var injury_id := _stabilize_best_injury(target)
        if _has_skill(Aurélien, "AU-SUT-11"):
            target["function_preserved_until_rest"] = true
        var hemorrhage_result := {
            "ok": true,
            "actor_id": "Aurélien",
            "skill_id": aurelien_REFLEX_HAND,
            "target_id": str(target.get("id", "")),
            "enemy_id": str(enemy.get("id", "")),
            "stabilized_injury": injury_id,
            "bleeding_before": bleeding_after,
            "bleeding_after": int(target.get("bleeding", 0)),
            "round": round_index
        }
        _consume_reaction(Aurélien, round_index, aurelien_REFLEX_HAND)
        reaction_resolved.emit("Aurélien", aurelien_REFLEX_HAND, hemorrhage_result.duplicate(true))
        return hemorrhage_result
    return {}

# Hémocorde : réaction générique de fin d'action. Elle n'est tentée qu'après
# les réactions médicales et les ouvertures de mouvement, afin qu'une urgence
# ou Pointe réflexe garde la priorité sur Retour sanguin.
func after_enemy_action(enemy: Dictionary, target: Dictionary, round_index: int, party: Array) -> Dictionary:
    var Aurélien := _hero(party, "Aurélien")
    if Aurélien.is_empty() or int(enemy.get("hp", 0)) <= 0:
        return {}
    if not _has_skill(Aurélien, aurelien_BLOOD_RETURN) or not _reaction_available(Aurélien, round_index):
        return {}
    if int(enemy.get("bleeding", 0)) <= 0 or not _adjacent(Aurélien, target):
        return {}

    AnatomyRuntime.ensure_state(enemy)
    var part := _known_vascular_part(enemy)
    if part == "":
        # Le saignement visible fournit un indice local, mais pas une carte vasculaire omnisciente.
        part = _preferred_close_part(enemy)
    if part == "":
        return {}

    var damage := maxi(3, 3 + int(Aurélien.get("level", 1)) / 15)
    var bleeding_before_enemy := int(enemy.get("bleeding", 0))
    enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
    var anatomy_result := AnatomyRuntime.register_targeted_hit(Aurélien, enemy, "technique", damage, part, aurelien_BLOOD_RETURN)
    enemy["bleeding"] = bleeding_before_enemy + 1
    var circulation := VeilleursSkillResolverRouter.refresh_specialized_target(enemy)
    var result := {
        "ok": true,
        "actor_id": "Aurélien",
        "skill_id": aurelien_BLOOD_RETURN,
        "target_id": str(target.get("id", "")),
        "enemy_id": str(enemy.get("id", "")),
        "damage": damage,
        "part_id": str(anatomy_result.get("part_id", part)),
        "bleeding_before": bleeding_before_enemy,
        "bleeding_after": int(enemy.get("bleeding", 0)),
        "circulatory_shock": int(circulation.get("shock", enemy.get("circulatory_shock", 0))),
        "round": round_index
    }
    _consume_reaction(Aurélien, round_index, aurelien_BLOOD_RETURN)
    reaction_resolved.emit("Aurélien", aurelien_BLOOD_RETURN, result.duplicate(true))
    return result

func on_enemy_miss(enemy: Dictionary, target: Dictionary, round_index: int, party: Array) -> Dictionary:
    if str(target.get("id", "")) != "Mathilde":
        return {}
    var Mathilde := _hero(party, "Mathilde")
    if Mathilde.is_empty() or not _has_skill(Mathilde, mathilde_RETURN_BLADE) or not _reaction_available(Mathilde, round_index):
        return {}
    var damage := maxi(3, 3 + int(Mathilde.get("level", 1)) / 12)
    enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
    AnatomyRuntime.ensure_state(enemy)
    var part := _preferred_close_part(enemy)
    var anatomy_result := {}
    if part != "":
        anatomy_result = AnatomyRuntime.register_targeted_hit(Mathilde, enemy, "technique", damage, part, mathilde_RETURN_BLADE)
        enemy["bleeding"] = int(enemy.get("bleeding", 0)) + 1
    var result := {
        "ok": true,
        "actor_id": "Mathilde",
        "skill_id": mathilde_RETURN_BLADE,
        "enemy_id": str(enemy.get("id", "")),
        "damage": damage,
        "part_id": str(anatomy_result.get("part_id", part)),
        "round": round_index
    }
    _consume_reaction(Mathilde, round_index, mathilde_RETURN_BLADE)
    reaction_resolved.emit("Mathilde", mathilde_RETURN_BLADE, result.duplicate(true))
    return result

func on_enemy_movement(enemy: Dictionary, position_before: int, position_after: int, round_index: int, party: Array) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    if position_before == position_after or int(enemy.get("hp", 0)) <= 0:
        return results

    var Mathilde := _hero(party, "Mathilde")
    if not Mathilde.is_empty() and _has_skill(Mathilde, mathilde_SWEEP_REACTION) and _reaction_available(Mathilde, round_index):
        var damage := maxi(4, 4 + int(Mathilde.get("level", 1)) / 10)
        enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
        var part := _preferred_close_part(enemy)
        if part != "":
            AnatomyRuntime.register_targeted_hit(Mathilde, enemy, "technique", damage, part, mathilde_SWEEP_REACTION)
            enemy["bleeding"] = int(enemy.get("bleeding", 0)) + 1
        var mathilde_result := {
            "ok": true,
            "actor_id": "Mathilde",
            "skill_id": mathilde_SWEEP_REACTION,
            "enemy_id": str(enemy.get("id", "")),
            "damage": damage,
            "position_before": position_before,
            "position_after": position_after,
            "round": round_index
        }
        _consume_reaction(Mathilde, round_index, mathilde_SWEEP_REACTION)
        reaction_resolved.emit("Mathilde", mathilde_SWEEP_REACTION, mathilde_result.duplicate(true))
        results.append(mathilde_result)

    var Aurélien := _hero(party, "Aurélien")
    if Aurélien.is_empty() or not _reaction_available(Aurélien, round_index) or int(enemy.get("hp", 0)) <= 0:
        return results

    # Pointe réflexe est plus spécifique que Réflexe musculaire : si une zone
    # vasculaire connue devient brièvement accessible au premier plan, elle a priorité.
    if _has_skill(Aurélien, aurelien_REFLEX_POINT) and mini(position_before, position_after) <= 1:
        AnatomyRuntime.ensure_state(enemy)
        var vascular_part := _known_vascular_part(enemy)
        if vascular_part != "":
            var damage := maxi(5, 5 + int(Aurélien.get("level", 1)) / 12)
            var bleeding_before_enemy := int(enemy.get("bleeding", 0))
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
            var anatomy_result := AnatomyRuntime.register_targeted_hit(Aurélien, enemy, "technique", damage, vascular_part, aurelien_REFLEX_POINT)
            enemy["bleeding"] = bleeding_before_enemy + 1
            var circulation := VeilleursSkillResolverRouter.refresh_specialized_target(enemy)
            var point_result := {
                "ok": true,
                "actor_id": "Aurélien",
                "skill_id": aurelien_REFLEX_POINT,
                "enemy_id": str(enemy.get("id", "")),
                "damage": damage,
                "part_id": str(anatomy_result.get("part_id", vascular_part)),
                "bleeding_before": bleeding_before_enemy,
                "bleeding_after": int(enemy.get("bleeding", 0)),
                "circulatory_shock": int(circulation.get("shock", enemy.get("circulatory_shock", 0))),
                "position_before": position_before,
                "position_after": position_after,
                "round": round_index
            }
            _consume_reaction(Aurélien, round_index, aurelien_REFLEX_POINT)
            reaction_resolved.emit("Aurélien", aurelien_REFLEX_POINT, point_result.duplicate(true))
            results.append(point_result)

    if _reaction_available(Aurélien, round_index) and _has_skill(Aurélien, aurelien_MUSCLE_REFLEX):
        AnatomyRuntime.ensure_state(enemy)
        var locomotor_part := _part_with_any_tag(enemy, ["mobility", "support", "anchor"])
        if locomotor_part == "":
            locomotor_part = _preferred_close_part(enemy)
        var anatomy_result := {}
        if locomotor_part != "":
            anatomy_result = AnatomyRuntime.register_targeted_hit(Aurélien, enemy, "technique", 6, locomotor_part, aurelien_MUSCLE_REFLEX)
            var state := str(anatomy_result.get("state", enemy.get("anatomy_part_states", {}).get(locomotor_part, "intact")))
            InjuryRuntime.apply_if_needed(enemy, locomotor_part, state)
        var aurelien_result := {
            "ok": true,
            "actor_id": "Aurélien",
            "skill_id": aurelien_MUSCLE_REFLEX,
            "enemy_id": str(enemy.get("id", "")),
            "part_id": locomotor_part,
            "position_before": position_before,
            "position_after": position_after,
            "round": round_index
        }
        _consume_reaction(Aurélien, round_index, aurelien_MUSCLE_REFLEX)
        reaction_resolved.emit("Aurélien", aurelien_MUSCLE_REFLEX, aurelien_result.duplicate(true))
        results.append(aurelien_result)
    return results

func advance_round_state(party: Array) -> void:
    for hero_value: Variant in party:
        if not (hero_value is Dictionary):
            continue
        var hero: Dictionary = hero_value
        for key in ["predator_posture_rounds", "clinical_posture_rounds", "triage_posture_rounds"]:
            if int(hero.get(key, 0)) > 0:
                hero[key] = maxi(0, int(hero.get(key, 0)) - 1)
        if int(hero.get("predator_posture_rounds", 0)) <= 0:
            hero.erase("predator_defense_penalty")
        if int(hero.get("clinical_posture_rounds", 0)) <= 0:
            hero.erase("clinical_defense_penalty")
        if int(hero.get("triage_posture_rounds", 0)) <= 0:
            hero.erase("medical_priority_auto")
        for injury_value: Variant in hero.get("persistent_injuries", []):
            if injury_value is Dictionary and int((injury_value as Dictionary).get("protected_rounds", 0)) > 0:
                (injury_value as Dictionary)["protected_rounds"] = maxi(0, int((injury_value as Dictionary).get("protected_rounds", 0)) - 1)

func _consume_reaction(actor: Dictionary, round_index: int, skill_id: String) -> void:
    actor["clinical_reaction_round_used"] = round_index
    actor["clinical_reaction_skill_used"] = skill_id

func _reaction_available(actor: Dictionary, round_index: int) -> bool:
    return int(actor.get("hp", 0)) > 0 and int(actor.get("clinical_reaction_round_used", -1)) != round_index

func _hero(party: Array, hero_id: String) -> Dictionary:
    for value: Variant in party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == hero_id:
            return value
    return {}

func _has_skill(hero: Dictionary, skill_id: String) -> bool:
    return (hero.get("unlocked_skills", []) as Array).has(skill_id)

func _adjacent(Aurélien: Dictionary, target: Dictionary) -> bool:
    if str(Aurélien.get("id", "")) == str(target.get("id", "")):
        return true
    return absi(int(Aurélien.get("combat_position", 0)) - int(target.get("combat_position", 0))) <= 1

func _hp_ratio(character: Dictionary) -> float:
    return float(character.get("hp", 0)) / float(maxi(1, int(character.get("max_hp", 1))))

func _medical_priority_score(character: Dictionary) -> int:
    var score := int(character.get("bleeding", 0)) * 12
    var max_hp := maxi(1, int(character.get("max_hp", 1)))
    score += int(round((1.0 - float(character.get("hp", max_hp)) / float(max_hp)) * 30.0))
    for injury_value: Variant in character.get("persistent_injuries", []):
        if injury_value is Dictionary:
            score += {"minor": 10, "serious": 25, "critical": 50}.get(str((injury_value as Dictionary).get("severity", "minor")), 5)
    return score

func _stabilize_best_injury(patient: Dictionary) -> String:
    PersistentInjuryRuntime.prepare_character(patient)
    var best_id := ""
    var best_rank := -1
    for injury_value: Variant in patient.get("persistent_injuries", []):
        if not (injury_value is Dictionary):
            continue
        var injury: Dictionary = injury_value
        if bool(injury.get("stabilized", false)):
            continue
        var rank := int({"minor": 1, "serious": 2, "critical": 3}.get(str(injury.get("severity", "minor")), 0))
        if rank > best_rank:
            best_rank = rank
            best_id = str(injury.get("id", ""))
    if best_id != "":
        PersistentInjuryRuntime.stabilize_in_field(patient, best_id)
    return best_id

func _reveal_visible_lesions(Aurélien: Dictionary, enemy: Dictionary) -> void:
    AnatomyRuntime.ensure_state(enemy)
    var diagnostics: Dictionary = enemy.get("aurelien_diagnostics", {})
    for part_value: Variant in AnatomyRuntime.targetable_parts(enemy):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        var state := str(enemy.get("anatomy_part_states", {}).get(part_id, "intact"))
        if state == "intact" and int(enemy.get("anatomy_part_trauma", {}).get(part_id, 0)) <= 0:
            continue
        diagnostics[part_id] = {
            "certainty": 3,
            "state": state,
            "functional": InjuryRuntime.part_functional(enemy, part_id),
            "consequence": str(part.get("consequence", "")),
            "observer_id": "Aurélien",
            "transformation": "AU-ANA-15",
            "run_index": RemanenceRuntime.run_index
        }
    enemy["aurelien_diagnostics"] = diagnostics

func _most_injured_part(enemy: Dictionary) -> String:
    AnatomyRuntime.ensure_state(enemy)
    var best := ""
    var best_score := 0
    for part_value: Variant in AnatomyRuntime.targetable_parts(enemy):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        var score := int(enemy.get("anatomy_part_trauma", {}).get(part_id, 0))
        score += {"injured": 100, "critical": 250}.get(str(enemy.get("anatomy_part_states", {}).get(part_id, "intact")), 0)
        if score > best_score:
            best_score = score
            best = part_id
    return best

func _known_vascular_part(enemy: Dictionary) -> String:
    AnatomyRuntime.ensure_state(enemy)
    var known: Dictionary = enemy.get("vascular_known_parts", {})
    var best := ""
    var best_score := -1
    for part_value: Variant in AnatomyRuntime.targetable_parts(enemy):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        var entry_value: Variant = known.get(part_id, {})
        if not (entry_value is Dictionary):
            continue
        var certainty := int((entry_value as Dictionary).get("certainty", 0))
        if certainty <= 0:
            continue
        var score := certainty * 100 + int(enemy.get("anatomy_part_trauma", {}).get(part_id, 0))
        if score > best_score:
            best_score = score
            best = part_id
    return best

func _preferred_close_part(enemy: Dictionary) -> String:
    var part := _part_with_any_tag(enemy, ["mobility", "attack", "support"])
    if part != "":
        return part
    var parts := AnatomyRuntime.targetable_parts(enemy)
    return str((parts[0] as Dictionary).get("id", "")) if not parts.is_empty() else ""

func _part_with_any_tag(enemy: Dictionary, wanted: Array) -> String:
    AnatomyRuntime.ensure_state(enemy)
    for part_value: Variant in AnatomyRuntime.targetable_parts(enemy):
        var part: Dictionary = part_value
        for tag_value: Variant in part.get("tags", []):
            if wanted.has(str(tag_value)):
                return str(part.get("id", ""))
    return ""
