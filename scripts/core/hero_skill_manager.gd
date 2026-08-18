extends Node

const LEVELS: Array[int] = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 35, 39, 44, 49]
const COSTS: Array[int] = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5]
const BRANCHES: Array[String] = ["offense", "defense", "special"]

func prepare_hero(hero: Dictionary) -> void:
    hero["xp"] = maxi(0, int(hero.get("xp", 0)))
    hero["skill_points"] = maxi(0, int(hero.get("skill_points", 1)))
    hero["unlocked_skills"] = hero.get("unlocked_skills", [])
    hero["specialization"] = str(hero.get("specialization", ""))

func multi_tree_enabled() -> bool:
    return EndgameState.active_cycle >= 1

func skill_nodes(hero: Dictionary, branch: String) -> Array:
    var result: Array = []
    var hero_id: String = str(hero.get("id", "hero"))
    var previous: String = ""
    var stats: Array[String] = _stats(hero_id, branch)
    for index in range(15):
        var skill_id: String = "%s_%s_%02d" % [hero_id, branch, index + 1]
        var stat: String = stats[index % stats.size()]
        var value: int = _value(stat, index, hero_id, branch)
        result.append({"id":skill_id,"name":_skill_name(hero_id,branch,index),"description":"+%d %s"%[value,stat.replace("_"," ")],"stat":stat,"value":value,"cost":COSTS[index],"required_level":LEVELS[index],"requires":previous})
        previous = skill_id
    return result

func can_unlock(hero: Dictionary, skill_id: String) -> bool:
    var branch: String = _branch_for(hero, skill_id)
    var specialization: String = str(hero.get("specialization", ""))
    if branch == "": return false
    if not multi_tree_enabled() and specialization != "" and specialization != branch: return false
    var node: Dictionary = _node(hero, skill_id)
    if node.is_empty() or hero.get("unlocked_skills", []).has(skill_id): return false
    if int(hero.get("level",1)) < int(node.required_level) or int(hero.get("skill_points",0)) < int(node.cost): return false
    return str(node.requires) == "" or hero.get("unlocked_skills", []).has(str(node.requires))

func unlock(hero: Dictionary, skill_id: String) -> bool:
    if not can_unlock(hero, skill_id): return false
    var node: Dictionary = _node(hero, skill_id)
    var unlocked: Array = hero.get("unlocked_skills", [])
    unlocked.append(skill_id); hero["unlocked_skills"] = unlocked
    hero["skill_points"] = int(hero.get("skill_points",0)) - int(node.cost)
    if not multi_tree_enabled() and str(hero.get("specialization","")) == "": hero["specialization"] = _branch_for(hero,skill_id)
    return true

func stats_for(hero: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for skill_id_value in hero.get("unlocked_skills", []):
        var node: Dictionary = _node(hero,str(skill_id_value)); var stat: String = str(node.get("stat",""))
        result[stat] = int(result.get(stat,0)) + int(node.get("value",0))
    return result

func grant_xp(hero: Dictionary, amount: int) -> void:
    hero["xp"] = int(hero.get("xp",0)) + maxi(0,amount)
    while int(hero.level) < GameState.MAX_CHARACTER_LEVEL and int(hero.xp) >= 50 + int(hero.level) * 25:
        hero["xp"] = int(hero.xp) - (50 + int(hero.level) * 25); hero["level"] = int(hero.level)+1; hero["skill_points"] = int(hero.get("skill_points",0))+1

func _node(hero: Dictionary, skill_id: String) -> Dictionary:
    for branch in BRANCHES:
        for node_value in skill_nodes(hero,branch):
            if str(node_value.id)==skill_id: return node_value
    return {}
func _branch_for(hero: Dictionary, skill_id: String) -> String:
    for branch in BRANCHES:
        for node_value in skill_nodes(hero,branch):
            if str(node_value.id)==skill_id: return branch
    return ""
func _stats(hero_id: String, branch: String) -> Array[String]:
    match hero_id:
        "aurelien":
            if branch=="offense": return ["damage_percent","critical_chance","max_madness","damage_bonus","madness_resistance"]
            if branch=="defense": return ["madness_resistance","fear_resistance","max_hp","physical_resistance","guard_power"]
            return ["max_madness","damage_percent","party_heal","critical_chance","fear_resistance"]
        "malvor":
            if branch=="offense": return ["break_chance","damage_bonus","stun_chance","execute_percent","damage_percent"]
            if branch=="defense": return ["physical_resistance","max_hp","guard_power","fear_resistance","riposte_chance"]
            return ["execute_percent","break_chance","stun_chance","damage_bonus","physical_resistance"]
        "lysandra":
            if branch=="offense": return ["precision","critical_chance","damage_bonus","stun_chance","damage_percent"]
            if branch=="defense": return ["max_hope","fear_resistance","physical_resistance","max_hp","guard_power"]
            return ["healing_power","party_heal","max_hope","fear_resistance","guard_power"]
        _:
            if branch=="offense": return ["riposte_chance","damage_bonus","critical_chance","stun_chance","damage_percent"]
            if branch=="defense": return ["guard_power","physical_resistance","max_hp","riposte_chance","fear_resistance"]
            return ["riposte_chance","guard_power","stun_chance","physical_resistance","party_heal"]
func _value(stat:String,index:int,hero_id:String,branch:String)->int:
    var hero_offset: int = int({"aurelien":1,"malvor":2,"lysandra":3,"darius":4}.get(hero_id,0))
    var branch_offset: int = int({"offense":0,"defense":1,"special":2}.get(branch,0))
    return int({"damage_bonus":2,"critical_chance":3,"damage_percent":5,"break_chance":4,"bleed_chance":4,"physical_resistance":2,"fear_resistance":3,"guard_power":4,"max_hp":5,"riposte_chance":3,"madness_resistance":3,"max_madness":4,"stun_chance":3,"execute_percent":6,"healing_power":5,"max_hope":4,"party_heal":2,"precision":3}.get(stat,2))+int(index/4)+hero_offset+branch_offset
func _skill_name(hero_id:String,branch:String,index:int)->String:
    return "%s · %s %d"%[str({"aurelien":"Rite occulte","malvor":"Fureur brisée","lysandra":"Grâce du Voile","darius":"Serment du Veilleur"}.get(hero_id,"Maîtrise")),str({"offense":"Assaut","defense":"Égide","special":"Essence"}.get(branch,branch)),index+1]
