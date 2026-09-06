extends Node

const FormerNemesisCombat := preload("res://scripts/core/veilleurs_former_nemesis_combat_runtime.gd")
const VeilleursCapture := preload("res://scripts/core/veilleurs_capture_runtime.gd")

const REGION_ID := "act_i"

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    _prepare()
    var former := _recruit_former_nemesis()
    _test_real_family_recognition(former)
    _test_skill_tree_continuity(former)
    _test_regional_successor_and_archives(former)
    _finish()

func _prepare() -> void:
    GameState.reset_new_game()
    RemanenceRuntime.reset_new_game()
    CreatureManager.reset_new_game(26090622)
    EndgameState.reset_profile_progress()
    ContentScopeDirector.grant_capability("capture")
    GameState.essence = 100
    GameState.party = [
        {"id":"nayra_orun","name":"Nayra Orun","hp":40,"max_hp":40,"speed":12,"relationships":{}},
        {"id":"tarek_senn","name":"Tarek Senn","hp":34,"max_hp":34,"speed":14,"relationships":{}},
        {"id":"aisha_maren","name":"Aïsha Maren","hp":31,"max_hp":31,"speed":11,"relationships":{}},
        {"id":"idris_vael","name":"Idris Vael","hp":35,"max_hp":35,"speed":10,"relationships":{}}
    ]
    ActionTimelineDirector.round_index = 1

func _recruit_former_nemesis() -> Dictionary:
    var enemy := {
        "id":1,
        "species_id":"hungry_ghoul",
        "family_id":"ghouls",
        "name":"La Gueule Fendue",
        "hp":1,
        "max_hp":24,
        "damage":[2,4],
        "captured":false,
        "level":12,
        "xp":33,
        "skill_points":4,
        "specialization":"offense",
        "active_doctrine":"offense",
        "unlocked_skills":["ghoul_claws","ghoul_critical"],
        "skill_tree_progress":{
            "offense":{"unlocked":2,"last_skill":"ghoul_critical"},
            "defense":{"unlocked":0},
            "special":{"unlocked":0}
        }
    }
    var entity_id := _promote_to_nemesis(enemy, "nayra_orun")
    _check(str(RemanenceRuntime.entity_state(entity_id).get("stage", "")) == "nemesis", "Succession : le premier individu doit être un Némésis hostile avant son recrutement")
    var capture := VeilleursCapture.attempt(enemy, 1)
    _check(bool(capture.get("success", false)), "Succession : le Némésis doit pouvoir rejoindre les auxiliaires lorsque les conditions de capture sont réunies")
    _check(bool(capture.get("skill_state_preserved", false)) or bool((capture.get("creature", {}) as Dictionary).get("three_tree_continuity", false)), "Compétences : le recrutement doit annoncer la continuité des arbres")
    var creature: Dictionary = CreatureManager.captured_creatures[0] if not CreatureManager.captured_creatures.is_empty() else {}
    _check(not creature.is_empty(), "Succession : l'ancien Némésis doit exister comme auxiliaire")
    _check(str(creature.get("source_remanence_id", "")) == entity_id, "Succession : l'auxiliaire doit conserver le même EntityID")
    return creature

func _test_real_family_recognition(former: Dictionary) -> void:
    var family_enemy := {
        "id":101,
        "species_id":"hungry_ghoul",
        "family_id":"ghouls",
        "name":"Goule de l'ancienne meute",
        "hp":6,
        "max_hp":24,
        "speed":16,
        "enemy_fear":40,
        "captured":false
    }
    var enemies: Array = [family_enemy]
    var cycle := ActionTimelineDirector.begin_cycle(GameState.party, enemies)
    _check(not cycle.is_empty(), "Reconnaissance : le vrai cycle de combat doit être construit")
    _check(bool(family_enemy.get("former_kin_recognition_applied", false)), "Reconnaissance : l'ancienne famille doit être reconnue dans la rencontre réelle")
    _check(str(family_enemy.get("former_kin_recognition", "")) == "recognition_shock", "Reconnaissance : un ancien Némésis doit provoquer un choc de reconnaissance")
    _check(int(family_enemy.get("enemy_fear", 0)) > 40, "Reconnaissance : la peur de l'ancienne famille doit changer réellement")
    _check(int(family_enemy.get("former_kin_respect", 0)) >= 45, "Reconnaissance : le respect de son ancien rang doit être exposé")
    _check(bool(family_enemy.get("former_kin_surrender_available", false)), "Reconnaissance : une cible affaiblie et effrayée doit ouvrir une reddition télégraphiée")
    _check(str(EnemyCombatDirector.intent_preview(family_enemy)).contains("reddition"), "Reconnaissance : l'intention doit annoncer la possibilité de reddition")
    _check(not bool(family_enemy.get("former_kin_betrayal_allowed", true)), "Reconnaissance : aucune trahison aléatoire de l'ancien Némésis n'est permise")
    _check(bool(family_enemy.get("former_kin_player_control_preserved", false)), "Reconnaissance : le contrôle joueur de l'auxiliaire doit être explicitement préservé")

    var first_enemy_action := _consume_until_actor("101")
    _check(bool(first_enemy_action.get("skipped", false)), "Reconnaissance : l'ennemi reconnu doit réellement perdre son premier acte")
    _check(str(first_enemy_action.get("reason", "")) == "former_kin_hesitation", "Reconnaissance : la perte d'action doit être causée par l'hésitation mémorielle et non par un faux étourdissement")

    ActionTimelineDirector.next_round()
    ActionTimelineDirector.begin_cycle(GameState.party, enemies)
    var second_enemy_action := _consume_until_actor("101")
    _check(not bool(second_enemy_action.get("skipped", false)) or str(second_enemy_action.get("reason", "")) != "former_kin_hesitation", "Reconnaissance : l'hésitation ne doit pas se répéter gratuitement aux tours suivants")

    var source_record := RemanenceRuntime.entity_state(str(former.get("source_remanence_id", "")))
    _check(str(source_record.get("stage", "")) == "former_nemesis", "Reconnaissance : mémoriser la scène alliée ne doit jamais repromouvoir l'ancien Némésis en hostile")
    _check(not (source_record.get("allied_social_history", []) as Array).is_empty(), "Reconnaissance : la scène avec son ancienne famille doit rejoindre son histoire alliée")

func _test_skill_tree_continuity(former: Dictionary) -> void:
    var instance_id := str(former.get("instance_id", ""))
    var current := CreatureManager.get_creature(instance_id)
    _check(int(current.get("level", 0)) == 12, "Compétences : le niveau hostile doit survivre au recrutement")
    _check(int(current.get("xp", 0)) == 33, "Compétences : l'XP hostile doit survivre au recrutement")
    _check(str(current.get("specialization", "")) == "offense", "Compétences : la doctrine choisie comme ennemi doit rester verrouillée")
    _check((current.get("unlocked_skills", []) as Array).has("ghoul_claws") and (current.get("unlocked_skills", []) as Array).has("ghoul_critical"), "Compétences : les compétences déjà apprises ne doivent pas être réinitialisées")
    _check(bool(current.get("three_tree_continuity", false)), "Compétences : les trois arbres doivent conserver une continuité explicite")
    _check(not CreatureManager.skill_nodes(current, "offense").is_empty() and not CreatureManager.skill_nodes(current, "defense").is_empty() and not CreatureManager.skill_nodes(current, "special").is_empty(), "Compétences : les trois arbres de l'espèce doivent rester consultables après recrutement")
    _check(not CreatureManager.can_unlock(instance_id, "ghoul_hide"), "Compétences : le recrutement ne doit pas contourner l'exclusivité de l'arbre choisi dans le cycle initial")
    _check(CreatureManager.unlock_skill(instance_id, "ghoul_frenzy"), "Compétences : la progression doit pouvoir continuer dans l'arbre hostile déjà choisi")
    current = CreatureManager.get_creature(instance_id)
    _check((current.get("unlocked_skills", []) as Array).has("ghoul_frenzy"), "Compétences : une nouvelle compétence doit s'ajouter à l'historique existant sans reset")
    _check((current.get("unlocked_skills", []) as Array).has("ghoul_claws"), "Compétences : progresser après recrutement ne doit pas effacer les anciens nœuds")

func _test_regional_successor_and_archives(former: Dictionary) -> void:
    var former_id := str(former.get("source_remanence_id", ""))
    var successor_enemy := {
        "id":202,
        "species_id":"hungry_ghoul",
        "family_id":"ghouls",
        "name":"La Mâchoire de Suie",
        "hp":24,
        "max_hp":24,
        "speed":13,
        "captured":false
    }
    var successor_id := _promote_to_nemesis(successor_enemy, "tarek_senn")
    var successor_record := RemanenceRuntime.entity_state(successor_id)
    _check(str(successor_record.get("stage", "")) == "nemesis" and str(successor_record.get("status", "")) == "active", "Succession : un nouveau Némésis doit pouvoir émerger dans la même région après le recrutement du précédent")

    var successor_state := FormerNemesisCombat.regional_successor_state(REGION_ID)
    _check(int(successor_state.get("former_count", 0)) >= 1, "Archives : l'ancien Némésis recruté doit rester présent")
    _check(int(successor_state.get("hostile_count", 0)) == 1, "Succession : la région doit conserver au maximum un Némésis hostile")
    _check(bool(successor_state.get("cap_respected", false)), "Succession : le plafond régional doit rester respecté")
    _check(str(successor_state.get("successor_entity_id", "")) == successor_id, "Succession : le nouveau Némésis doit être identifié comme successeur hostile")
    _check(str(successor_state.get("predecessor_entity_id", "")) == former_id, "Succession : l'ancien Némésis doit être identifié comme prédécesseur devenu allié")

    FormerNemesisCombat.prepare_family_encounter([successor_enemy], {"region_id":REGION_ID, "silent":true})
    var has_successor_link := false
    for link: Dictionary in RemanenceRuntime.linked_entries(former_id):
        if str(link.get("relation", "")) == "nemesis_succeeded_by" and str(link.get("target_id", "")) == successor_id:
            has_successor_link = true
            break
    _check(has_successor_link, "Archives : prédécesseur et successeur doivent être reliés dans le réseau de mémoire")
    _check(RemanenceRuntime.entities.has(former_id) and RemanenceRuntime.entities.has(successor_id), "Archives : ancien Némésis allié et nouveau Némésis hostile doivent coexister simultanément")
    _check(str(RemanenceRuntime.entity_state(former_id).get("status", "")) == "recruited", "Archives : l'ancien Némésis doit rester classé comme recrue")
    _check(str(RemanenceRuntime.entity_state(successor_id).get("status", "")) == "active", "Archives : le successeur doit rester classé comme adversaire actif")

func _promote_to_nemesis(enemy: Dictionary, hero_id: String) -> String:
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, REGION_ID)
    for index in range(4):
        RemanenceRuntime.note_encounter(enemy, REGION_ID, {"summary":"Rencontre mémorielle %d" % (index + 1)})
    for index in range(4):
        RemanenceRuntime.record_event(entity_id, "killed_watcher", {
            "region_id":REGION_ID,
            "hero_id":hero_id,
            "summary":"Acte majeur de succession %d" % (index + 1)
        })
    return entity_id

func _consume_until_actor(actor_id: String) -> Dictionary:
    while not ActionTimelineDirector.cycle_complete():
        var result := ActionTimelineDirector.consume_cycle_action()
        if str(result.get("id", "")) == actor_id:
            return result
    return {}

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_FORMER_NEMESIS_SUCCESSOR_SMOKE_OK recognition=true first_turn_hesitation=true surrender=true successor=true archives=true skill_continuity=true")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_FORMER_NEMESIS_SUCCESSOR_SMOKE: " + failure)
    print("VEILLEURS_FORMER_NEMESIS_SUCCESSOR_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
