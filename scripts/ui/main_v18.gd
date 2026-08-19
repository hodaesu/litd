extends "res://scripts/ui/main_v17.gd"

# v18 : liens persistants entre héros.
# Les relations restent derrière le système : elles se révèlent par des actes,
# quelques conséquences tactiques et des scènes courtes au Sanctuaire.

func start_random_battle() -> void:
    RelationshipRuntime.reset_battle_runtime()
    super.start_random_battle()

func hero_bonuses(hero: Dictionary) -> Dictionary:
    var result := super.hero_bonuses(hero)
    var relationship_modifiers := RelationshipRuntime.combat_modifiers(hero)
    for key_value in relationship_modifiers.keys():
        var key := str(key_value)
        result[key] = int(result.get(key, 0)) + int(relationship_modifiers.get(key, 0))
    return result

func _select_enemy_target(enemy: Dictionary, targets: Array) -> Dictionary:
    var target := super._select_enemy_target(enemy, targets)
    if target.is_empty():
        return target
    return RelationshipRuntime.try_interpose(target, enemy, round_number)

func _hero_heal_action(hero: Dictionary) -> void:
    var hp_before: Dictionary = {}
    for hero_value in GameState.party:
        var candidate: Dictionary = hero_value
        hp_before[str(candidate.get("id", ""))] = int(candidate.get("hp", 0))
    super._hero_heal_action(hero)
    for hero_value in GameState.party:
        var candidate: Dictionary = hero_value
        var candidate_id := str(candidate.get("id", ""))
        var before := int(hp_before.get(candidate_id, int(candidate.get("hp", 0))))
        if int(candidate.get("hp", 0)) > before:
            RelationshipRuntime.record_heal(hero, candidate, before)

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var living := GameState.alive_enemies()
    if living.is_empty():
        super._hero_attack_action(hero, action)
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp", 0)) <= 0:
        target = living[0]
    var hp_before := int(target.get("hp", 0))
    var was_boss := bool(target.get("boss", false)) \
        or bool(target.get("is_boss", false)) \
        or bool(target.get("deep_vestige_boss", false)) \
        or str(target.get("chapter_boss_id", "")) != ""
    super._hero_attack_action(hero, action)
    if was_boss and hp_before > 0 and int(target.get("hp", 0)) <= 0:
        RelationshipRuntime.record_boss_finisher(hero, target)

func _after_enemy_attack(enemy: Dictionary, target: Dictionary, damage: int, fear_gain: int) -> void:
    super._after_enemy_attack(enemy, target, damage, fear_gain)
    if int(target.get("hp", 0)) <= 0:
        RelationshipRuntime.on_hero_fallen(target)

func _tavern_shared_meal() -> void:
    var supplies_before := GameState.supplies
    var flag := _relationship_meal_flag()
    var already_shared := bool(CampaignState.chapter_flags.get(flag, false))
    super._tavern_shared_meal()
    if not already_shared and GameState.supplies < supplies_before:
        RelationshipRuntime.record_shared_meal()
        CampaignState.set_chapter_flag(flag, true)
        GameState.add_log("LIEN — ce repas devient un souvenir commun plutôt qu'un simple ravitaillement.")
        show_screen("tavern")

func show_tavern() -> void:
    super.show_tavern()
    RelationshipRuntime.prepare_party()
    var summaries := RelationshipRuntime.pair_summaries(3)
    var text := "LIENS MARQUANTS\n"
    if summaries.is_empty():
        text += "La compagnie ne s'est pas encore assez éprouvée pour que des liens se dessinent."
    else:
        text += "\n".join(summaries)
    var label := make_label(text, 14, TEXT)
    label.position = Vector2(40, 410)
    label.size = Vector2(790, 100)
    content.add_child(label)

    var flag := _relationship_conversation_flag()
    var used := bool(CampaignState.chapter_flags.get(flag, false))
    var conversation := make_button(
        "ÉCHANGE DÉJÀ VÉCU" if used else "PARLER À DEUX",
        func(): _tavern_relationship_conversation(),
        Vector2(300, 54)
    )
    conversation.position = Vector2(850, 430)
    conversation.disabled = used or GameState.alive_heroes().size() < 2
    content.add_child(conversation)

    var note := make_label("Une fois par chapitre. L'échange se porte vers le lien qui en a le plus besoin.", 12, MUTED)
    note.position = Vector2(850, 492)
    note.size = Vector2(340, 48)
    content.add_child(note)

func _tavern_relationship_conversation() -> void:
    var flag := _relationship_conversation_flag()
    if bool(CampaignState.chapter_flags.get(flag, false)):
        show_screen("tavern")
        return
    var result := RelationshipRuntime.sanctuary_conversation()
    if bool(result.get("applied", false)):
        CampaignState.set_chapter_flag(flag, true)
    else:
        GameState.add_log(str(result.get("text", "Aucun échange n'a lieu.")))
    show_screen("tavern")

func show_memorial() -> void:
    super.show_memorial()
    var line := RelationshipRuntime.memorial_line()
    if line == "":
        return
    var bond := make_label("LIEN CONSERVÉ — %s" % line, 15, GOLD)
    bond.position = Vector2(40, 402)
    bond.size = Vector2(1120, 54)
    content.add_child(bond)

func _relationship_meal_flag() -> String:
    return "relationship_shared_meal_%s" % CampaignState.current_chapter_id

func _relationship_conversation_flag() -> String:
    return "relationship_conversation_%s" % CampaignState.current_chapter_id
