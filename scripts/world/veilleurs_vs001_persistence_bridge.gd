extends Node
class_name VeilleursVS001PersistenceBridge

signal persistent_world_changed
signal survivor_recruited(instance_id: String, remanence_id: String)
signal wound_remembered(entry: Dictionary)

const ZONE_ID := "veilleurs_vs001_voices_under_sanctuary"
const VS001 := preload("res://scripts/core/veilleurs_vs001_runtime.gd")

var corpse_scar_ids: Array[String] = []
var wound_history: Array[Dictionary] = []
var wound_signatures: Dictionary = {}
var s6_creature_instance_id: String = ""
var s6_remanence_id: String = ""

func _ready() -> void:
    if not VeilleursVS001WorldRuntime.session_started.is_connected(_on_session_started):
        VeilleursVS001WorldRuntime.session_started.connect(_on_session_started)
    if not VeilleursVS001WorldRuntime.combat_resolved.is_connected(_on_combat_resolved):
        VeilleursVS001WorldRuntime.combat_resolved.connect(_on_combat_resolved)
    if not VeilleursVS001WorldRuntime.interaction_resolved.is_connected(_on_interaction_resolved):
        VeilleursVS001WorldRuntime.interaction_resolved.connect(_on_interaction_resolved)
    if not RemanenceRuntime.remanence_changed.is_connected(_on_remanence_changed):
        RemanenceRuntime.remanence_changed.connect(_on_remanence_changed)

func reset() -> void:
    corpse_scar_ids.clear()
    wound_history.clear()
    wound_signatures.clear()
    s6_creature_instance_id = ""
    s6_remanence_id = ""
    persistent_world_changed.emit()

func serialize() -> Dictionary:
    return {
        "corpse_scar_ids": corpse_scar_ids.duplicate(),
        "wound_history": wound_history.duplicate(true),
        "wound_signatures": wound_signatures.duplicate(true),
        "s6_creature_instance_id": s6_creature_instance_id,
        "s6_remanence_id": s6_remanence_id
    }

func deserialize(payload: Dictionary) -> void:
    if payload.is_empty():
        reset()
        return
    corpse_scar_ids.clear()
    for value: Variant in payload.get("corpse_scar_ids", []):
        corpse_scar_ids.append(str(value))
    wound_history.clear()
    for value: Variant in payload.get("wound_history", []):
        if value is Dictionary:
            wound_history.append((value as Dictionary).duplicate(true))
    wound_signatures = payload.get("wound_signatures", {}).duplicate(true)
    s6_creature_instance_id = str(payload.get("s6_creature_instance_id", ""))
    s6_remanence_id = str(payload.get("s6_remanence_id", ""))
    persistent_world_changed.emit()

func recruited_survivor() -> Dictionary:
    if s6_creature_instance_id.is_empty():
        return {}
    return CreatureManager.get_creature(s6_creature_instance_id)

func active_corpse_scars() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for scar_id: String in corpse_scar_ids:
        var scar_value: Variant = RemanenceRuntime.world_scars.get(scar_id)
        if scar_value is Dictionary:
            result.append((scar_value as Dictionary).duplicate(true))
    return result

func latest_wounds(limit: int = 8) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var start_index: int = maxi(0, wound_history.size() - maxi(0, limit))
    for index: int in range(start_index, wound_history.size()):
        result.append(wound_history[index].duplicate(true))
    return result

func _on_session_started(_snapshot: Dictionary) -> void:
    reset()

func _on_remanence_changed() -> void:
    persistent_world_changed.emit()

func _on_combat_resolved(encounter_id: String, victory: bool, state_value: Dictionary) -> void:
    if not victory:
        _record_party_wounds(encounter_id, str(state_value.get("current_room", "")))
        return
    _persist_authored_corpses(encounter_id)
    _record_party_wounds(encounter_id, str(state_value.get("current_room", "")))
    persistent_world_changed.emit()

func _on_interaction_resolved(anchor_id: String, action_id: String, result: Dictionary) -> void:
    if anchor_id != "s6_survivor" or not bool(result.get("success", false)):
        return
    if action_id == "s6_recruit" and str(result.get("outcome", "")) == "recruited":
        _register_s6_survivor()
    elif action_id == "s6_leave":
        var enemy: Dictionary = _s6_enemy_snapshot()
        var entity_id: String = _ensure_s6_identity(enemy)
        if not entity_id.is_empty():
            RemanenceRuntime.record_event(entity_id, "survived_combat", {
                "zone_id": ZONE_ID,
                "region_id": ZONE_ID,
                "summary": "La Goule blessée est laissée vivante dans le recoin du Sanctuaire."
            })
    persistent_world_changed.emit()

func _persist_authored_corpses(encounter_id: String) -> void:
    var source_anchor := ""
    var marker_id := ""
    match encounter_id:
        "vs001_s3_ghouls":
            source_anchor = "voices.s3.corpses"
            marker_id = "s3_corpses"
        "vs001_s7_ghouls":
            source_anchor = "voices.s7.corpses"
            marker_id = "s7_combat"
        "vs001_s6_wounded_ghoul":
            source_anchor = "voices.s6.recruit_history"
            marker_id = "s6_survivor"
        _:
            return

    for enemy_value: Variant in GameState.battle_enemies:
        if not (enemy_value is Dictionary):
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) > 0 or bool(enemy.get("captured", false)):
            continue
        var entity_id: String = str(enemy.get("remanence_id", ""))
        if entity_id.is_empty():
            entity_id = RemanenceRuntime.prepare_enemy(enemy, ZONE_ID)
        if entity_id.is_empty() or _corpse_exists(entity_id, encounter_id):
            continue
        RemanenceRuntime.sync_body_snapshot(enemy)
        var entity_state: Dictionary = RemanenceRuntime.entity_state(entity_id)
        var body_snapshot: Dictionary = entity_state.get("body_snapshot", {}).duplicate(true)
        body_snapshot["dismembered_parts"] = (enemy.get("dismembered_parts", []) as Array).duplicate(true)
        body_snapshot["anatomy_injuries"] = (enemy.get("anatomy_injuries", {}) as Dictionary).duplicate(true)
        body_snapshot["anatomy_part_states"] = (enemy.get("anatomy_part_states", {}) as Dictionary).duplicate(true)
        body_snapshot["anatomy_part_trauma"] = (enemy.get("anatomy_part_trauma", {}) as Dictionary).duplicate(true)
        var scar_id: String = RemanenceRuntime.create_world_scar(source_anchor, "persistent_corpse", "local", {
            "zone_id": ZONE_ID,
            "region_id": ZONE_ID,
            "origin_entity_id": entity_id,
            "owner_kind": "enemy",
            "owner_id": entity_id,
            "owner_name": str(enemy.get("name", "Goule")),
            "body_snapshot": body_snapshot,
            "combat_id": encounter_id,
            "vs001_marker_id": marker_id,
            "summary": "%s demeure dans %s." % [str(enemy.get("name", "Une Goule")), _room_label_for_encounter(encounter_id)],
            "visit_count": 0,
            "last_seen_run": -1
        })
        if not scar_id.is_empty():
            corpse_scar_ids.append(scar_id)
            RemanenceRuntime.link_archive_nodes(entity_id, scar_id, "corpse_left", {
                "run_index": RemanenceRuntime.run_index,
                "encounter_id": encounter_id
            })

func _record_party_wounds(encounter_id: String, room_id: String) -> void:
    var marker_id: String = _marker_for_room(room_id)
    for hero_value: Variant in GameState.party:
        if not (hero_value is Dictionary):
            continue
        var hero: Dictionary = hero_value
        if not bool(hero.get("vs001_watcher", false)):
            continue
        PersistentInjuryRuntime.prepare_character(hero)
        for injury_value: Variant in hero.get("persistent_injuries", []):
            if not (injury_value is Dictionary):
                continue
            var injury: Dictionary = injury_value
            var signature := "%s|%s|%s|%s" % [
                str(hero.get("id", "watcher")),
                str(injury.get("id", "injury")),
                str(injury.get("severity", "minor")),
                encounter_id
            ]
            if wound_signatures.has(signature):
                continue
            wound_signatures[signature] = true
            var definition: Dictionary = PersistentInjuryRuntime.definition(str(injury.get("id", "")))
            var entry := {
                "hero_id": str(hero.get("id", "")),
                "hero_name": str(hero.get("name", "Veilleur")),
                "injury_id": str(injury.get("id", "")),
                "injury_name": str(definition.get("name", injury.get("id", "Blessure"))),
                "severity": str(injury.get("severity", "minor")),
                "permanent": bool(injury.get("permanent", false)),
                "room_id": room_id,
                "encounter_id": encounter_id,
                "run_index": RemanenceRuntime.run_index
            }
            wound_history.append(entry)
            wound_remembered.emit(entry.duplicate(true))
            if str(injury.get("severity", "minor")) in ["serious", "critical"] or bool(injury.get("permanent", false)):
                var scar_id: String = RemanenceRuntime.create_world_scar(_source_anchor_for_room(room_id), "watcher_injury_trace", "trace", {
                    "zone_id": ZONE_ID,
                    "region_id": ZONE_ID,
                    "origin_hero_id": str(hero.get("id", "")),
                    "owner_kind": "watcher_injury",
                    "owner_id": "hero:%s" % str(hero.get("id", "")),
                    "owner_name": str(hero.get("name", "Veilleur")),
                    "vs001_marker_id": marker_id,
                    "summary": "%s a été marqué ici par %s." % [str(hero.get("name", "Un Veilleur")), str(definition.get("name", "une blessure"))],
                    "injury": entry.duplicate(true)
                })
                if not scar_id.is_empty():
                    RemanenceRuntime.link_archive_nodes("hero:%s" % str(hero.get("id", "")), scar_id, "wounded_at", {
                        "encounter_id": encounter_id,
                        "room_id": room_id
                    })

func _register_s6_survivor() -> Dictionary:
    var existing: Dictionary = recruited_survivor()
    if not existing.is_empty():
        return existing
    var enemy: Dictionary = _s6_enemy_snapshot()
    var entity_id: String = _ensure_s6_identity(enemy)
    var definition: Dictionary = CreatureManager.definition_for_species("hungry_ghoul")
    if definition.is_empty():
        return {}
    var creature_value: Variant = CreatureManager.call("_create_creature", definition)
    if not (creature_value is Dictionary):
        return {}
    var creature: Dictionary = creature_value
    creature["name"] = "Goule blessée"
    creature["vs001_recruit"] = true
    creature["source_enemy_remanence_id"] = entity_id
    creature["capture_history_tags"] = ["abandoned_wounded", "captured_in_sanctuary_crypt", "fear_origin"]
    creature["persistent_injuries"] = (enemy.get("persistent_injuries", []) as Array).duplicate(true)
    CreatureManager.captured_creatures.append(creature)
    if CreatureManager.active_instance_id.is_empty():
        CreatureManager.active_instance_id = str(creature.get("instance_id", ""))
    CreatureManager.creatures_changed.emit()
    CreatureManager.creature_captured.emit(creature.duplicate(true))
    var wounded_creature: Dictionary = CaptureWoundRuntime.apply_to_latest_capture(enemy)
    if not wounded_creature.is_empty():
        creature = wounded_creature
        var index: int = CreatureManager.captured_creatures.size() - 1
        creature["vs001_recruit"] = true
        creature["source_enemy_remanence_id"] = entity_id
        creature["capture_history_tags"] = ["abandoned_wounded", "captured_in_sanctuary_crypt", "fear_origin"]
        creature["persistent_injuries"] = (enemy.get("persistent_injuries", []) as Array).duplicate(true)
        CreatureManager.captured_creatures[index] = creature
        CreatureManager.creatures_changed.emit()
    s6_creature_instance_id = str(creature.get("instance_id", ""))
    s6_remanence_id = entity_id
    if not entity_id.is_empty():
        RemanenceRuntime.set_entity_status(entity_id, "recruited")
        RemanenceRuntime.record_event(entity_id, "recruited", {
            "zone_id": ZONE_ID,
            "region_id": ZONE_ID,
            "summary": "La Goule blessée accepte le lien avec les Veilleurs.",
            "object_id": s6_creature_instance_id
        })
        RemanenceRuntime.link_archive_nodes(entity_id, "creature:%s" % s6_creature_instance_id, "recruited_as", {
            "species_id": "hungry_ghoul",
            "name": str(creature.get("name", "Goule blessée"))
        })
    survivor_recruited.emit(s6_creature_instance_id, s6_remanence_id)
    persistent_world_changed.emit()
    return creature.duplicate(true)

func _s6_enemy_snapshot() -> Dictionary:
    var profile: Dictionary = VS001.ghoul_profile("hungry_standard")
    var stats: Dictionary = profile.get("stats", {})
    var max_hp: int = int(stats.get("hp", 30))
    var enemy := {
        "id": 9106,
        "name": "Goule blessée",
        "species_id": "hungry_ghoul",
        "creature_id": "hungry_ghoul",
        "family": "ghoul",
        "hp": maxi(1, int(round(float(max_hp) * 0.28))),
        "max_hp": max_hp,
        "remanence_protected": true,
        "dismembered_parts": [],
        "anatomy_part_states": {"leg_left": "critical"},
        "anatomy_injuries": {"leg_left": "critical"},
        "anatomy_part_trauma": {"leg_left": 95.0},
        "persistent_injuries": []
    }
    PersistentInjuryRuntime.apply_injury(enemy, "fracture_leg", "critical")
    if not s6_remanence_id.is_empty():
        enemy["remanence_id"] = s6_remanence_id
    return enemy

func _ensure_s6_identity(enemy: Dictionary) -> String:
    if not s6_remanence_id.is_empty() and RemanenceRuntime.entities.has(s6_remanence_id):
        enemy["remanence_id"] = s6_remanence_id
        return s6_remanence_id
    s6_remanence_id = RemanenceRuntime.prepare_enemy(enemy, ZONE_ID)
    if not s6_remanence_id.is_empty():
        RemanenceRuntime.note_encounter(enemy, ZONE_ID, {
            "zone_id": ZONE_ID,
            "region_id": ZONE_ID,
            "summary": "Les Veilleurs découvrent une Goule grièvement blessée qui cherche surtout une issue."
        })
        RemanenceRuntime.sync_body_snapshot(enemy)
    return s6_remanence_id

func _corpse_exists(entity_id: String, encounter_id: String) -> bool:
    for scar_value: Variant in RemanenceRuntime.world_scars.values():
        if not (scar_value is Dictionary):
            continue
        var scar: Dictionary = scar_value
        var payload: Dictionary = scar.get("payload", {})
        if str(scar.get("type", "")) == "persistent_corpse" and str(scar.get("origin_entity_id", "")) == entity_id and str(payload.get("combat_id", "")) == encounter_id:
            return true
    return false

func _room_label_for_encounter(encounter_id: String) -> String:
    match encounter_id:
        "vs001_s3_ghouls": return "la Salle des Dormeurs"
        "vs001_s7_ghouls": return "la Chambre des Voix"
        "vs001_s6_wounded_ghoul": return "le Recoin du Survivant"
    return "le Sanctuaire inférieur"

func _marker_for_room(room_id: String) -> String:
    match room_id:
        "s3_sleepers": return "s3_corpses"
        "s6_survivor": return "s6_survivor"
        "s7_voice_chamber": return "s7_combat"
        "s5_fractured_crypt": return "s5_scout_corpse"
    return "entry_spawn"

func _source_anchor_for_room(room_id: String) -> String:
    match room_id:
        "s3_sleepers": return "voices.s3.corpses"
        "s6_survivor": return "voices.s6.recruit_history"
        "s7_voice_chamber": return "voices.s7.corpses"
        "s5_fractured_crypt": return "voices.s5.scout_corpse"
    return "voices.s1.fresco"
