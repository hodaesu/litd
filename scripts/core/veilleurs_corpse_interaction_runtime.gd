extends Node

signal corpse_previewed(scar_id: String, preview: Dictionary)
signal corpse_action_resolved(scar_id: String, action_id: String, result: Dictionary)

const AISHA_CORPSE_SKILL := "AÏ-ANA-12"
const TAREK_CORPSE_SKILL := "TA-DIS-12"

func preview(scar_id: String) -> Dictionary:
    if not RemanenceRuntime.world_scars.has(scar_id):
        return {"ok": false, "reason": "scar_missing"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    if str(scar.get("type", "")) != "persistent_corpse":
        return {"ok": false, "reason": "not_a_corpse"}
    var payload: Dictionary = scar.get("payload", {})
    var state := str(payload.get("corpse_state", "intact"))
    var owner_name := str(payload.get("owner_name", scar.get("summary", "Corps")))
    var options: Array[Dictionary] = []
    options.append(_option("inspect", "EXAMINER", false, "Observer le corps et ses traces sans le modifier."))
    if state not in ["destroyed", "consumed", "burned"]:
        options.append(_option("move", "DÉPLACER", false, "Déplace physiquement le corps dans la salle; la nouvelle position est persistante."))
        if _party_has_skill(AISHA_CORPSE_SKILL):
            options.append(_option("study_aisha", "AÏSHA · LECTURE DES MORTS", false, "Analyse anatomique du cadavre et enregistre ce qui peut être appris."))
        if _party_has_skill(TAREK_CORPSE_SKILL):
            options.append(_option("cover_tarek", "TAREK · DERRIÈRE LES MORTS", false, "Prépare ce corps comme couverture réelle pour une utilisation tactique."))
        if int(payload.get("postmortem_mutilation_count", 0)) <= 0:
            options.append(_option("mutilate", "MUTILER", true, "Altère irréversiblement le corps et laisse une nouvelle trace de Rémanence."))
    var preview_value := {
        "ok": true,
        "scar_id": scar_id,
        "title": owner_name,
        "description": _description(scar, payload),
        "state": state,
        "options": options,
        "aisha_analysis_available": _party_has_skill(AISHA_CORPSE_SKILL),
        "tarek_cover_available": _party_has_skill(TAREK_CORPSE_SKILL)
    }
    corpse_previewed.emit(scar_id, preview_value.duplicate(true))
    return preview_value

func execute(scar_id: String, action_id: String) -> Dictionary:
    var before := preview(scar_id)
    if not bool(before.get("ok", false)):
        return before
    var allowed := false
    for option_value: Variant in before.get("options", []):
        var option: Dictionary = option_value
        if str(option.get("id", "")) == action_id:
            allowed = true
            break
    if not allowed:
        return {"ok": false, "reason": "action_unavailable", "action_id": action_id}
    var result: Dictionary
    match action_id:
        "inspect": result = _inspect(scar_id)
        "move": result = _move(scar_id)
        "study_aisha": result = _study_aisha(scar_id)
        "cover_tarek": result = _cover_tarek(scar_id)
        "mutilate": result = _mutilate(scar_id)
        _: result = {"ok": false, "reason": "unknown_action"}
    corpse_action_resolved.emit(scar_id, action_id, result.duplicate(true))
    return result

func _inspect(scar_id: String) -> Dictionary:
    var director: Node = RemanenceCombatBridge.world_director as Node
    if director == null or not director.has_method("visit_scar"):
        return {"ok": false, "reason": "remanence_world_director_missing"}
    var result: Dictionary = director.call("visit_scar", scar_id)
    if bool(result.get("ok", false)):
        GameState.add_log(str(result.get("text", "Le corps demeure ici.")))
    return result

func _move(scar_id: String) -> Dictionary:
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    var count := int(payload.get("move_count", 0)) + 1
    var angle := float((count * 137) % 360) * PI / 180.0
    payload["move_count"] = count
    payload["corpse_state"] = "moved"
    payload["corpse_offset"] = [cos(angle) * 1.35, 0.0, sin(angle) * 1.35]
    payload["last_moved_run"] = RemanenceRuntime.run_index
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    _disturb(scar_id, "moved")
    GameState.add_log("Le corps est déplacé. Sa nouvelle position restera dans le monde.")
    return {"ok": true, "action": "move", "scar_id": scar_id, "corpse_offset": payload["corpse_offset"]}

func _study_aisha(scar_id: String) -> Dictionary:
    if not _party_has_skill(AISHA_CORPSE_SKILL):
        return {"ok": false, "reason": "aisha_skill_required"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    payload["studied_by_aisha"] = true
    payload["last_studied_run"] = RemanenceRuntime.run_index
    var body_snapshot: Dictionary = payload.get("body_snapshot", {})
    payload["study_summary"] = {
        "persistent_injuries": (body_snapshot.get("persistent_injuries", []) as Array).size(),
        "dismembered_parts": (body_snapshot.get("dismembered_parts", []) as Array).size(),
        "known_anatomy_states": (body_snapshot.get("anatomy_part_states", {}) as Dictionary).size()
    }
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    _disturb(scar_id, "studied_by_aisha")
    RemanenceRuntime.link_archive_nodes("hero:aisha_maren", scar_id, "studied_corpse", {"run_index": RemanenceRuntime.run_index})
    var origin_entity_id := str(scar.get("origin_entity_id", ""))
    if origin_entity_id != "":
        RemanenceRuntime.link_archive_nodes("hero:aisha_maren", origin_entity_id, "anatomy_learned_from_corpse", {"scar_id": scar_id})
    GameState.add_log("Aïsha lit les lésions du corps et inscrit l’observation dans les Archives.")
    return {"ok": true, "action": "study_aisha", "scar_id": scar_id, "study_summary": payload["study_summary"]}

func _cover_tarek(scar_id: String) -> Dictionary:
    if not _party_has_skill(TAREK_CORPSE_SKILL):
        return {"ok": false, "reason": "tarek_skill_required"}
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    payload["prepared_as_cover"] = true
    payload["cover_quality"] = clampi(35 + int((payload.get("body_snapshot", {}) as Dictionary).size()) * 2, 35, 60)
    payload["last_cover_run"] = RemanenceRuntime.run_index
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload})
    _disturb(scar_id, "prepared_as_cover")
    RemanenceRuntime.link_archive_nodes("hero:tarek_senn", scar_id, "corpse_cover", {"run_index": RemanenceRuntime.run_index})
    GameState.add_log("Tarek repère comment utiliser ce corps comme couverture sans le faire disparaître.")
    return {"ok": true, "action": "cover_tarek", "scar_id": scar_id, "cover_quality": int(payload["cover_quality"])}

func _mutilate(scar_id: String) -> Dictionary:
    var scar: Dictionary = RemanenceRuntime.world_scars[scar_id]
    var payload: Dictionary = scar.get("payload", {}).duplicate(true)
    var count := int(payload.get("postmortem_mutilation_count", 0)) + 1
    payload["postmortem_mutilation_count"] = count
    payload["corpse_state"] = "mutilated"
    payload["last_mutilated_run"] = RemanenceRuntime.run_index
    var body_snapshot: Dictionary = payload.get("body_snapshot", {}).duplicate(true)
    body_snapshot["postmortem_mutilated"] = true
    body_snapshot["postmortem_mutilation_count"] = count
    payload["body_snapshot"] = body_snapshot
    RemanenceRuntime.update_world_scar(scar_id, {"payload": payload, "severity": "regional"})
    _disturb(scar_id, "mutilated")
    var origin_entity_id := str(scar.get("origin_entity_id", ""))
    if origin_entity_id != "":
        RemanenceRuntime.record_event(origin_entity_id, "corpse_mutilated", {
            "scar_id": scar_id,
            "summary": "Le corps de %s est mutilé après sa mort." % str(payload.get("owner_name", "l’adversaire")),
            "zone_id": str(scar.get("zone_id", "")),
            "region_id": str(scar.get("region_id", ""))
        })
        RemanenceRuntime.link_archive_nodes(origin_entity_id, scar_id, "postmortem_mutilation", {"run_index": RemanenceRuntime.run_index})
    GameState.add_log("Le corps est mutilé. Cette altération est désormais une trace persistante.")
    return {"ok": true, "action": "mutilate", "scar_id": scar_id, "mutilation_count": count}

func _disturb(scar_id: String, disturbance: String) -> void:
    var director: Node = RemanenceCombatBridge.world_director as Node
    if director != null and director.has_method("disturb_scar"):
        director.call("disturb_scar", scar_id, disturbance)

func _party_has_skill(skill_id: String) -> bool:
    for hero_value: Variant in GameState.party:
        if not (hero_value is Dictionary):
            continue
        var hero: Dictionary = hero_value
        if (hero.get("unlocked_skills", []) as Array).has(skill_id):
            return true
    return false

func _option(id_value: String, label_value: String, irreversible: bool, description: String) -> Dictionary:
    return {"id": id_value, "label": label_value, "irreversible": irreversible, "description": description}

func _description(scar: Dictionary, payload: Dictionary) -> String:
    var parts: Array[String] = []
    parts.append(str(scar.get("summary", "Un corps persiste ici.")))
    parts.append("État : %s." % str(payload.get("corpse_state", "intact")))
    if bool(payload.get("studied_by_aisha", false)):
        parts.append("Aïsha a déjà étudié ses lésions.")
    if bool(payload.get("prepared_as_cover", false)):
        parts.append("Tarek l’a préparé comme couverture tactique.")
    if int(payload.get("postmortem_mutilation_count", 0)) > 0:
        parts.append("Le corps porte une mutilation post-mortem persistante.")
    return " ".join(parts)
