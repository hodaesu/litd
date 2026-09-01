extends Node

signal cycle_profile_changed(profile_id: String)
signal chapter_variant_applied(chapter_number: int, world_variant: String)
signal expedition_variant_applied(payload: Dictionary)

const DATA_PATH := "res://data/world/ngplus_cycle_variants.json"

var data: Dictionary = {}
var _last_chapter_marker := ""
var _announced_chapters: Dictionary = {}

func _ready() -> void:
    data = _load_json(DATA_PATH)
    if not EndgameState.new_cycle_started.is_connected(_on_new_cycle_started):
        EndgameState.new_cycle_started.connect(_on_new_cycle_started)
    if not CampaignState.campaign_changed.is_connected(_on_campaign_changed):
        CampaignState.campaign_changed.connect(_on_campaign_changed)
    call_deferred("_wire_late_signals")

func _wire_late_signals() -> void:
    if not ExpeditionManager.expedition_started.is_connected(_on_expedition_started):
        ExpeditionManager.expedition_started.connect(_on_expedition_started)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("NgPlusCycleDirector: missing " + path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func active() -> bool:
    return EndgameState.active_cycle > 0

func profile_for_cycle(cycle: int = -1) -> Dictionary:
    var target := EndgameState.active_cycle if cycle < 0 else cycle
    if target <= 0:
        return {}
    for value in data.get("profiles", []):
        var profile: Dictionary = value
        if target >= int(profile.get("cycle_min", 1)) and target <= int(profile.get("cycle_max", 999)):
            return profile
    return {}

func active_profile() -> Dictionary:
    return profile_for_cycle()

func profile_id() -> String:
    return String(active_profile().get("id", "cycle_initial"))

func chapter_number() -> int:
    return CampaignState.current_chapter_number()

func world_variant(chapter: int = -1) -> String:
    if not active():
        return ""
    var profile := active_profile()
    var pool: Array = profile.get("world_variants", [])
    if pool.is_empty():
        return ""
    var chapter_id := chapter_number() if chapter < 0 else chapter
    return String(pool[_stable_index("world|%s|%d|%d" % [profile_id(), EndgameState.active_cycle, chapter_id], pool.size())])

func narrative_echo(chapter: int = -1) -> String:
    if not active():
        return ""
    var chapter_id := chapter_number() if chapter < 0 else chapter
    var echoes: Dictionary = active_profile().get("narrative_echoes", {})
    return String(echoes.get(str(chapter_id), ""))

func dungeon_context(base_seed: int, dungeon_id: String) -> Dictionary:
    if not active():
        return {"active": false, "seed": base_seed}
    var profile := active_profile()
    var rules: Dictionary = profile.get("dungeon", {})
    var salt := int(rules.get("seed_salt", 0))
    var derived_seed := base_seed + salt * EndgameState.active_cycle + int(dungeon_id.hash()) % 7919
    return {
        "active": true,
        "cycle": EndgameState.active_cycle,
        "profile_id": profile_id(),
        "seed": derived_seed,
        "variant_tag": String(rules.get("variant_tag", profile_id())),
        "extra_hazard_pool": rules.get("extra_hazard_pool", []).duplicate(true),
        "secret_chance_bonus": float(rules.get("secret_chance_bonus", 0.0)),
        "world_variant": world_variant()
    }

func enemy_mutator(enemy: Dictionary) -> Dictionary:
    if not active():
        return {}
    var pool: Array = active_profile().get("enemy_mutators", [])
    if pool.is_empty():
        return {}
    var identity := String(enemy.get("encounter_id", enemy.get("id", enemy.get("name", "enemy"))))
    return (pool[_stable_index("enemy|%s|%d|%s" % [profile_id(), EndgameState.active_cycle, identity], pool.size())] as Dictionary).duplicate(true)

func modify_enemy_action(action: Dictionary, enemy: Dictionary, heroes: Array) -> Dictionary:
    if not active() or action.is_empty():
        return action
    var result := action.duplicate(true)
    var mutator := enemy_mutator(enemy)
    var behavior := String(mutator.get("behavior", ""))
    result["ngplus_mutator_id"] = String(mutator.get("id", ""))
    result["ngplus_mutator_name"] = String(mutator.get("name", ""))
    match behavior:
        "counter_guard":
            result["target"] = "guarding"
            result["status"] = "break"
            result["status_chance"] = maxi(int(result.get("status_chance", 0)), 35)
        "break_guard":
            result["target"] = "guarding"
            result["power"] = float(result.get("power", 1.0)) + 0.18
            result["status"] = "break"
            result["status_chance"] = maxi(int(result.get("status_chance", 0)), 45)
        "hunt_hope":
            result["target"] = "highest_hope"
            result["fear_damage"] = maxi(int(result.get("fear_damage", 0)), 4 + EndgameState.active_cycle)
        "fear_burst":
            result["fear_damage"] = maxi(int(result.get("fear_damage", 0)), 3 + EndgameState.active_cycle)
        "wounded_fury":
            var hp_ratio := float(enemy.get("hp", 1)) / maxf(1.0, float(enemy.get("max_hp", 1)))
            if hp_ratio <= 0.5:
                result["power"] = float(result.get("power", 1.0)) + 0.22
        "counter_repeat":
            result["power"] = float(result.get("power", 1.0)) + 0.10
            result["status_chance"] = int(result.get("status_chance", 0)) + 8
    return result

func wow_contract() -> Dictionary:
    return data.get("wow_guarantee", {}).duplicate(true)

func _on_new_cycle_started(cycle: int, _perk_id: String) -> void:
    _last_chapter_marker = ""
    _announced_chapters.clear()
    var profile := profile_for_cycle(cycle)
    var title := String(profile.get("title", "Nouveau Cycle+ %d" % cycle))
    var opening := String(profile.get("opening_log", ""))
    GameState.add_log(title)
    if opening != "":
        GameState.add_log(opening)
    cycle_profile_changed.emit(String(profile.get("id", "")))
    call_deferred("_apply_current_chapter_variant")

func _on_campaign_changed() -> void:
    if not active():
        return
    call_deferred("_apply_current_chapter_variant")

func _apply_current_chapter_variant() -> void:
    if not active():
        return
    var chapter := chapter_number()
    var marker := "%d:%d" % [EndgameState.active_cycle, chapter]
    if marker == _last_chapter_marker:
        return
    _last_chapter_marker = marker
    var variant := world_variant(chapter)
    if variant != "":
        CampaignState.chapter_flags["ngplus_world_%s" % variant] = true
        CampaignState.chapter_flags["ngplus_profile_%s" % profile_id()] = true
    if not _announced_chapters.has(marker):
        _announced_chapters[marker] = true
        var echo := narrative_echo(chapter)
        if echo != "":
            GameState.add_log("Mémoire du cycle — " + echo)
    chapter_variant_applied.emit(chapter, variant)

func _on_expedition_started(_seed: int) -> void:
    if not active():
        return
    call_deferred("_apply_expedition_variant")

func _apply_expedition_variant() -> void:
    if not active():
        return
    var variant := world_variant()
    var profile := active_profile()
    var effect := {
        "cycle": EndgameState.active_cycle,
        "profile_id": profile_id(),
        "world_variant": variant
    }
    match variant:
        "patrouilles_inattendues", "territoires_disputes", "double_patrouille":
            ExplorationDirector.noise_level = maxf(ExplorationDirector.noise_level, 0.18)
        "routes_secondaires_ouvertes", "routes_de_contournement", "quartiers_inaccessibles_ouverts":
            ExplorationDirector.light_level = minf(1.0, ExplorationDirector.light_level + 0.08)
        "frontieres_instables", "zones_de_survie_transformees":
            ExplorationDirector.light_level = maxf(0.45, ExplorationDirector.light_level - 0.08)
    ExplorationDirector.markers.append({
        "id": "ngplus_%d_%d" % [EndgameState.active_cycle, chapter_number()],
        "kind": "ngplus_world_variant",
        "variant": variant,
        "profile": profile_id()
    })
    expedition_variant_applied.emit(effect)

func _stable_index(key: String, size: int) -> int:
    if size <= 0:
        return 0
    return absi(hash(key)) % size
