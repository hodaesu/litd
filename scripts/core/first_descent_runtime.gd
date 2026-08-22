extends Node

signal attempt_started(status: Dictionary)
signal attempt_finished(result: Dictionary)
signal first_descent_completed(award: Dictionary)

const RULES_PATH := "res://data/roguelike/roguelike_rules.json"

var rules: Dictionary = {}
var attempts_by_dungeon: Dictionary = {}
var claims: Dictionary = {}
var chronicles: Array = []
var unlocked_titles: Dictionary = {}
var relic_collection: Dictionary = {}
var achievements: Dictionary = {}
var active_attempt: Dictionary = {}
var last_award: Dictionary = {}

func _ready() -> void:
    _load_rules()
    if not GameState.new_game_reset.is_connected(reset_new_game):
        GameState.new_game_reset.connect(reset_new_game)

func _load_rules() -> void:
    if not FileAccess.file_exists(RULES_PATH):
        push_error("FirstDescentRuntime: missing roguelike rules")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
    if typeof(parsed) == TYPE_DICTIONARY:
        rules = parsed

func reset_new_game() -> void:
    attempts_by_dungeon = {}
    claims = {}
    chronicles = []
    unlocked_titles = {}
    relic_collection = {}
    achievements = {}
    active_attempt = {}
    last_award = {}

func default_dungeon_id() -> String:
    return str(rules.get("default_dungeon_id", "first_veil_crypts"))

func start_attempt(dungeon_id: String = "", seed_value: int = 0, party: Array = []) -> Dictionary:
    if rules.is_empty():
        _load_rules()
    var resolved_id := dungeon_id if dungeon_id != "" else default_dungeon_id()
    var profile: Dictionary = rules.get("dungeons", {}).get(resolved_id, {})
    var challenge: Dictionary = profile.get("first_descent", {})
    var attempt_number := int(attempts_by_dungeon.get(resolved_id, 0)) + 1
    attempts_by_dungeon[resolved_id] = attempt_number
    var enabled := bool(challenge.get("enabled", false))
    var eligible := enabled and attempt_number == 1 and not claims.has(resolved_id)
    active_attempt = {
        "dungeon_id": resolved_id,
        "seed": seed_value,
        "attempt_number": attempt_number,
        "eligible": eligible,
        "finalized": false,
        "party_started": _snapshot_party(party)
    }
    last_award = {}
    var result := status(resolved_id)
    attempt_started.emit(result.duplicate(true))
    return result

func finish_attempt(reason: String, run_state: Dictionary, party: Array = [], light_remaining: int = -1) -> Dictionary:
    if active_attempt.is_empty() or bool(active_attempt.get("finalized", false)):
        return {"unlocked": false, "reason": "no_active_attempt"}
    active_attempt["finalized"] = true
    var dungeon_id := str(active_attempt.get("dungeon_id", default_dungeon_id()))
    var eligible := bool(active_attempt.get("eligible", false))
    var boss_defeated := bool(run_state.get("boss_defeated", false))
    var qualifies := eligible and boss_defeated and reason == "boss_defeated" and not claims.has(dungeon_id)
    if not qualifies:
        var failure := {
            "unlocked": false,
            "dungeon_id": dungeon_id,
            "attempt_number": int(active_attempt.get("attempt_number", 0)),
            "reason": reason,
            "boss_defeated": boss_defeated
        }
        active_attempt = {}
        last_award = {}
        attempt_finished.emit(failure.duplicate(true))
        return failure

    var profile: Dictionary = rules.get("dungeons", {}).get(dungeon_id, {})
    var challenge: Dictionary = profile.get("first_descent", {})
    var title_id := str(challenge.get("title_id", "first_descent_%s_title" % dungeon_id))
    var relic_id := str(challenge.get("relic_id", "first_descent_%s_relic" % dungeon_id))
    var achievement_id := str(challenge.get("achievement_id", "first_descent_%s" % dungeon_id))
    var chronicle := _build_chronicle(dungeon_id, profile, challenge, run_state, party, light_remaining)
    chronicles.append(chronicle.duplicate(true))

    var title_reward := {
        "id": title_id,
        "name": str(challenge.get("title", "Première Descente")),
        "cosmetic_only": true
    }
    var relic_reward := {
        "id": relic_id,
        "name": str(challenge.get("relic_name", "Relique de la Première Descente")),
        "collection_only": true,
        "combat_bonus": 0
    }
    var achievement := {
        "id": achievement_id,
        "name": str(challenge.get("achievement_name", "Première Descente")),
        "dungeon_id": dungeon_id
    }
    unlocked_titles[title_id] = title_reward.duplicate(true)
    relic_collection[relic_id] = relic_reward.duplicate(true)
    achievements[achievement_id] = achievement.duplicate(true)

    var award := {
        "unlocked": true,
        "dungeon_id": dungeon_id,
        "attempt_number": int(active_attempt.get("attempt_number", 1)),
        "title": title_reward,
        "relic": relic_reward,
        "achievement": achievement,
        "chronicle": chronicle
    }
    claims[dungeon_id] = award.duplicate(true)
    last_award = award.duplicate(true)
    active_attempt = {}
    first_descent_completed.emit(award.duplicate(true))
    attempt_finished.emit(award.duplicate(true))
    return award

func status(dungeon_id: String = "") -> Dictionary:
    var resolved_id := dungeon_id if dungeon_id != "" else default_dungeon_id()
    var active_matches := not active_attempt.is_empty() and str(active_attempt.get("dungeon_id", "")) == resolved_id
    return {
        "dungeon_id": resolved_id,
        "attempts": int(attempts_by_dungeon.get(resolved_id, 0)),
        "claimed": claims.has(resolved_id),
        "eligible": bool(active_attempt.get("eligible", false)) if active_matches else false,
        "active": active_matches,
        "attempt_number": int(active_attempt.get("attempt_number", 0)) if active_matches else 0
    }

func collection() -> Dictionary:
    return {
        "titles": unlocked_titles.duplicate(true),
        "relics": relic_collection.duplicate(true),
        "achievements": achievements.duplicate(true),
        "claims": claims.duplicate(true)
    }

func chronicle_entries() -> Array:
    return chronicles.duplicate(true)

func _build_chronicle(dungeon_id: String, profile: Dictionary, challenge: Dictionary, run_state: Dictionary, party: Array, light_remaining: int) -> Dictionary:
    var survivors: Array = []
    var fallen: Array = []
    var seen_ids: Dictionary = {}
    for hero_value in party:
        var hero: Dictionary = hero_value
        var entry := {
            "id": str(hero.get("id", "hero")),
            "name": str(hero.get("name", "Inconnu")),
            "level": int(hero.get("level", 1)),
            "hp": int(hero.get("hp", 0))
        }
        seen_ids[entry.id] = true
        if int(hero.get("hp", 0)) > 0:
            survivors.append(entry)
        else:
            fallen.append(entry)
    for start_value in active_attempt.get("party_started", []):
        var start_entry: Dictionary = start_value
        var hero_id := str(start_entry.get("id", ""))
        if hero_id != "" and not seen_ids.has(hero_id):
            fallen.append({
                "id": hero_id,
                "name": str(start_entry.get("name", "Inconnu")),
                "level": int(start_entry.get("level", 1)),
                "hp": 0
            })
    return {
        "id": "first_descent_%s" % dungeon_id,
        "title": str(challenge.get("chronicle_title", "LA PREMIÈRE DESCENTE")),
        "dungeon_id": dungeon_id,
        "dungeon_title": str(profile.get("title", dungeon_id)),
        "boss_name": str(challenge.get("boss_name", "Boss")),
        "seed": int(active_attempt.get("seed", run_state.get("seed", 0))),
        "attempt_number": int(active_attempt.get("attempt_number", 1)),
        "rooms_cleared": int(run_state.get("rooms_cleared", 0)),
        "deepest_depth": int(run_state.get("deepest_depth", 0)),
        "light_remaining": light_remaining,
        "survivors": survivors,
        "fallen": fallen,
        "party_started": active_attempt.get("party_started", []).duplicate(true),
        "completed_at_unix": int(Time.get_unix_time_from_system())
    }

func _snapshot_party(party: Array) -> Array:
    var result: Array = []
    for hero_value in party:
        var hero: Dictionary = hero_value
        result.append({
            "id": str(hero.get("id", "hero")),
            "name": str(hero.get("name", "Inconnu")),
            "level": int(hero.get("level", 1))
        })
    return result

func serialize() -> Dictionary:
    return {
        "attempts_by_dungeon": attempts_by_dungeon,
        "claims": claims,
        "chronicles": chronicles,
        "unlocked_titles": unlocked_titles,
        "relic_collection": relic_collection,
        "achievements": achievements,
        "active_attempt": active_attempt,
        "last_award": last_award
    }

func deserialize(data: Dictionary) -> void:
    attempts_by_dungeon = data.get("attempts_by_dungeon", {}).duplicate(true)
    claims = data.get("claims", {}).duplicate(true)
    chronicles = data.get("chronicles", []).duplicate(true)
    unlocked_titles = data.get("unlocked_titles", {}).duplicate(true)
    relic_collection = data.get("relic_collection", {}).duplicate(true)
    achievements = data.get("achievements", {}).duplicate(true)
    active_attempt = data.get("active_attempt", {}).duplicate(true)
    last_award = data.get("last_award", {}).duplicate(true)
