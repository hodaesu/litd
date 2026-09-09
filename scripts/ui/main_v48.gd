extends "res://scripts/ui/main_v47.gd"

# v48 — garde-fous du dernier contrôle avant playtest.
# Cette couche ne change ni les règles ni l'initiative : elle empêche uniquement
# les états transitoires (mort, cible devenue invalide, sélecteur ouvert) de
# réinitialiser un round, de conserver une cible morte ou de laisser le combat
# verrouillé après victoire/défaite.

func _ensure_combat_state() -> void:
    _ensure_combat_positions()

    # Un quatuor mort ne doit jamais relancer une sélection de héros.
    if GameState.alive_heroes().is_empty():
        combat_active_hero_id = ""
        return

    # Si le héros actif est encore vivant, l'état du round est déjà valide.
    if combat_active_hero_id != "" and not _active_combat_hero().is_empty():
        return

    # Point important : ne PAS vider combat_acted_hero_ids ici. Si un héros meurt
    # ou devient indisponible en cours de round, les Veilleurs ayant déjà agi
    # doivent rester marqués comme tels. _select_next_combat_hero() saute alors le
    # mort et choisit le prochain vivant non joué selon R1 -> R4.
    combat_active_hero_id = ""
    _select_next_combat_hero()

func show_combat() -> void:
    _normalize_selected_enemy_v48()
    super.show_combat()

func _normalize_selected_enemy_v48() -> void:
    if GameState.battle_enemies.is_empty():
        selected_enemy = 0
        return
    if selected_enemy >= 0 and selected_enemy < GameState.battle_enemies.size():
        var current: Dictionary = GameState.battle_enemies[selected_enemy]
        if int(current.get("hp", 0)) > 0:
            return
    for index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[index]
        if int(enemy.get("hp", 0)) > 0:
            selected_enemy = index
            return
    selected_enemy = clampi(selected_enemy, 0, maxi(0, GameState.battle_enemies.size() - 1))

func finish_victory() -> void:
    _clear_combat_transients_v48()
    super.finish_victory()

func finish_defeat() -> void:
    _clear_combat_transients_v48()
    super.finish_defeat()

func _clear_combat_transients_v48() -> void:
    # Ciblage ennemi explicite (v44).
    pending_target_skill_slot = -1
    pending_target_indices.clear()

    # Inspection contextuelle (v45).
    inspected_combat_side = ""
    inspected_combat_key = ""

    # Ciblage allié / objets / zones automatiques (v46).
    pending_choice_kind = ""
    pending_choice_skill_slot = -1
    pending_choice_item_id = ""
    pending_ally_ids.clear()
    forced_support_target_id = ""
    forced_item_target_id = ""
    pending_auto_group_skill_slot = -1
    pending_auto_group_indices.clear()

    combat_item_menu = false
    combat_position_menu = false
    formation_selected_hero_id = ""
    battle_locked = false
