extends Node

signal community_changed
signal rumor_added(rumor: Dictionary)
signal quest_changed(quest_id: String, state: String)

const DATA_PATH := "res://data/community_network.json"

var data: Dictionary = {}
var people_state: Dictionary = {}
var rumors: Array[Dictionary] = []
var collective_memory: Dictionary = {}
var quest_states: Dictionary = {}
var systemic_visual_cues: Array[String] = []
var systemic_audio_cues: Array[String] = []
var systemic_population_cues: Array[String] = []
var _syncing_world_facts: bool = false

func _ready() -> void:
    _load_data()
    reset_new_game()
    if not FieldEncounterRuntime.encounter_resolved.is_connected(_on_field_encounter_resolved):
        FieldEncounterRuntime.encounter_resolved.connect(_on_field_encounter_resolved)
    if not CreatureManager.creature_captured.is_connected(_on_creature_captured):
        CreatureManager.creature_captured.connect(_on_creature_captured)
    if not Chapter03Runtime.evidence_discovered.is_connected(_on_chapter03_evidence):
        Chapter03Runtime.evidence_discovered.connect(_on_chapter03_evidence)
    if not AshlandsRuntime.zone_discovered.is_connected(_on_zone_discovered):
        AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    if not GameState.new_game_reset.is_connected(_on_new_game_reset):
        GameState.new_game_reset.connect(_on_new_game_reset)
    if not GameState.state_changed.is_connected(_on_game_state_changed):
        GameState.state_changed.connect(_on_game_state_changed)
    call_deferred("_sync_world_facts")

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        data = {}
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    data = parsed if parsed is Dictionary else {}

func reset_new_game() -> void:
    people_state = {}
    rumors = []
    collective_memory = {}
    quest_states = {}
    systemic_visual_cues = []
    systemic_audio_cues = []
    systemic_population_cues = []
    for person_value in data.get("people", []):
        var person: Dictionary = person_value if person_value is Dictionary else {}
        var person_id: String = str(person.get("id", ""))
        if person_id == "":
            continue
        var default_value: Variant = person.get("default", {})
        var default_state: Dictionary = default_value.duplicate(true) if default_value is Dictionary else {}
        default_state["id"] = person_id
        default_state["name"] = str(person.get("name", person_id))
        people_state[person_id] = default_state
    community_changed.emit()

func _on_new_game_reset() -> void:
    reset_new_game()

func _on_game_state_changed() -> void:
    call_deferred("_sync_world_facts")

func _on_field_encounter_resolved(event_id: String, outcome: String) -> void:
    _apply_encounter_transition(event_id, outcome)
    _evaluate_all_active_quests()

func _on_creature_captured(creature: Dictionary) -> void:
    var species_id: String = str(creature.get("species_id", "unknown"))
    var creature_name: String = str(creature.get("name", "une créature"))
    _add_rumor({
        "id": "rumor_creature_companion_" + species_id,
        "scope": "travellers",
        "reliability": "variable",
        "text": "Les voyageurs commencent à raconter que %s marche désormais avec la compagnie. Certains parlent d'alliance, d'autres encore de capture." % creature_name
    })
    _record_fact({
        "scope": "travellers",
        "id": "creature_companion_" + species_id,
        "text": "%s accompagne réellement la compagnie." % creature_name
    })
    community_changed.emit()

func _on_chapter03_evidence(_evidence: Dictionary) -> void:
    _evaluate_all_active_quests()

func _on_zone_discovered(_zone_id: String) -> void:
    _evaluate_all_active_quests()

func _apply_encounter_transition(event_id: String, outcome: String) -> void:
    var transitions_value: Variant = data.get("encounter_transitions", {})
    var transitions: Dictionary = transitions_value if transitions_value is Dictionary else {}
    var event_value: Variant = transitions.get(event_id, {})
    var event_rules: Dictionary = event_value if event_value is Dictionary else {}
    var transition_value: Variant = event_rules.get(outcome, {})
    var transition: Dictionary = transition_value if transition_value is Dictionary else {}
    if transition.is_empty():
        return
    var people_value: Variant = transition.get("people", {})
    var people_changes: Dictionary = people_value if people_value is Dictionary else {}
    _apply_people_changes(people_changes)
    var rumor_value: Variant = transition.get("rumor", {})
    if rumor_value is Dictionary:
        _add_rumor(rumor_value)
    var fact_value: Variant = transition.get("fact", {})
    if fact_value is Dictionary:
        _record_fact(fact_value)
    var quests_value: Variant = transition.get("offer_quests", [])
    var quest_ids: Array = quests_value if quests_value is Array else []
    for quest_value in quest_ids:
        offer_quest(str(quest_value))
    community_changed.emit()

func _apply_people_changes(changes: Dictionary) -> void:
    for person_key in changes.keys():
        var person_id: String = str(person_key)
        var current_value: Variant = people_state.get(person_id, {})
        var current: Dictionary = current_value.duplicate(true) if current_value is Dictionary else {"id": person_id}
        var patch_value: Variant = changes.get(person_key, {})
        var patch: Dictionary = patch_value if patch_value is Dictionary else {}
        for key_value in patch.keys():
            current[str(key_value)] = patch.get(key_value)
        current["name"] = str(_person_definition(person_id).get("name", current.get("name", person_id)))
        people_state[person_id] = current

func _add_rumor(rumor_value: Dictionary) -> bool:
    var rumor: Dictionary = rumor_value.duplicate(true)
    var rumor_id: String = str(rumor.get("id", ""))
    if rumor_id == "" or _has_rumor(rumor_id):
        return false
    rumor["chapter_id"] = str(rumor.get("chapter_id", CampaignState.current_chapter_id))
    rumor["heard"] = bool(rumor.get("heard", false))
    rumors.append(rumor)
    var limit: int = int(data.get("rumor_limit", 24))
    while rumors.size() > limit:
        rumors.pop_front()
    rumor_added.emit(rumor.duplicate(true))
    return true

func _has_rumor(rumor_id: String) -> bool:
    for rumor_value in rumors:
        var rumor: Dictionary = rumor_value
        if str(rumor.get("id", "")) == rumor_id:
            return true
    return false

func record_systemic_cross_event(item_id: String, payload: Dictionary, kind: String = "event") -> bool:
    if item_id == "" or payload.is_empty():
        return false
    var changed := false
    var rumor_index := 0
    for rumor_value in payload.get("rumors", []):
        var rumor: Dictionary = rumor_value if rumor_value is Dictionary else {}
        var text := str(rumor.get("text", ""))
        if text == "":
            continue
        changed = _add_rumor({
            "id": "systemic_%s_%d" % [_safe_systemic_id(item_id), rumor_index],
            "scope": "sanctuary",
            "reliability": str(rumor.get("reliability", "reported")),
            "source_id": item_id,
            "source_kind": kind,
            "text": text
        }) or changed
        rumor_index += 1
    var fact_text := str(payload.get("fact", ""))
    if fact_text != "":
        changed = _record_fact({
            "scope": "systemic_cross",
            "id": "systemic_fact_" + _safe_systemic_id(item_id),
            "source_id": item_id,
            "source_kind": kind,
            "text": fact_text
        }) or changed
    systemic_visual_cues = _merge_cues(systemic_visual_cues, payload.get("visual", []))
    systemic_audio_cues = _merge_cues(systemic_audio_cues, payload.get("audio", []))
    systemic_population_cues = _merge_cues(systemic_population_cues, payload.get("population", []))
    community_changed.emit()
    return changed

func _merge_cues(existing: Array[String], values: Variant, limit: int = 18) -> Array[String]:
    var result: Array[String] = []
    for cue in existing:
        if not result.has(cue):
            result.append(cue)
    if values is Array:
        for cue_value in values:
            var cue := str(cue_value)
            if cue != "" and not result.has(cue):
                result.append(cue)
    while result.size() > limit:
        result.pop_front()
    return result

func _safe_systemic_id(value: String) -> String:
    return value.replace(".", "_").replace(":", "_").replace("/", "_")

func recent_rumor_lines(limit: int = 4) -> Array[String]:
    var result: Array[String] = []
    for index in range(rumors.size() - 1, -1, -1):
        if result.size() >= limit:
            break
        var rumor: Dictionary = rumors[index]
        var text: String = str(rumor.get("text", ""))
        if text != "":
            result.append(text)
    return result

func listen_next_rumor() -> Dictionary:
    for index in range(rumors.size() - 1, -1, -1):
        var rumor: Dictionary = rumors[index]
        if bool(rumor.get("heard", false)):
            continue
        rumor["heard"] = true
        rumors[index] = rumor
        var text: String = str(rumor.get("text", ""))
        if text != "":
            GameState.add_log("RUMEUR — " + text)
        community_changed.emit()
        return rumor.duplicate(true)
    return {}

func _record_fact(fact_value: Dictionary) -> bool:
    var fact: Dictionary = fact_value.duplicate(true)
    var scope: String = str(fact.get("scope", "world"))
    var fact_id: String = str(fact.get("id", ""))
    if fact_id == "":
        return false
    var entries_value: Variant = collective_memory.get(scope, [])
    var entries: Array = entries_value.duplicate(true) if entries_value is Array else []
    for entry_value in entries:
        var entry: Dictionary = entry_value if entry_value is Dictionary else {}
        if str(entry.get("id", "")) == fact_id:
            return false
    fact["chapter_id"] = str(fact.get("chapter_id", CampaignState.current_chapter_id))
    entries.append(fact)
    var limit: int = int(data.get("collective_memory_limit_per_scope", 18))
    while entries.size() > limit:
        entries.pop_front()
    collective_memory[scope] = entries
    return true

func facts_for_scope(scope: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var entries_value: Variant = collective_memory.get(scope, [])
    var entries: Array = entries_value if entries_value is Array else []
    for entry_value in entries:
        var entry: Dictionary = entry_value if entry_value is Dictionary else {}
        result.append(entry.duplicate(true))
    return result

func knows_fact(scope: String, fact_id: String) -> bool:
    for entry in facts_for_scope(scope):
        if str(entry.get("id", "")) == fact_id:
            return true
    return false

func sanctuary_people() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for person_value in data.get("people", []):
        var definition: Dictionary = person_value if person_value is Dictionary else {}
        var person_id: String = str(definition.get("id", ""))
        var state_value: Variant = people_state.get(person_id, {})
        var state: Dictionary = state_value if state_value is Dictionary else {}
        if not bool(state.get("sanctuary_presence", false)):
            continue
        var entry: Dictionary = definition.duplicate(true)
        entry["state"] = state.duplicate(true)
        result.append(entry)
    return result

func sanctuary_population_cues() -> Array[String]:
    var result: Array[String] = []
    for cue in systemic_population_cues:
        if not result.has(cue):
            result.append(cue)
    for person in sanctuary_people():
        var sanctuary_value: Variant = person.get("sanctuary", {})
        var sanctuary: Dictionary = sanctuary_value if sanctuary_value is Dictionary else {}
        var cue: String = str(sanctuary.get("population_cue", ""))
        if cue != "" and not result.has(cue):
            result.append(cue)
    return result

func sanctuary_visual_cues() -> Array[String]:
    var result: Array[String] = []
    for cue in systemic_visual_cues:
        if not result.has(cue):
            result.append(cue)
    for person in sanctuary_people():
        var sanctuary_value: Variant = person.get("sanctuary", {})
        var sanctuary: Dictionary = sanctuary_value if sanctuary_value is Dictionary else {}
        var cue: String = str(sanctuary.get("visual_cue", ""))
        if cue != "" and not result.has(cue):
            result.append(cue)
    return result

func sanctuary_audio_cues() -> Array[String]:
    var result: Array[String] = []
    for cue in systemic_audio_cues:
        if not result.has(cue):
            result.append(cue)
    if not sanctuary_people().is_empty():
        for cue in ["noms de routes et de survivants échangés autour des tables communes", "départs d'expédition discutés avec ceux qui ont réellement traversé les Cendres"]:
            if not result.has(cue):
                result.append(cue)
    return result

func community_summary() -> String:
    var residents: int = sanctuary_people().size()
    var offered: int = 0
    var active: int = 0
    for state_value in quest_states.values():
        var state: String = str(state_value)
        if state == "offered":
            offered += 1
        elif state == "active":
            active += 1
    return "%d présence(s) liée(s) aux choix · %d quête(s) proposée(s) · %d active(s)" % [residents, offered, active]

func offer_quest(quest_id: String) -> bool:
    if quest_definition(quest_id).is_empty() or quest_states.has(quest_id):
        return false
    quest_states[quest_id] = "offered"
    quest_changed.emit(quest_id, "offered")
    return true

func accept_quest(quest_id: String) -> bool:
    if str(quest_states.get(quest_id, "")) != "offered":
        return false
    quest_states[quest_id] = "active"
    quest_changed.emit(quest_id, "active")
    var quest: Dictionary = quest_definition(quest_id)
    GameState.add_log("QUÊTE ÉMERGENTE — %s" % str(quest.get("name", quest_id)))
    _evaluate_quest(quest_id)
    community_changed.emit()
    return true

func quest_definition(quest_id: String) -> Dictionary:
    for quest_value in data.get("quests", []):
        var quest: Dictionary = quest_value if quest_value is Dictionary else {}
        if str(quest.get("id", "")) == quest_id:
            return quest.duplicate(true)
    return {}

func quest_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for quest_value in data.get("quests", []):
        var quest: Dictionary = quest_value if quest_value is Dictionary else {}
        var quest_id: String = str(quest.get("id", ""))
        if not quest_states.has(quest_id):
            continue
        var entry: Dictionary = quest.duplicate(true)
        entry["state"] = str(quest_states.get(quest_id, ""))
        result.append(entry)
    return result

func _evaluate_all_active_quests() -> void:
    var active_ids: Array[String] = []
    for quest_key in quest_states.keys():
        if str(quest_states.get(quest_key, "")) == "active":
            active_ids.append(str(quest_key))
    for quest_id in active_ids:
        _evaluate_quest(quest_id)

func _evaluate_quest(quest_id: String) -> void:
    if str(quest_states.get(quest_id, "")) != "active":
        return
    var quest: Dictionary = quest_definition(quest_id)
    if quest.is_empty():
        return
    var objective_value: Variant = quest.get("objective", {})
    var objective: Dictionary = objective_value if objective_value is Dictionary else {}
    if not _objective_met(objective):
        return
    _complete_quest(quest_id, quest)

func _objective_met(objective: Dictionary) -> bool:
    var objective_type: String = str(objective.get("type", ""))
    var objective_id: String = str(objective.get("id", ""))
    match objective_type:
        "chapter03_evidence":
            return Chapter03Runtime.is_evidence_collected(objective_id)
        "zone_discovered":
            return AshlandsRuntime.is_zone_discovered(objective_id)
        _:
            return false

func _complete_quest(quest_id: String, quest: Dictionary) -> void:
    quest_states[quest_id] = "completed"
    var reward_value: Variant = quest.get("reward", {})
    var reward: Dictionary = reward_value if reward_value is Dictionary else {}
    for resource_key in reward.keys():
        ExpeditionManager.add_resource(str(resource_key), int(reward.get(resource_key, 0)))
    var rumor_value: Variant = quest.get("completion_rumor", {})
    if rumor_value is Dictionary:
        _add_rumor(rumor_value)
        var completion_rumor: Dictionary = rumor_value
        _record_fact({
            "scope": str(completion_rumor.get("scope", "sanctuary")),
            "id": "quest_completed_" + quest_id,
            "text": str(completion_rumor.get("text", quest.get("name", quest_id)))
        })
    quest_changed.emit(quest_id, "completed")
    GameState.add_log("QUÊTE ACCOMPLIE — %s" % str(quest.get("name", quest_id)))
    community_changed.emit()

func _sync_world_facts() -> void:
    if _syncing_world_facts:
        return
    _syncing_world_facts = true
    var changed: bool = false
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        var memories_value: Variant = hero.get("field_memories", [])
        var memories: Array = memories_value if memories_value is Array else []
        for memory_value in memories:
            var memory: Dictionary = memory_value if memory_value is Dictionary else {}
            var memory_type: String = str(memory.get("type", ""))
            if memory_type not in ["boss_spared", "boss_executed"]:
                continue
            var encounter_id: String = str(memory.get("encounter_id", ""))
            if encounter_id == "":
                continue
            var outcome: String = str(memory.get("outcome", ""))
            var rumor_id: String = "rumor_boss_fate_%s_%s" % [encounter_id, outcome]
            if _has_rumor(rumor_id):
                continue
            var boss_name: String = str(memory.get("boss_name", encounter_id))
            var text: String = "Des témoins disent que la compagnie a laissé %s vivre après sa défaite." % boss_name
            if memory_type == "boss_executed":
                text = "Des témoins disent que la compagnie a achevé %s après sa défaite." % boss_name
            changed = _add_rumor({"id": rumor_id, "scope": "travellers", "reliability": "witnessed", "text": text}) or changed
            changed = _record_fact({"scope": "travellers", "id": "boss_fate_" + encounter_id, "text": text}) or changed
    _syncing_world_facts = false
    if changed:
        community_changed.emit()

func _person_definition(person_id: String) -> Dictionary:
    for person_value in data.get("people", []):
        var person: Dictionary = person_value if person_value is Dictionary else {}
        if str(person.get("id", "")) == person_id:
            return person
    return {}

func serialize() -> Dictionary:
    return {
        "people_state": people_state.duplicate(true),
        "rumors": rumors.duplicate(true),
        "collective_memory": collective_memory.duplicate(true),
        "quest_states": quest_states.duplicate(true),
        "systemic_visual_cues": systemic_visual_cues.duplicate(),
        "systemic_audio_cues": systemic_audio_cues.duplicate(),
        "systemic_population_cues": systemic_population_cues.duplicate()
    }

func deserialize(payload: Dictionary) -> void:
    reset_new_game()
    var people_value: Variant = payload.get("people_state", {})
    if people_value is Dictionary:
        for person_key in people_value.keys():
            var person_id: String = str(person_key)
            var stored_value: Variant = people_value.get(person_key, {})
            if stored_value is Dictionary:
                people_state[person_id] = stored_value.duplicate(true)
    var rumors_value: Variant = payload.get("rumors", [])
    rumors = []
    if rumors_value is Array:
        for rumor_value in rumors_value:
            if rumor_value is Dictionary:
                rumors.append(rumor_value.duplicate(true))
    var collective_value: Variant = payload.get("collective_memory", {})
    collective_memory = collective_value.duplicate(true) if collective_value is Dictionary else {}
    var quests_value: Variant = payload.get("quest_states", {})
    quest_states = quests_value.duplicate(true) if quests_value is Dictionary else {}
    systemic_visual_cues = _string_array(payload.get("systemic_visual_cues", []))
    systemic_audio_cues = _string_array(payload.get("systemic_audio_cues", []))
    systemic_population_cues = _string_array(payload.get("systemic_population_cues", []))
    _evaluate_all_active_quests()
    community_changed.emit()

func _string_array(value: Variant) -> Array[String]:
    var result: Array[String] = []
    if value is Array:
        for item in value:
            var text := str(item)
            if text != "":
                result.append(text)
    return result
