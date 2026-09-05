extends Node

const HEMOCORDE_KEY := "aisha_maren:hemocorde"
const HERO_STATE_KEY := "watcher_ultimate_state"

signal ultimate_resolved(hero_id: String, branch: String, result: Dictionary)

var encounter_serial := 0
var encounter_open := false
var encounter_signature := ""
var encounter_key := ""

func _ready() -> void:
    call_deferred("_connect_expedition_signals")

func _connect_expedition_signals() -> void:
    if ExpeditionManager == null:
        return
    if not ExpeditionManager.expedition_started.is_connected(_on_expedition_started):
        ExpeditionManager.expedition_started.connect(_on_expedition_started)
    if not ExpeditionManager.expedition_ended.is_connected(_on_expedition_ended):
        ExpeditionManager.expedition_ended.connect(_on_expedition_ended)

func _on_expedition_started(seed: int) -> void:
    encounter_serial = 0
    encounter_open = false
    encounter_signature = ""
    encounter_key = ""
    for hero_value: Variant in GameState.party:
        if hero_value is Dictionary and VeilleursSkillCatalog.is_watcher(hero_value):
            _reset_hero_run_state(hero_value, seed)

func _on_expedition_ended(_reason: String) -> void:
    end_encounter()

func begin_encounter(enemies: Array) -> String:
    var signature := _encounter_signature(enemies)
    if not encounter_open or signature != encounter_signature:
        encounter_serial += 1
        encounter_open = true
        encounter_signature = signature
        encounter_key = "%d:%d:%d:%s" % [int(ExpeditionManager.expedition_seed), int(GameState.expedition_room), encounter_serial, signature]
    return encounter_key

func end_encounter() -> void:
    encounter_open = false
    encounter_signature = ""
    encounter_key = ""

func status(hero: Dictionary, branch: String, target: Dictionary = {}, enemies: Array = []) -> Dictionary:
    var contract := VeilleursSkillResolverRouter.ultimate_contract(hero, branch)
    var ultimate: Dictionary = contract.get("ultimate", {})
    var result := {
        "available": false,
        "reason": "ultimate_unavailable",
        "hero_id": str(hero.get("id", "")),
        "branch": branch,
        "name": str(ultimate.get("name", "Ultime")),
        "charges_remaining": 0,
        "charges_max": 0,
        "encounter_key": encounter_key,
        "contract_status": str(contract.get("status", "required"))
    }
    if str(contract.get("status", "required")) != "implemented":
        result["reason"] = "ultimate_resolver_required"
        return result
    if str(hero.get("id", "")) != "aisha_maren" or branch != "hemocorde":
        result["reason"] = "ultimate_not_implemented_for_tree"
        return result
    if not ExpeditionManager.expedition_active:
        result["reason"] = "expedition_required"
        return result
    if int(hero.get("level", 1)) < 16:
        result["reason"] = "ultimate_level_locked"
        return result
    if str(hero.get("specialization", "")) != branch:
        result["reason"] = "wrong_specialization"
        return result

    var state := _ensure_hero_run_state(hero)
    var charges: Dictionary = state.get("charges", {})
    var max_charges: Dictionary = state.get("max_charges", {})
    result["charges_remaining"] = int(charges.get(branch, 0))
    result["charges_max"] = int(max_charges.get(branch, 0))
    if int(result.get("charges_remaining", 0)) <= 0:
        result["reason"] = "no_ultimate_charges"
        return result

    if not encounter_open:
        begin_encounter(enemies)
    result["encounter_key"] = encounter_key
    var used: Dictionary = state.get("encounters_used", {})
    if bool(used.get(_use_key(branch, encounter_key), false)):
        result["reason"] = "ultimate_already_used_this_encounter"
        return result
    if target.is_empty() or int(target.get("hp", 0)) <= 0:
        result["reason"] = "valid_target_required"
        return result

    if branch == "hemocorde":
        var physiology := VeilleursSkillResolverRouter.refresh_specialized_target(target)
        var known: Dictionary = target.get("vascular_known_parts", {})
        var hp_ratio := _hp_ratio(target)
        var shock := int(physiology.get("shock", target.get("circulatory_shock", 0)))
        var risk := int(physiology.get("hemorrhage_risk", target.get("hemorrhage_risk", 0)))
        var bleeding := int(target.get("bleeding", 0))
        var open_wounds := int(physiology.get("open_wounds", target.get("open_wound_count", 0)))
        result["physiology"] = {
            "known_parts": known.size(),
            "hp_ratio": hp_ratio,
            "shock": shock,
            "hemorrhage_risk": risk,
            "bleeding": bleeding,
            "open_wounds": open_wounds
        }
        if known.is_empty():
            result["reason"] = "vascular_knowledge_required"
            return result
        if shock < 2 or bleeding < 5 or risk < 5 or hp_ratio > 0.35:
            result["reason"] = "target_not_compromised_enough"
            return result

    result["available"] = true
    result["reason"] = "ready"
    return result

func resolve(hero: Dictionary, branch: String, target: Dictionary, enemies: Array = []) -> Dictionary:
    var check := status(hero, branch, target, enemies)
    if not bool(check.get("available", false)):
        return {"ok": false, "reason": str(check.get("reason", "ultimate_unavailable")), "status": check}
    if str(hero.get("id", "")) == "aisha_maren" and branch == "hemocorde":
        return _resolve_hemocorde(hero, target, check)
    return {"ok": false, "reason": "ultimate_not_implemented_for_tree"}

func _resolve_hemocorde(hero: Dictionary, target: Dictionary, check: Dictionary) -> Dictionary:
    AnatomyRuntime.ensure_state(target)
    var part_id := _best_known_vascular_part(target)
    if part_id == "":
        return {"ok": false, "reason": "vascular_knowledge_required"}

    var hp_before := int(target.get("hp", 0))
    var max_hp := maxi(1, int(target.get("max_hp", hp_before)))
    var bleeding_before := int(target.get("bleeding", 0))
    var shock_before := int(target.get("circulatory_shock", 0))
    var risk_before := int(target.get("hemorrhage_risk", 0))
    var open_wounds := int(target.get("open_wound_count", 0))
    var derived_damage := maxi(8, int(round(float(max_hp) * 0.12)) + shock_before * 2 + open_wounds)

    var attacker := hero.duplicate(true)
    attacker["precision"] = int(attacker.get("precision", 0)) + 20
    var anatomy_result := AnatomyRuntime.register_targeted_hit(attacker, target, "heavy", derived_damage, part_id, "ULT-AÏ-HÉM")
    var state := str(anatomy_result.get("state", target.get("anatomy_part_states", {}).get(part_id, "intact")))
    var functional_injury := InjuryRuntime.apply_if_needed(target, part_id, state)

    target["bleeding"] = maxi(bleeding_before + 2, int(target.get("bleeding", 0)))
    target["circulatory_collapse"] = true
    target["rhythm_disrupted_rounds"] = maxi(3, int(target.get("rhythm_disrupted_rounds", 0)))
    target["stunned"] = true

    var severe_terminal_state := shock_before >= 3 and bleeding_before >= 8 and _hp_ratio_before(hp_before, max_hp) <= 0.20
    var is_boss := bool(target.get("boss", false)) or bool(target.get("is_boss", false))
    var fatal_collapse := severe_terminal_state and not is_boss
    if fatal_collapse:
        target["hp"] = 0
    else:
        target["hp"] = maxi(1, int(target.get("hp", 0)) - derived_damage)
        if is_boss:
            target["hp"] = maxi(1, int(target.get("hp", 0)))
    var physiology_after := VeilleursSkillResolverRouter.refresh_specialized_target(target)

    var run_state := _ensure_hero_run_state(hero)
    var charges: Dictionary = run_state.get("charges", {})
    charges["hemocorde"] = maxi(0, int(charges.get("hemocorde", 0)) - 1)
    run_state["charges"] = charges
    var used: Dictionary = run_state.get("encounters_used", {})
    used[_use_key("hemocorde", encounter_key)] = true
    run_state["encounters_used"] = used
    hero[HERO_STATE_KEY] = run_state

    var result := {
        "ok": true,
        "hero_id": "aisha_maren",
        "branch": "hemocorde",
        "ultimate_name": "Le Dernier Battement",
        "part_id": part_id,
        "part_name": str(AnatomyRuntime.part_definition(target, part_id).get("name", part_id)),
        "hp_before": hp_before,
        "hp_after": int(target.get("hp", 0)),
        "bleeding_before": bleeding_before,
        "bleeding_after": int(target.get("bleeding", 0)),
        "shock_before": shock_before,
        "shock_after": int(physiology_after.get("shock", target.get("circulatory_shock", 0))),
        "hemorrhage_risk_before": risk_before,
        "hemorrhage_risk_after": int(physiology_after.get("hemorrhage_risk", target.get("hemorrhage_risk", 0))),
        "functional_injury": functional_injury,
        "circulatory_collapse": true,
        "fatal_collapse": fatal_collapse,
        "boss_floor_applied": is_boss and int(target.get("hp", 0)) >= 1,
        "charges_remaining": int(charges.get("hemocorde", 0)),
        "encounter_key": encounter_key,
        "presentation": {
            "sequence_id": "hemocorde_last_beat",
            "animation": "ultimate_hemocorde_last_beat",
            "camera": "vascular_focus_then_collapse",
            "audio": "hemocorde_last_beat",
            "haptic": "ultimate_impact_triplet",
            "beats": ["focus", "contact", "silence", "collapse"]
        }
    }
    ultimate_resolved.emit("aisha_maren", "hemocorde", result.duplicate(true))
    return result

func charges_remaining(hero: Dictionary, branch: String) -> int:
    if not ExpeditionManager.expedition_active:
        return 0
    var state := _ensure_hero_run_state(hero)
    return int((state.get("charges", {}) as Dictionary).get(branch, 0))

func _ensure_hero_run_state(hero: Dictionary) -> Dictionary:
    var seed := int(ExpeditionManager.expedition_seed)
    var state_value: Variant = hero.get(HERO_STATE_KEY, {})
    var state: Dictionary = state_value if state_value is Dictionary else {}
    if int(state.get("run_seed", -1)) != seed:
        state = _reset_hero_run_state(hero, seed)
    return state

func _reset_hero_run_state(hero: Dictionary, seed: int) -> Dictionary:
    var charges: Dictionary = {}
    var max_charges: Dictionary = {}
    var count := ExpeditionManager.ultimate_uses_for_level(int(hero.get("level", 1)))
    for branch: String in HeroSkillManager.branches_for(hero):
        charges[branch] = count
        max_charges[branch] = count
    var state := {
        "run_seed": seed,
        "charges": charges,
        "max_charges": max_charges,
        "encounters_used": {}
    }
    hero[HERO_STATE_KEY] = state
    return state

func _best_known_vascular_part(target: Dictionary) -> String:
    AnatomyRuntime.ensure_state(target)
    var known: Dictionary = target.get("vascular_known_parts", {})
    var best := ""
    var best_score := -1
    for part_value: Variant in AnatomyRuntime.targetable_parts(target):
        var part: Dictionary = part_value
        var part_id := str(part.get("id", ""))
        var entry_value: Variant = known.get(part_id, {})
        if not (entry_value is Dictionary):
            continue
        var certainty := int((entry_value as Dictionary).get("certainty", 0))
        if certainty <= 0:
            continue
        var score := certainty * 100 + int((target.get("anatomy_part_trauma", {}) as Dictionary).get(part_id, 0))
        if score > best_score:
            best_score = score
            best = part_id
    return best

func _encounter_signature(enemies: Array) -> String:
    var ids: Array[String] = []
    for enemy_value: Variant in enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        var identity := str(enemy.get("combat_uid", enemy.get("remanence_id", enemy.get("id", enemy.get("name", "enemy")))))
        if not ids.has(identity):
            ids.append(identity)
    ids.sort()
    return "+".join(ids)

func _use_key(branch: String, key: String) -> String:
    return "%s@%s" % [branch, key]

func _hp_ratio(target: Dictionary) -> float:
    return _hp_ratio_before(int(target.get("hp", 0)), maxi(1, int(target.get("max_hp", 1))))

func _hp_ratio_before(hp: int, max_hp: int) -> float:
    return float(hp) / float(maxi(1, max_hp))
