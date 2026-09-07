extends RefCounted

const SpeciesKnowledge := preload("res://scripts/core/species_knowledge_runtime.gd")

const MAX_SOCIAL_HISTORY := 16
const RECRUIT_DELAY_RUNS := 1
const SERVICE_DELAY_RUNS := 1

const CHOICE_AID_SURVIVOR := "aid_survivor"
const CHOICE_LISTEN := "listen_testimony"
const CHOICE_RECEIVE_INFORMATION := "receive_information"
const CHOICE_REQUEST_SERVICE := "request_service"
const CHOICE_RETURN_TO_FAMILY := "return_to_family"
const CHOICE_INVITE_REFUGE := "invite_refuge"
const CHOICE_LET_GO := "let_go"
const CHOICE_SEND_MESSAGE := "send_message"

static func build_event(projection: Dictionary, context: Dictionary = {}) -> Dictionary:
    if projection.is_empty():
        return {}
    var entity_id := str(projection.get("entity_id", ""))
    var role := str(projection.get("role", ""))
    if entity_id == "" or role == "" or not RemanenceRuntime.entities.has(entity_id):
        return {}
    var choices := _choices_for_role(role)
    var reaction := _former_nemesis_reaction(projection)
    var event_id := "surrender-social:%s:%d:%s" % [entity_id, RemanenceRuntime.run_index, role]
    return {
        "event_id": event_id,
        "entity_id": entity_id,
        "name": str(projection.get("name", "Survivant")),
        "family_id": str(projection.get("family_id", "")),
        "species_id": str(projection.get("species_id", "")),
        "role": role,
        "title": _title_for_role(role),
        "body": str(projection.get("summary", _body_for_role(role))),
        "choices": choices,
        "choice_count": choices.size(),
        "can_resolve": not choices.is_empty(),
        "combat_handoff": role == "resentful_adversary",
        "former_nemesis_reaction": reaction,
        "region_id": str(context.get("region_id", "")),
        "run_index": RemanenceRuntime.run_index,
        "deferred_recruitment_only": role == "potential_recruit"
    }

static func resolve_choice(event: Dictionary, choice_id: String, context: Dictionary = {}) -> Dictionary:
    if event.is_empty() or choice_id == "":
        return {"resolved": false, "reason": "invalid_social_event"}
    var entity_id := str(event.get("entity_id", ""))
    var event_id := str(event.get("event_id", ""))
    if entity_id == "" or event_id == "" or not RemanenceRuntime.entities.has(entity_id):
        return {"resolved": false, "reason": "entity_missing"}
    if not _choice_allowed(event, choice_id):
        return {"resolved": false, "reason": "choice_not_available", "entity_id": entity_id}

    var record := RemanenceRuntime.entity_state(entity_id)
    var history: Array = (record.get("surrender_social_history", []) as Array).duplicate(true)
    for value: Variant in history:
        if value is Dictionary and str((value as Dictionary).get("event_id", "")) == event_id:
            return {"resolved": false, "reason": "already_resolved", "entity_id": entity_id, "event_id": event_id}

    var outcome := _apply_choice(record, event, choice_id, context)
    if not bool(outcome.get("ok", false)):
        return {"resolved": false, "reason": str(outcome.get("reason", "choice_failed")), "entity_id": entity_id, "event_id": event_id}

    record = outcome.get("record", record)
    var history_entry := {
        "event_id": event_id,
        "run_index": RemanenceRuntime.run_index,
        "role": str(event.get("role", "")),
        "choice_id": choice_id,
        "region_id": str(context.get("region_id", event.get("region_id", ""))),
        "former_nemesis_reaction": str((event.get("former_nemesis_reaction", {}) as Dictionary).get("reaction", "none"))
    }
    history.append(history_entry)
    while history.size() > MAX_SOCIAL_HISTORY:
        history.pop_front()
    record["surrender_social_history"] = history
    record["last_surrender_social_event_id"] = event_id
    record["last_surrender_social_choice"] = choice_id
    record["last_surrender_social_run"] = RemanenceRuntime.run_index
    RemanenceRuntime.entities[entity_id] = record
    RemanenceRuntime.record_event(entity_id, "surrender_social_choice", {
        "region_id": str(history_entry.get("region_id", "")),
        "role": str(event.get("role", "")),
        "choice_id": choice_id,
        "former_nemesis_reaction": str(history_entry.get("former_nemesis_reaction", "none")),
        "summary": _resolution_summary(str(event.get("name", "Survivant")), choice_id)
    })
    return {
        "resolved": true,
        "reason": "ok",
        "entity_id": entity_id,
        "event_id": event_id,
        "choice_id": choice_id,
        "effects": (outcome.get("effects", {}) as Dictionary).duplicate(true),
        "history_entry": history_entry.duplicate(true)
    }

static func is_deferred_recruit_ready(entity_id: String, current_run: int = -1) -> bool:
    var record := RemanenceRuntime.entity_state(entity_id)
    if record.is_empty() or not bool(record.get("pending_refuge_recruitment", false)):
        return false
    if str(record.get("status", "active")) in ["dead", "recruited"]:
        return false
    var run_value := RemanenceRuntime.run_index if current_run < 0 else current_run
    return run_value >= int(record.get("refuge_recruit_available_run", 999999))

static func service_state(entity_id: String, current_run: int = -1) -> Dictionary:
    var record := RemanenceRuntime.entity_state(entity_id)
    if record.is_empty():
        return {"entity_id": entity_id, "owed": false, "ready": false, "debt_count": 0}
    var run_value := RemanenceRuntime.run_index if current_run < 0 else current_run
    var debt_count := int(record.get("service_debt_count", 0))
    var available_run := int(record.get("service_available_from_run", 999999))
    return {
        "entity_id": entity_id,
        "owed": debt_count > 0,
        "ready": debt_count > 0 and run_value >= available_run,
        "debt_count": debt_count,
        "available_from_run": available_run
    }

static func redeem_service(entity_id: String, context: Dictionary = {}) -> Dictionary:
    var state := service_state(entity_id)
    if not bool(state.get("owed", false)):
        return {"redeemed": false, "reason": "no_service_owed", "entity_id": entity_id}
    if not bool(state.get("ready", false)):
        return {"redeemed": false, "reason": "service_not_ready", "entity_id": entity_id, "available_from_run": int(state.get("available_from_run", -1))}
    var record := RemanenceRuntime.entity_state(entity_id)
    var remaining := maxi(0, int(record.get("service_debt_count", 0)) - 1)
    record["service_debt_count"] = remaining
    record["service_owed_to_watchers"] = remaining > 0
    record["last_service_redeemed_run"] = RemanenceRuntime.run_index
    RemanenceRuntime.entities[entity_id] = record
    RemanenceRuntime.record_event(entity_id, "surrender_service_redeemed", {
        "region_id": str(context.get("region_id", "")),
        "service_kind": str(context.get("service_kind", "field_support")),
        "remaining_debt": remaining,
        "summary": "Un ancien adversaire honore un service promis aux Veilleurs."
    })
    return {"redeemed": true, "reason": "ok", "entity_id": entity_id, "remaining_debt": remaining}

static func _apply_choice(record: Dictionary, event: Dictionary, choice_id: String, context: Dictionary) -> Dictionary:
    var effects: Dictionary = {}
    match choice_id:
        CHOICE_AID_SURVIVOR:
            record["social_aid_count"] = int(record.get("social_aid_count", 0)) + 1
            record["watcher_social_trust"] = clampi(int(record.get("watcher_social_trust", 0)) + 10, -100, 100)
            effects["aid_recorded"] = true
        CHOICE_LISTEN, CHOICE_RECEIVE_INFORMATION:
            var knowledge := _record_information(record, event, choice_id)
            record["information_shared_count"] = int(record.get("information_shared_count", 0)) + 1
            record["last_information_shared_run"] = RemanenceRuntime.run_index
            effects["knowledge"] = knowledge
            effects["information_recorded"] = true
        CHOICE_REQUEST_SERVICE:
            record["service_debt_count"] = int(record.get("service_debt_count", 0)) + 1
            record["service_owed_to_watchers"] = true
            record["service_available_from_run"] = RemanenceRuntime.run_index + SERVICE_DELAY_RUNS
            effects["service_owed"] = true
            effects["service_available_from_run"] = int(record.get("service_available_from_run", -1))
        CHOICE_RETURN_TO_FAMILY:
            record["social_returned_to_family"] = true
            record["family_return_run"] = RemanenceRuntime.run_index
            record["pending_refuge_recruitment"] = false
            effects["returned_to_family"] = true
        CHOICE_INVITE_REFUGE:
            record["pending_refuge_recruitment"] = true
            record["refuge_recruit_invited_run"] = RemanenceRuntime.run_index
            record["refuge_recruit_available_run"] = RemanenceRuntime.run_index + RECRUIT_DELAY_RUNS
            record["social_returned_to_family"] = false
            effects["pending_recruitment"] = true
            effects["available_from_run"] = int(record.get("refuge_recruit_available_run", -1))
            effects["instant_recruitment"] = false
        CHOICE_LET_GO:
            record["released_after_social_encounter_count"] = int(record.get("released_after_social_encounter_count", 0)) + 1
            effects["released"] = true
        CHOICE_SEND_MESSAGE:
            record["family_message_count"] = int(record.get("family_message_count", 0)) + 1
            record["last_family_message_run"] = RemanenceRuntime.run_index
            effects["family_message_recorded"] = true
        _:
            return {"ok": false, "reason": "unsupported_choice"}
    record["last_social_region_id"] = str(context.get("region_id", event.get("region_id", "")))
    return {"ok": true, "record": record, "effects": effects}

static func _record_information(record: Dictionary, event: Dictionary, choice_id: String) -> Dictionary:
    var species_id := str(event.get("species_id", record.get("species_id", "")))
    if species_id == "":
        return {"ok": false, "reason": "species_missing"}
    return SpeciesKnowledge.record_evidence(species_id, "surrender_testimony", {
        "species_name": str(event.get("name", species_id)),
        "evidence_key": "surrender-social:%s:%d:%s" % [str(event.get("entity_id", "")), RemanenceRuntime.run_index, choice_id],
        "source": "surrender_social_event",
        "summary": "%s partage une information issue de sa survie après reddition." % str(event.get("name", "Un survivant"))
    })

static func _choice_allowed(event: Dictionary, choice_id: String) -> bool:
    for value: Variant in event.get("choices", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
            return true
    return false

static func _choices_for_role(role: String) -> Array[Dictionary]:
    match role:
        "survivor":
            return [_choice(CHOICE_AID_SURVIVOR, "L'aider", "Lui laisser des soins ou des vivres."), _choice(CHOICE_LISTEN, "Écouter", "Recueillir son témoignage sans lui imposer de dette."), _choice(CHOICE_RETURN_TO_FAMILY, "Le laisser rentrer", "L'autoriser à retourner auprès des siens.")]
        "neutral":
            return [_choice(CHOICE_LISTEN, "Écouter", "Laisser l'ancien adversaire raconter ce qu'il sait."), _choice(CHOICE_LET_GO, "Passer son chemin", "Ne rien exiger et poursuivre l'expédition."), _choice(CHOICE_RETURN_TO_FAMILY, "Retourner aux siens", "L'encourager à rejoindre son ancienne famille.")]
        "informant":
            return [_choice(CHOICE_RECEIVE_INFORMATION, "Prendre l'information", "Inscrire son témoignage dans la connaissance collective."), _choice(CHOICE_REQUEST_SERVICE, "Demander un service", "Créer une dette explicite, utilisable lors d'un run ultérieur."), _choice(CHOICE_RETURN_TO_FAMILY, "Le laisser rentrer", "Mettre fin à l'échange et le laisser rejoindre les siens.")]
        "potential_recruit":
            return [_choice(CHOICE_INVITE_REFUGE, "Inviter au Refuge", "Créer une possibilité de recrutement différé, jamais un cinquième Veilleur instantané."), _choice(CHOICE_RECEIVE_INFORMATION, "Parler d'abord", "Recueillir une information avant toute décision future."), _choice(CHOICE_RETURN_TO_FAMILY, "Refuser sans violence", "Le laisser retourner aux siens sans le recruter.")]
        "family_returnee":
            return [_choice(CHOICE_LISTEN, "Écouter", "Recueillir ce qu'il a vu depuis son retour."), _choice(CHOICE_SEND_MESSAGE, "Confier un message", "Laisser une trace adressée à sa famille."), _choice(CHOICE_LET_GO, "Le laisser partir", "Ne pas rouvrir l'ancien conflit.")]
        _:
            return []

static func _choice(id_value: String, label: String, description: String) -> Dictionary:
    return {"id": id_value, "label": label, "description": description}

static func _former_nemesis_reaction(projection: Dictionary) -> Dictionary:
    var former_id := str(projection.get("former_nemesis_id", ""))
    if former_id == "":
        return {"reaction": "none", "present": false, "former_nemesis_id": ""}
    if not RemanenceRuntime.entities.has(former_id):
        return {"reaction": "memory_only", "present": false, "former_nemesis_id": former_id}
    if not _former_nemesis_is_active_companion(former_id):
        return {"reaction": "remembered_not_present", "present": false, "former_nemesis_id": former_id}
    var relation: Dictionary = projection.get("relationship", {})
    var trust := int(relation.get("trust", 0))
    var respect := int(relation.get("respect", 0))
    var resentment := int(relation.get("resentment", 0))
    var reaction := "silent_recognition"
    if resentment >= 40:
        reaction = "guarded_tension"
    elif trust >= 20 and respect >= 55:
        reaction = "recognition_open"
    elif respect >= 50:
        reaction = "recognition_cautious"
    return {"reaction": reaction, "present": true, "former_nemesis_id": former_id, "random_betrayal": false, "player_control_kept": true}

static func _former_nemesis_is_active_companion(former_id: String) -> bool:
    var active_id := str(CreatureManager.active_instance_id)
    if active_id == "":
        return false
    for value: Variant in CreatureManager.captured_creatures:
        if not (value is Dictionary):
            continue
        var creature: Dictionary = value
        if str(creature.get("instance_id", "")) != active_id:
            continue
        return str(creature.get("source_remanence_id", "")) == former_id and bool(creature.get("former_nemesis", false))
    return false

static func _title_for_role(role: String) -> String:
    match role:
        "survivor": return "Un visage épargné"
        "neutral": return "Un ancien adversaire"
        "informant": return "Une voix revenue des cendres"
        "potential_recruit": return "Devant le Refuge"
        "family_returnee": return "Celui qui est rentré"
        "resentful_adversary": return "La rancune revient"
    return "Une conséquence de la reddition"

static func _body_for_role(role: String) -> String:
    match role:
        "survivor": return "L'ancien adversaire a survécu. Il reconnaît les Veilleurs."
        "neutral": return "La rencontre n'est plus immédiatement hostile."
        "informant": return "Il possède une information acquise depuis sa reddition."
        "potential_recruit": return "Il ne demande pas à rejoindre le quatuor : il peut seulement être invité au Refuge."
        "family_returnee": return "Il porte avec lui la mémoire de ce qui s'est passé entre les Veilleurs et les siens."
        "resentful_adversary": return "La reddition passée est devenue une rancune active : la rencontre bascule vers le combat."
    return "Le passé réapparaît sous une nouvelle forme."

static func _resolution_summary(name_value: String, choice_id: String) -> String:
    return "%s : choix social post-reddition '%s'." % [name_value, choice_id]
