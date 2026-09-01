extends Node

const DATA_PATH := "res://data/world/ngplus_boss_recruits.json"

var data: Dictionary = {}

func _ready() -> void:
    data = _load_json(DATA_PATH)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func enabled() -> bool:
    return EndgameState.active_cycle >= int(data.get("unlock_cycle_min", 1))

func party_reference_level() -> int:
    if GameState.party.is_empty(): return 1
    var total := 0
    var count := 0
    for hero_value in GameState.party:
        var hero: Dictionary = hero_value
        total += clampi(int(hero.get("level", 1)), 1, GameState.MAX_CHARACTER_LEVEL)
        count += 1
    return clampi(int(round(float(total) / float(maxi(1, count)))), 1, GameState.MAX_CHARACTER_LEVEL)

func encounter_id_from_enemy(enemy: Dictionary) -> String:
    for key in ["chapter_boss_id", "chapter_miniboss_id"]:
        var value := String(enemy.get(key, ""))
        if value != "": return value
    return String(enemy.get("encounter_id", ""))

func raw_entry_for_encounter(encounter_id: String) -> Dictionary:
    for value in data.get("recruits", []):
        var entry: Dictionary = value
        if String(entry.get("encounter_id", "")) == encounter_id: return entry
    return {}

func raw_entry_for_species(species_id: String) -> Dictionary:
    for value in data.get("recruits", []):
        var entry: Dictionary = value
        if String(entry.get("id", "")) == species_id: return entry
    return {}

func definition_for_enemy(enemy: Dictionary) -> Dictionary:
    if not enabled(): return {}
    var encounter_id := encounter_id_from_enemy(enemy)
    if encounter_id == "": return {}
    return _build_definition(raw_entry_for_encounter(encounter_id))

func definition_for_species(species_id: String) -> Dictionary:
    return _build_definition(raw_entry_for_species(species_id))

func _build_definition(entry: Dictionary) -> Dictionary:
    if entry.is_empty(): return {}
    var rank := String(entry.get("rank", "boss"))
    var capture_rules: Dictionary = data.get("capture_rules", {}).get(rank, {})
    var result := entry.duplicate(true)
    result["enemy_id"] = -1
    result["boss_recruit"] = true
    result["level_sync"] = true
    result["capture"] = capture_rules.duplicate(true)
    result["evolutions"] = [{"level":1,"name":String(entry.get("name", "Boss lié"))}]
    result["skill_trees"] = _generated_skill_trees(entry)
    return result

func _generated_skill_trees(entry: Dictionary) -> Dictionary:
    var id := String(entry.get("id", "boss_recruit"))
    var signature := String(entry.get("signature", "Signature"))
    var archetype := String(entry.get("archetype", "control"))
    var special_nodes := _special_nodes(id, signature, archetype)
    return {
        "offense": [
            _node(id+"_off_1", "Présence dominante", "+2 dégâts", 1, "", "damage_bonus", 2),
            _node(id+"_off_2", "Lire la faille", "+7 % critique", 8, id+"_off_1", "critical_chance", 7),
            _node(id+"_off_sig", signature+" — Assaut", "+18 % dégâts", 16, id+"_off_2", "damage_percent", 18),
            _node(id+"_off_4", "Mémoire du duel", "+4 dégâts", 32, id+"_off_sig", "damage_bonus", 4)
        ],
        "defense": [
            _node(id+"_def_1", "Corps recomposé", "+4 % résistance physique", 1, "", "physical_resistance", 4),
            _node(id+"_def_2", "Volonté persistante", "+6 résistance à la peur", 8, id+"_def_1", "fear_resistance", 6),
            _node(id+"_def_sig", signature+" — Rempart", "+12 puissance de garde", 16, id+"_def_2", "guard_power", 12),
            _node(id+"_def_4", "Ancrage du vaincu", "+7 % résistance physique", 32, id+"_def_sig", "physical_resistance", 7)
        ],
        "special": special_nodes
    }

func _special_nodes(id: String, signature: String, archetype: String) -> Array:
    match archetype:
        "guardian":
            return [_node(id+"_sp_1","Interposition","+8 puissance de garde",2,"","guard_power",8),_node(id+"_sp_2","Contrecoup","+8 % étourdissement",8,id+"_sp_1","stun_chance",8),_node(id+"_sp_sig",signature+" — Égide","+10 résistance à la peur",16,id+"_sp_2","fear_resistance",10),_node(id+"_sp_4","Tenir la ligne","+8 % résistance physique",32,id+"_sp_sig","physical_resistance",8)]
        "tactician":
            return [_node(id+"_sp_1","Lecture tactique","+7 % critique",2,"","critical_chance",7),_node(id+"_sp_2","Briser le plan","+10 % rupture",8,id+"_sp_1","break_chance",10),_node(id+"_sp_sig",signature+" — Renversement","+20 % dégâts",16,id+"_sp_2","damage_percent",20),_node(id+"_sp_4","Victoire préparée","+12 % critique",32,id+"_sp_sig","critical_chance",12)]
        "support":
            return [_node(id+"_sp_1","Présence apaisante","Soigne 2 PV",2,"","party_heal",2),_node(id+"_sp_2","Mémoire partagée","+7 résistance à la peur",8,id+"_sp_1","fear_resistance",7),_node(id+"_sp_sig",signature+" — Résonance","Soigne 4 PV",16,id+"_sp_2","party_heal",4),_node(id+"_sp_4","Lien durable","+14 résistance à la peur",32,id+"_sp_sig","fear_resistance",14)]
        "striker":
            return [_node(id+"_sp_1","Frappe précise","+3 dégâts",2,"","damage_bonus",3),_node(id+"_sp_2","Ouverture","+8 % critique",8,id+"_sp_1","critical_chance",8),_node(id+"_sp_sig",signature+" — Percée","+28 % exécution",16,id+"_sp_2","execute_percent",28),_node(id+"_sp_4","Prédateur de faille","+22 % dégâts",32,id+"_sp_sig","damage_percent",22)]
        _:
            return [_node(id+"_sp_1","Déséquilibre","+8 % étourdissement",2,"","stun_chance",8),_node(id+"_sp_2","Pression du Voile","+9 % saignement",8,id+"_sp_1","bleed_chance",9),_node(id+"_sp_sig",signature+" — Contrôle","+12 % étourdissement",16,id+"_sp_2","stun_chance",12),_node(id+"_sp_4","Réalité imposée","+18 % dégâts",32,id+"_sp_sig","damage_percent",18)]

func _node(id: String, name: String, description: String, level: int, requires: String, stat: String, value: int) -> Dictionary:
    return {"id":id,"name":name,"description":description,"cost":1 if level < 16 else 2,"required_level":level,"requires":requires,"stat":stat,"value":value}
