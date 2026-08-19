extends Node

signal relationship_changed(source_id: String, target_id: String, event_id: String)
signal relationship_moment(text: String)

const DATA_PATH := "res://data/hero_relationships.json"
const HISTORY_LIMIT: int = 16

var data: Dictionary = {}
var _interpose_used: Dictionary = {}
var _fallen_recorded: Dictionary = {}

func _ready() -> void:
    _load_data()
    GameState.state_changed.connect(_on_game_state_changed)
    if not AshlandsCombatBridge.ashlands_combat_started.is_connected(_on_campaign_combat_started):
        AshlandsCombatBridge.ashlands_combat_started.connect(_on_campaign_combat_started)
    prepare_party()

func _load_data() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func _on_game_state_changed() -> void:
    prepare_party()

func _on_campaign_combat_started(_encounter_id: String, _encounter_type: String) -> void:
    reset_battle_runtime()

func reset_battle_runtime() -> void:
    _interpose_used.clear()
    _fallen_recorded.clear()

func prepare_party() -> void:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if not hero.has("relationships") or not (hero.get("relationships", {}) is Dictionary):
            hero["relationships"] = {}

func relation(source: Dictionary, target: Dictionary) -> Dictionary:
    if source.is_empty() or target.is_empty():
        return _empty_relation()
    if str(source.get("id", "")) == str(target.get("id", "")):
        return _empty_relation()
    return _ensure_relation(source, str(target.get("id", "")))

func relation_by_ids(source_id: String, target_id: String) -> Dictionary:
    var source := _hero_by_id(source_id)
    var target := _hero_by_id(target_id)
    return relation(source, target)

func record_heal(actor: Dictionary, target: Dictionary, hp_before: int) -> void:
    if actor.is_empty() or target.is_empty() or str(actor.get("id", "")) == str(target.get("id", "")):
        return
    _apply_event_directional("heal", actor, target)
    var max_hp := maxi(1, int(target.get("max_hp", 1)))
    if float(hp_before) / float(max_hp) <= 0.25:
        _apply_event_directional("critical_heal", actor, target)
        _moment("%s n'oublie pas que %s l'a relevé au bord de la rupture." % [str(target.get("name", "Le héros")), str(actor.get("name", "son allié"))])

func record_boss_finisher(actor: Dictionary, target: Dictionary) -> void:
    if actor.is_empty() or target.is_empty():
        return
    if not _is_boss(target):
        return
    for witness_value in GameState.alive_heroes():
        var witness: Dictionary = witness_value
        if str(witness.get("id", "")) == str(actor.get("id", "")):
            continue
        _apply_delta(witness, actor, _event_delta("boss_finisher", "witness_to_actor"), "boss_finisher")
        if float(actor.get("hp", 0)) / float(maxi(1, int(actor.get("max_hp", 1)))) <= 0.25:
            _apply_delta(witness, actor, _event_delta("desperate_boss_finisher", "witness_to_actor"), "desperate_boss_finisher")
    _moment("La manière dont %s abat %s restera dans la mémoire de la compagnie." % [str(actor.get("name", "Le héros")), str(target.get("name", "le boss"))])

func record_shared_meal() -> void:
    var living := GameState.alive_heroes()
    for left_index in range(living.size()):
        for right_index in range(left_index + 1, living.size()):
            var left: Dictionary = living[left_index]
            var right: Dictionary = living[right_index]
            _apply_mutual(left, right, _event_delta("shared_meal", "mutual"), "shared_meal")

func sanctuary_conversation() -> Dictionary:
    var living := GameState.alive_heroes()
    if living.size() < 2:
        return {"applied": false, "text": "Il faut au moins deux héros présents pour qu'un échange ait lieu."}

    var selected_left: Dictionary = living[0]
    var selected_right: Dictionary = living[1]
    var selected_tension := -1
    var selected_trust := 101
    for left_index in range(living.size()):
        for right_index in range(left_index + 1, living.size()):
            var left: Dictionary = living[left_index]
            var right: Dictionary = living[right_index]
            var pair := pair_state(left, right)
            var tension := int(pair.get("tension", 0))
            var trust := int(pair.get("trust", 0))
            if tension > selected_tension or (tension == selected_tension and trust < selected_trust):
                selected_left = left
                selected_right = right
                selected_tension = tension
                selected_trust = trust

    var threshold := int(data.get("thresholds", {}).get("high_tension", 45))
    var event_id := "sanctuary_reconcile" if selected_tension >= threshold else "sanctuary_opening"
    _apply_mutual(selected_left, selected_right, _event_delta(event_id, "mutual"), event_id)
    var text := ""
    if event_id == "sanctuary_reconcile":
        text = "%s et %s mettent enfin des mots sur ce qui les opposait." % [str(selected_left.get("name", "Un héros")), str(selected_right.get("name", "un autre"))]
    else:
        text = "%s et %s restent à parler après que les autres ont quitté la table." % [str(selected_left.get("name", "Un héros")), str(selected_right.get("name", "un autre"))]
    _moment(text)
    return {
        "applied": true,
        "event_id": event_id,
        "left_id": str(selected_left.get("id", "")),
        "right_id": str(selected_right.get("id", "")),
        "text": text
    }

func combat_modifiers(hero: Dictionary) -> Dictionary:
    var result := {"fear_resistance": 0, "precision": 0}
    if hero.is_empty():
        return result
    var max_trust := 0
    var max_admiration := 0
    var max_tension := 0
    for ally_value in GameState.alive_heroes():
        var ally: Dictionary = ally_value
        if str(ally.get("id", "")) == str(hero.get("id", "")):
            continue
        var state := relation(hero, ally)
        max_trust = maxi(max_trust, int(state.get("trust", 0)))
        max_admiration = maxi(max_admiration, int(state.get("admiration", 0)))
        max_tension = maxi(max_tension, int(state.get("mistrust", 0)) + int(state.get("resentment", 0)))

    var thresholds: Dictionary = data.get("thresholds", {})
    var bonuses: Dictionary = data.get("combat_bonuses", {})
    if max_trust >= int(thresholds.get("strong_trust", 60)):
        result["fear_resistance"] = int(result.get("fear_resistance", 0)) + int(bonuses.get("trusted_ally_fear_resistance", 3))
    if max_trust >= int(thresholds.get("deep_trust", 80)):
        result["fear_resistance"] = int(result.get("fear_resistance", 0)) + int(bonuses.get("deep_trust_fear_resistance", 2))
    if max_admiration >= int(thresholds.get("admiration", 55)):
        result["precision"] = int(result.get("precision", 0)) + int(bonuses.get("admired_ally_precision", 2))
    if max_tension >= int(thresholds.get("high_tension", 45)):
        result["precision"] = int(result.get("precision", 0)) + int(bonuses.get("high_tension_precision", -2))
    return result

func try_interpose(target: Dictionary, enemy: Dictionary, round_number: int) -> Dictionary:
    if target.is_empty() or int(target.get("hp", 0)) <= 0:
        return target
    var thresholds: Dictionary = data.get("thresholds", {})
    var fear_trigger := int(thresholds.get("interpose_fear", 75))
    var hp_trigger := float(thresholds.get("interpose_hp_ratio", 0.35))
    var hp_ratio := float(target.get("hp", 0)) / float(maxi(1, int(target.get("max_hp", 1))))
    if int(target.get("fear", 0)) < fear_trigger and hp_ratio > hp_trigger:
        return target

    var best: Dictionary = {}
    var best_score := -1
    for ally_value in GameState.alive_heroes():
        var ally: Dictionary = ally_value
        if str(ally.get("id", "")) == str(target.get("id", "")):
            continue
        var target_to_ally := relation(target, ally)
        var ally_to_target := relation(ally, target)
        var trust_to_protector := int(target_to_ally.get("trust", 0))
        var protector_trust := int(ally_to_target.get("trust", 0))
        if trust_to_protector < int(thresholds.get("strong_trust", 60)) or protector_trust < 35:
            continue
        var used_key := "%s|%d|%s" % [_battle_key(), round_number, str(ally.get("id", ""))]
        if bool(_interpose_used.get(used_key, false)):
            continue
        var score := trust_to_protector + protector_trust + int(target_to_ally.get("admiration", 0))
        if score > best_score:
            best = ally
            best_score = score

    if best.is_empty():
        return target
    var key := "%s|%d|%s" % [_battle_key(), round_number, str(best.get("id", ""))]
    _interpose_used[key] = true
    _apply_event_directional("interpose", best, target)
    GameState.add_log("LIEN — %s s'interpose avant que %s ne soit frappé par %s." % [str(best.get("name", "Un allié")), str(target.get("name", "son compagnon")), str(enemy.get("name", "l'ennemi"))])
    return best

func on_hero_fallen(fallen: Dictionary) -> void:
    if fallen.is_empty() or int(fallen.get("hp", 0)) > 0:
        return
    var fallen_id := str(fallen.get("id", ""))
    var key := "%s|%s" % [_battle_key(), fallen_id]
    if bool(_fallen_recorded.get(key, false)):
        return
    _fallen_recorded[key] = true

    var rules: Dictionary = data.get("fallen_fear", {})
    for survivor_value in GameState.alive_heroes():
        var survivor: Dictionary = survivor_value
        if str(survivor.get("id", "")) == fallen_id:
            continue
        var bond := relation(survivor, fallen)
        var fear_gain := 0
        if int(bond.get("trust", 0)) >= 60:
            fear_gain += int(rules.get("trust_60", 6))
        if int(bond.get("trust", 0)) >= 80:
            fear_gain += int(rules.get("trust_80", 4))
        if int(bond.get("admiration", 0)) >= 55:
            fear_gain += int(rules.get("admiration_55", 2))
        if fear_gain <= 0:
            continue
        var before := int(survivor.get("fear", 0))
        survivor["fear"] = mini(100, before + fear_gain)
        PsychologyRuntime.record_external_fear(survivor, before, "bond_loss", {"fallen_id": fallen_id})
    _moment("La chute de %s n'a pas le même poids pour ceux qui l'avaient laissé entrer dans leur vie." % str(fallen.get("name", "un compagnon")))

func pair_state(left: Dictionary, right: Dictionary) -> Dictionary:
    var left_to_right := relation(left, right)
    var right_to_left := relation(right, left)
    return {
        "trust": int(round((int(left_to_right.get("trust", 0)) + int(right_to_left.get("trust", 0))) / 2.0)),
        "admiration": int(round((int(left_to_right.get("admiration", 0)) + int(right_to_left.get("admiration", 0))) / 2.0)),
        "tension": int(round((int(left_to_right.get("mistrust", 0)) + int(right_to_left.get("mistrust", 0)) + int(left_to_right.get("resentment", 0)) + int(right_to_left.get("resentment", 0))) / 2.0))
    }

func pair_descriptor(left: Dictionary, right: Dictionary) -> String:
    var pair := pair_state(left, right)
    var trust := int(pair.get("trust", 0))
    var admiration := int(pair.get("admiration", 0))
    var tension := int(pair.get("tension", 0))
    if tension >= 70:
        return "ressentiment ouvert"
    if tension >= 45:
        return "relation tendue"
    if trust >= 80:
        return "confiance profonde"
    if trust >= 60:
        return "confiance solide"
    if admiration >= 55:
        return "admiration marquée"
    if trust >= 30:
        return "lien en formation"
    return "distance prudente"

func pair_summaries(limit: int = 3) -> Array[String]:
    var entries: Array[Dictionary] = []
    for left_index in range(GameState.party.size()):
        var left: Dictionary = GameState.party[left_index]
        for right_index in range(left_index + 1, GameState.party.size()):
            var right: Dictionary = GameState.party[right_index]
            var pair := pair_state(left, right)
            var importance := int(pair.get("trust", 0)) + int(pair.get("admiration", 0)) + int(pair.get("tension", 0))
            entries.append({"importance": importance, "left": left, "right": right})
    entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("importance", 0)) > int(b.get("importance", 0)))
    var result: Array[String] = []
    for index in range(mini(limit, entries.size())):
        var entry: Dictionary = entries[index]
        var left: Dictionary = entry.get("left", {})
        var right: Dictionary = entry.get("right", {})
        result.append("%s ↔ %s : %s" % [str(left.get("name", "?")), str(right.get("name", "?")), pair_descriptor(left, right)])
    return result

func memorial_line() -> String:
    var best_line := ""
    var best_score := -1
    for fallen_value in GameState.party:
        var fallen: Dictionary = fallen_value
        if int(fallen.get("hp", 0)) > 0:
            continue
        for survivor_value in GameState.alive_heroes():
            var survivor: Dictionary = survivor_value
            var bond := relation(survivor, fallen)
            var score := int(bond.get("trust", 0)) + int(bond.get("admiration", 0))
            if score > best_score:
                best_score = score
                best_line = "%s reste longtemps devant le nom de %s." % [str(survivor.get("name", "Un survivant")), str(fallen.get("name", "un disparu"))]
    return best_line

func _apply_event_directional(event_id: String, actor: Dictionary, target: Dictionary) -> void:
    _apply_delta(target, actor, _event_delta(event_id, "target_to_actor"), event_id)
    _apply_delta(actor, target, _event_delta(event_id, "actor_to_target"), event_id)

func _apply_mutual(left: Dictionary, right: Dictionary, delta: Dictionary, event_id: String) -> void:
    _apply_delta(left, right, delta, event_id)
    _apply_delta(right, left, delta, event_id)

func _apply_delta(source: Dictionary, target: Dictionary, delta: Dictionary, event_id: String) -> void:
    if source.is_empty() or target.is_empty() or delta.is_empty():
        return
    if str(source.get("id", "")) == str(target.get("id", "")):
        return
    var target_id := str(target.get("id", ""))
    var relationships: Dictionary = source.get("relationships", {})
    var state := _ensure_relation(source, target_id)
    for metric_value in data.get("metrics", []):
        var metric := str(metric_value)
        if not delta.has(metric):
            continue
        state[metric] = clampi(int(state.get(metric, 0)) + int(delta.get(metric, 0)), 0, 100)
    var history: Array = state.get("history", [])
    history.append({"event_id": event_id, "chapter": CampaignState.current_chapter_id})
    while history.size() > HISTORY_LIMIT:
        history.pop_front()
    state["history"] = history
    relationships[target_id] = state
    source["relationships"] = relationships
    relationship_changed.emit(str(source.get("id", "")), target_id, event_id)

func _ensure_relation(source: Dictionary, target_id: String) -> Dictionary:
    var relationships_value = source.get("relationships", {})
    var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
    var state_value = relationships.get(target_id, {})
    var state: Dictionary = state_value if state_value is Dictionary else {}
    for metric_value in data.get("metrics", []):
        var metric := str(metric_value)
        if not state.has(metric):
            state[metric] = 0
    if not state.has("history") or not (state.get("history", []) is Array):
        state["history"] = []
    relationships[target_id] = state
    source["relationships"] = relationships
    return state

func _empty_relation() -> Dictionary:
    return {"trust": 0, "admiration": 0, "mistrust": 0, "resentment": 0, "history": []}

func _event_delta(event_id: String, direction: String) -> Dictionary:
    var value = data.get("events", {}).get(event_id, {}).get(direction, {})
    return value if value is Dictionary else {}

func _hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _is_boss(enemy: Dictionary) -> bool:
    return bool(enemy.get("boss", false)) \
        or bool(enemy.get("is_boss", false)) \
        or bool(enemy.get("deep_vestige_boss", false)) \
        or str(enemy.get("chapter_boss_id", "")) != ""

func _battle_key() -> String:
    if AshlandsCombatBridge.active:
        return "campaign:%s" % AshlandsCombatBridge.encounter_id
    return "prototype:%d" % GameState.expedition_room

func _moment(text: String) -> void:
    if text == "":
        return
    relationship_moment.emit(text)
    GameState.add_log("LIEN — " + text)
