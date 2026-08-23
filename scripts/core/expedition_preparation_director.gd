extends Node

signal presets_changed

const MAX_PRESETS := 6
var presets: Array[Dictionary] = []

func warnings(party: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if GameState.supplies < 4:
        result.append(_warning("supplies", "Vivres faibles : la compagnie peut partir, mais le retour sera plus risqué."))
    if SideQuestRuntime.tracked_quest_id == "":
        result.append(_warning("quest", "Aucune quête n’est suivie par les cendres."))
    var healer_present := false
    for hero_value: Variant in party:
        var hero: Dictionary = hero_value
        healer_present = healer_present or PersistentInjuryRuntime.character_can_treat_party(hero)
        var hero_id := String(hero.get("id", ""))
        var equipment: Dictionary = EquipmentManager.equipped_by_hero.get(hero_id, {})
        if String(equipment.get("weapon", "")) == "":
            result.append(_warning("empty_weapon", "%s n’a aucune arme équipée." % String(hero.get("name", "Un héros"))))
        if not hero.get("persistent_injuries", []).is_empty():
            result.append(_warning("injury", "%s part avec une blessure persistante." % String(hero.get("name", "Un héros"))))
        if _two_handed_incompatible(hero, equipment):
            result.append(_warning("incompatible_weapon", "%s ne peut pas manier son arme à deux mains avec un seul bras." % String(hero.get("name", "Un héros"))))
        var loadout := CombatLoadoutManager.loadout(hero_id)
        for category in [CombatLoadoutManager.HEAL_SLOT, CombatLoadoutManager.GRENADE_SLOT]:
            if int((loadout.get(category, {}) as Dictionary).get("quantity", 0)) <= 0:
                result.append(_warning("empty_item", "%s a un emplacement rapide vide." % String(hero.get("name", "Un héros"))))
    if not healer_present:
        result.append(_warning("no_healer", "Aucun personnage doté d’une capacité de soin n’est présent."))
    return result

func save_preset(name: String, party: Array) -> bool:
    if name.strip_edges() == "":
        return false
    var snapshot := {"name":name.strip_edges(),"heroes":[]}
    for hero_value: Variant in party:
        var hero: Dictionary = hero_value
        var hero_id := String(hero.get("id", ""))
        snapshot["heroes"].append({
            "id":hero_id,
            "rank":int(hero.get("combat_position", 0)),
            "equipment":EquipmentManager.equipped_by_hero.get(hero_id, {}).duplicate(true),
            "items":CombatLoadoutManager.loadout(hero_id),
            "skills":HeroSkillManager.combat_loadout(hero)
        })
    for index in range(presets.size()):
        if String(presets[index].get("name", "")) == name.strip_edges():
            presets[index] = snapshot
            presets_changed.emit()
            return true
    presets.append(snapshot)
    if presets.size() > MAX_PRESETS:
        presets.pop_front()
    presets_changed.emit()
    return true

func apply_preset(index: int, party: Array) -> Dictionary:
    if index < 0 or index >= presets.size():
        return {"ok":false,"warnings":["Formation inconnue."]}
    var preset: Dictionary = presets[index]
    var applied := 0
    var warnings_list: Array[String] = []
    for saved_value: Variant in preset.get("heroes", []):
        var saved: Dictionary = saved_value
        var hero := _hero_by_id(party, String(saved.get("id", "")))
        if hero.is_empty():
            warnings_list.append("Héros indisponible : %s." % String(saved.get("id", "")))
            continue
        hero["combat_position"] = clampi(int(saved.get("rank", 0)), 0, 3)
        applied += 1
    return {"ok":applied > 0,"applied":applied,"warnings":warnings_list}

func serialize() -> Dictionary:
    return {"presets":presets.duplicate(true)}

func deserialize(payload: Dictionary) -> void:
    presets = payload.get("presets", []).duplicate(true)
    if presets.size() > MAX_PRESETS:
        presets.resize(MAX_PRESETS)
    presets_changed.emit()

func reset_new_game() -> void:
    presets = []
    presets_changed.emit()

func _hero_by_id(party: Array, hero_id: String) -> Dictionary:
    for hero_value: Variant in party:
        var hero: Dictionary = hero_value
        if String(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _warning(code: String, text: String) -> Dictionary:
    return {"code":code,"text":text,"blocking":false}

func _two_handed_incompatible(hero: Dictionary, equipment: Dictionary) -> bool:
    var usable_arms := 2
    for injury_value: Variant in hero.get("persistent_injuries", []):
        var injury: Dictionary = injury_value
        if String(injury.get("id", "")).contains("amputated_arm"):
            usable_arms -= 1
    var weapon := EquipmentManager.get_instance(String(equipment.get("weapon", "")))
    return usable_arms < 2 and bool(weapon.get("two_handed", false))
