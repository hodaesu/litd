extends RefCounted
class_name VeilleursHeroRecruitmentService

const RULES_PATH := "res://data/economy/sanctuary_economy_rules.json"

var rules: Dictionary = {}

func _init() -> void:
    _load_rules()

func _load_rules() -> void:
    if not FileAccess.file_exists(RULES_PATH):
        push_error("VeilleursHeroRecruitmentService: missing economy rules")
        rules = {}
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        rules = (parsed as Dictionary).get("hero_recruitment", {}).duplicate(true)

func generate_candidates(seed_value: int, count: int = -1) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if DataLoader.heroes.is_empty():
        return result
    var candidate_count := count if count > 0 else int(rules.get("candidate_count", 3))
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    for index in range(candidate_count):
        var template: Dictionary = DataLoader.heroes[rng.randi_range(0, DataLoader.heroes.size() - 1)]
        result.append(_build_candidate(template, seed_value, index))
    return result

func generate_replacement_candidates(dead_hero_id: String, seed_value: int, count: int = -1) -> Array[Dictionary]:
    var dead_index := _dead_hero_index(dead_hero_id)
    if dead_index < 0:
        return []
    var fallen: Dictionary = GameState.party[dead_index]
    var class_id := str(fallen.get("class_id", ""))
    var template: Dictionary = {}
    for hero_value in DataLoader.heroes:
        var hero: Dictionary = hero_value
        if str(hero.get("class_id", "")) == class_id:
            template = hero
            break
    if template.is_empty():
        return []
    var result: Array[Dictionary] = []
    var candidate_count := count if count > 0 else int(rules.get("candidate_count", 3))
    for index in range(candidate_count):
        result.append(_build_candidate(template, seed_value, index))
    return result

func _build_candidate(template: Dictionary, seed_value: int, index: int) -> Dictionary:
    var names: Array = rules.get("names", [])
    var base_id := str(template.get("id", "hero"))
    var name := "Recrue %d" % (index + 1)
    if not names.is_empty():
        name = str(names[(abs(seed_value) + index) % names.size()])
    var target_level := maxi(1, _average_alive_level() - int(rules.get("catchup_level_lag", 2)))
    var candidate := template.duplicate(true)
    candidate["id"] = "recruit_%s_%d_%d" % [base_id, abs(seed_value), index]
    candidate["canonical_id"] = str(candidate["id"])
    candidate["name"] = name
    candidate["level"] = target_level
    candidate["xp"] = 0
    candidate["skill_points"] = 0
    candidate["specialization"] = ""
    candidate["unlocked_skills"] = []
    candidate["combat_loadout"] = []
    candidate["player_owned"] = true
    candidate["recruit_generation"] = 1
    candidate["recruit_origin"] = "sanctuary_tavern"
    HeroSkillManager.prepare_hero(candidate)
    CharacterTraitDirector.prepare_character(candidate, str(candidate["id"]))
    EnemyFearDirector.prepare_hero(candidate)
    PersistentInjuryRuntime.prepare_character(candidate)
    candidate["hp"] = int(candidate.get("max_hp", candidate.get("hp", 1)))
    return {
        "candidate": candidate,
        "cost": recruitment_cost(candidate),
        "class_id": str(candidate.get("class_id", "")),
        "level": int(candidate.get("level", 1)),
        "name": str(candidate.get("name", "Recrue"))
    }

func recruitment_cost(candidate: Dictionary) -> int:
    var level := maxi(1, int(candidate.get("level", 1)))
    return maxi(0, int(rules.get("base_cost", 72)) + level * int(rules.get("level_cost", 11)))

func can_replace_dead(dead_hero_id: String, candidate: Dictionary) -> Dictionary:
    var dead_index := _dead_hero_index(dead_hero_id)
    if dead_index < 0:
        return {"ok": false, "reason": "dead_hero_not_found"}
    if candidate.is_empty() or str(candidate.get("id", "")) == "":
        return {"ok": false, "reason": "invalid_candidate"}
    var fallen: Dictionary = GameState.party[dead_index]
    if str(candidate.get("class_id", "")) != str(fallen.get("class_id", "")):
        return {"ok": false, "reason": "class_mismatch"}
    var cost := recruitment_cost(candidate)
    if GameState.gold < cost:
        return {"ok": false, "reason": "insufficient_gold", "cost": cost, "gold": GameState.gold}
    return {"ok": true, "dead_index": dead_index, "cost": cost}

func replace_dead(dead_hero_id: String, candidate: Dictionary) -> Dictionary:
    var check := can_replace_dead(dead_hero_id, candidate)
    if not bool(check.get("ok", false)):
        return check
    var dead_index := int(check.get("dead_index", -1))
    var cost := int(check.get("cost", 0))
    var fallen: Dictionary = GameState.party[dead_index]
    var recruit := candidate.duplicate(true)
    var identity_id := str(recruit.get("id", ""))
    recruit["recruit_identity_id"] = identity_id
    recruit["id"] = str(fallen.get("id", dead_hero_id))
    recruit["replaced_hero_id"] = str(fallen.get("id", dead_hero_id))
    recruit["recruit_generation"] = int(fallen.get("recruit_generation", 0)) + 1
    GameState.gold -= cost
    GameState.party[dead_index] = recruit
    GameState.add_log("Taverne : %s rejoint les Veilleurs pour %d or." % [str(recruit.get("name", "Une recrue")), cost])
    GameState.state_changed.emit()
    return {
        "ok": true,
        "cost": cost,
        "fallen": fallen.duplicate(true),
        "recruit": recruit.duplicate(true),
        "party_size": GameState.party.size(),
        "gold": GameState.gold
    }

func dead_hero_ids() -> Array[String]:
    var result: Array[String] = []
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if int(hero.get("hp", 0)) <= 0:
            result.append(str(hero.get("id", "")))
    return result

func _dead_hero_index(hero_id: String) -> int:
    for index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[index]
        if str(hero.get("id", "")) == hero_id and int(hero.get("hp", 0)) <= 0:
            return index
    return -1

func _average_alive_level() -> int:
    var alive := GameState.alive_heroes()
    if alive.is_empty():
        return 1
    var total := 0
    for hero in alive:
        total += maxi(1, int(hero.get("level", 1)))
    return maxi(1, int(round(float(total) / float(alive.size()))))
