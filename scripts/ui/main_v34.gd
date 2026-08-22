extends "res://scripts/ui/main_v33.gd"

# v34 : utiliser un soin/objet reste une action, mais le donner à un allié est
# gratuit. La règle s'applique aux héros et aux ennemis. Le transfert ne déclenche
# jamais l'effet de l'objet : il change uniquement son porteur.

const COMBAT_INVENTORY_RULES := preload("res://scripts/core/combat_inventory_rules.gd")

var combat_item_transfer_mode: String = ""
var combat_pending_item_id: String = ""

func show_combat() -> void:
    _ensure_personal_combat_inventories()
    if not combat_item_menu:
        _clear_pending_item_transfer()
    super.show_combat()

func _ensure_personal_combat_inventories() -> void:
    COMBAT_INVENTORY_RULES.reconcile_party_aggregate(GameState.party, ExpeditionManager.inventory)
    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        COMBAT_INVENTORY_RULES.initialize_enemy_inventory(enemy)

func _render_combat_item_menu() -> void:
    var hero := _active_combat_hero()
    if hero.is_empty():
        return

    var panel := VBoxContainer.new()
    panel.position = Vector2(585, 622)
    panel.size = Vector2(660, 92)
    panel.add_theme_constant_override("separation", 4)
    content.add_child(panel)

    if combat_item_transfer_mode == "give_item":
        _render_give_item_choices(panel, hero)
        return
    if combat_item_transfer_mode in ["target_use", "target_give"]:
        _render_item_target_choices(panel, hero)
        return

    panel.add_child(make_label(
        "OBJETS DE %s · UTILISER = ACTION · DONNER = GRATUIT" % str(hero.get("name", "Héros")),
        11,
        GOLD
    ))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    panel.add_child(row)
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    for resource_id in ["bandages", "medicine", "grenades"]:
        var rule: Dictionary = item_rules.get(resource_id, {})
        var label := str(rule.get("label", _item_label(resource_id))).to_upper()
        var quantity := COMBAT_INVENTORY_RULES.quantity(hero, resource_id)
        var button := make_button(
            "%s ×%d" % [label, quantity],
            func(item_id = resource_id): _begin_use_carried_item(str(item_id)),
            Vector2(150, 38)
        )
        button.disabled = quantity <= 0
        row.add_child(button)
    row.add_child(make_button("DONNER", func(): _open_give_item_menu(), Vector2(150, 38)))

func _render_give_item_choices(panel: VBoxContainer, hero: Dictionary) -> void:
    panel.add_child(make_label("DONNER UN OBJET — ne consomme pas l'action", 11, GOLD))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    panel.add_child(row)
    var carried := COMBAT_INVENTORY_RULES.ensure_actor_inventory(hero)
    var shown := 0
    for resource_value in carried.keys():
        var resource_id := str(resource_value)
        var quantity := COMBAT_INVENTORY_RULES.quantity(hero, resource_id)
        if quantity <= 0:
            continue
        row.add_child(make_button(
            "%s ×%d" % [_item_label(resource_id), quantity],
            func(item_id = resource_id): _begin_give_carried_item(str(item_id)),
            Vector2(125, 36)
        ))
        shown += 1
        if shown >= 4:
            break
    if shown == 0:
        row.add_child(make_label("Aucun objet porté.", 11, MUTED))
    row.add_child(make_button("RETOUR", func(): _clear_pending_item_transfer(); show_screen("combat"), Vector2(105, 36)))

func _render_item_target_choices(panel: VBoxContainer, hero: Dictionary) -> void:
    var verb := "UTILISER SUR" if combat_item_transfer_mode == "target_use" else "DONNER À"
    panel.add_child(make_label("%s : %s" % [verb, _item_label(combat_pending_item_id)], 11, GOLD))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    panel.add_child(row)
    for hero_value in GameState.alive_heroes():
        var target: Dictionary = hero_value
        if combat_item_transfer_mode == "target_give" and str(target.get("id", "")) == str(hero.get("id", "")):
            continue
        row.add_child(make_button(
            str(target.get("name", "Allié")),
            func(target_id = str(target.get("id", ""))): _resolve_item_target(str(target_id)),
            Vector2(125, 36)
        ))
    row.add_child(make_button("ANNULER", func(): _clear_pending_item_transfer(); show_screen("combat"), Vector2(105, 36)))

func _begin_use_carried_item(resource_id: String) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty() or COMBAT_INVENTORY_RULES.quantity(hero, resource_id) <= 0:
        return
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var item: Dictionary = item_rules.get(resource_id, {})
    if item.is_empty():
        return
    if str(item.get("target", "")) == "ally":
        combat_pending_item_id = resource_id
        combat_item_transfer_mode = "target_use"
        show_screen("combat")
        return
    _use_carried_item_on_target(resource_id, "")

func _use_combat_item(resource_id: String) -> void:
    # Compatibilité avec les parcours UI historiques : l'ancien appel passe par
    # le nouveau contrat de porteur et de ciblage.
    _begin_use_carried_item(resource_id)

func _open_give_item_menu() -> void:
    if battle_locked:
        return
    combat_item_transfer_mode = "give_item"
    combat_pending_item_id = ""
    show_screen("combat")

func _begin_give_carried_item(resource_id: String) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty() or COMBAT_INVENTORY_RULES.quantity(hero, resource_id) <= 0:
        return
    combat_pending_item_id = resource_id
    combat_item_transfer_mode = "target_give"
    show_screen("combat")

func _resolve_item_target(target_id: String) -> void:
    if combat_pending_item_id == "":
        return
    if combat_item_transfer_mode == "target_use":
        _use_carried_item_on_target(combat_pending_item_id, target_id)
    elif combat_item_transfer_mode == "target_give":
        _give_carried_item_to_hero(combat_pending_item_id, target_id)

func _use_carried_item_on_target(resource_id: String, target_id: String) -> void:
    if battle_locked:
        return
    var hero := _active_combat_hero()
    if hero.is_empty() or COMBAT_INVENTORY_RULES.quantity(hero, resource_id) <= 0:
        return
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var item: Dictionary = item_rules.get(resource_id, {})
    if item.is_empty():
        return

    var target: Dictionary = {}
    if str(item.get("target", "")) == "ally":
        target = _living_hero_by_id(target_id)
        if target.is_empty():
            return

    if not COMBAT_INVENTORY_RULES.consume(hero, resource_id, 1):
        return
    var consume_result: Dictionary = ExpeditionManager.consume_bundle({resource_id: 1})
    if not bool(consume_result.get("success", false)):
        COMBAT_INVENTORY_RULES.add(hero, resource_id, 1)
        return

    battle_locked = true
    var effect := str(item.get("effect", ""))
    if effect == "heal":
        var amount := int(item.get("heal", 0))
        target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)
        target["fear"] = maxi(0, int(target.get("fear", 0)) - int(item.get("fear_reduction", 0)))
        GameState.add_log("%s utilise %s sur %s : +%d PV. Son action est consommée." % [
            str(hero.get("name", "Héros")),
            str(item.get("label", _item_label(resource_id))),
            str(target.get("name", "Allié")),
            amount
        ])
    elif effect == "damage_all":
        var damage_range: Array = item.get("damage", [12, 18])
        var total := 0
        for enemy_value in GameState.alive_enemies():
            var enemy: Dictionary = enemy_value
            var damage := randi_range(int(damage_range[0]), int(damage_range[1]))
            enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
            total += damage
        GameState.add_log("%s utilise %s : %d dégâts cumulés. Son action est consommée." % [
            str(hero.get("name", "Héros")),
            str(item.get("label", _item_label(resource_id))),
            total
        ])

    combat_item_menu = false
    _clear_pending_item_transfer()
    _complete_active_hero_turn()

func _give_carried_item_to_hero(resource_id: String, target_id: String) -> void:
    if battle_locked:
        return
    var giver := _active_combat_hero()
    var receiver := _living_hero_by_id(target_id)
    if giver.is_empty() or receiver.is_empty():
        return
    if not COMBAT_INVENTORY_RULES.transfer(giver, receiver, resource_id, 1):
        return
    GameState.add_log("%s donne %s à %s sans consommer son action." % [
        str(giver.get("name", "Héros")),
        _item_label(resource_id),
        str(receiver.get("name", "Allié"))
    ])
    _clear_pending_item_transfer()
    show_screen("combat")

func _living_hero_by_id(hero_id: String) -> Dictionary:
    for hero_value in GameState.alive_heroes():
        var hero: Dictionary = hero_value
        if str(hero.get("id", "")) == hero_id:
            return hero
    return {}

func _item_label(resource_id: String) -> String:
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var rule: Dictionary = item_rules.get(resource_id, {})
    if not rule.is_empty():
        return str(rule.get("label", resource_id))
    return {
        "food": "Nourriture",
        "water": "Eau",
        "light": "Éclairage",
        "camp_tools": "Outils de camp",
        "bandages": "Bandage",
        "medicine": "Médecine",
        "grenades": "Grenade"
    }.get(resource_id, resource_id.replace("_", " ").capitalize())

func _clear_pending_item_transfer() -> void:
    combat_item_transfer_mode = ""
    combat_pending_item_id = ""

func _complete_active_hero_turn() -> void:
    # Même séquence que v30, mais l'appel au tour ennemi reste virtuel afin que
    # v34 puisse appliquer la même règle d'objets aux adversaires.
    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    var hero := _active_combat_hero()
    if not hero.is_empty():
        var hero_id := str(hero.get("id", ""))
        if not combat_acted_hero_ids.has(hero_id):
            combat_acted_hero_ids.append(hero_id)
    _select_next_combat_hero()
    if combat_active_hero_id != "":
        battle_locked = false
        show_screen("combat")
        return
    var companion_targets: Array[Dictionary] = GameState.alive_enemies()
    if not companion_targets.is_empty():
        var companion_result: Dictionary = CreatureManager.companion_turn(companion_targets[0])
        if not companion_result.is_empty():
            GameState.add_log("%s inflige %d dégâts." % [
                str(companion_result.get("name", "Le compagnon")),
                int(companion_result.get("damage", 0))
            ])
    if GameState.alive_enemies().is_empty():
        finish_victory()
        return
    combat_acted_hero_ids.clear()
    combat_round_number += 1
    round_number = combat_round_number
    _select_next_combat_hero()
    combat_item_menu = false
    combat_position_menu = false
    _clear_pending_item_transfer()
    enemy_turn()

func enemy_turn() -> void:
    _ensure_personal_combat_inventories()
    var original_enemies: Array = GameState.battle_enemies
    var item_rules: Dictionary = ExpeditionManager.rules.get("combat_items", {})
    var action_consumers: Array[String] = []

    # Préparation gratuite : les adversaires peuvent transmettre un objet avant
    # leur action. En revanche, administrer un soin marque l'action comme dépensée.
    for enemy_value in original_enemies:
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            continue
        if _enemy_try_use_healing_item(enemy, original_enemies, item_rules):
            action_consumers.append(str(enemy.get("combat_uid", "")))
        else:
            _enemy_try_free_item_transfer(enemy, original_enemies, item_rules)

    if action_consumers.is_empty():
        super.enemy_turn()
        return

    # Les ennemis ayant utilisé un soin sont retirés uniquement pendant la phase
    # d'attaque : leurs dictionnaires restent intacts et sont restaurés juste après.
    var attacking_enemies: Array = []
    for enemy_value in original_enemies:
        var enemy: Dictionary = enemy_value
        var uid := str(enemy.get("combat_uid", ""))
        if int(enemy.get("hp", 0)) <= 0 or not action_consumers.has(uid):
            attacking_enemies.append(enemy)
    GameState.battle_enemies = attacking_enemies
    super.enemy_turn()
    GameState.battle_enemies = original_enemies
    if GameState.current_screen == "combat":
        battle_locked = false
        show_screen("combat")

func _enemy_try_use_healing_item(enemy: Dictionary, allies: Array, item_rules: Dictionary) -> bool:
    var target := COMBAT_INVENTORY_RULES.most_wounded(allies)
    if target.is_empty():
        return false
    var ratio := float(target.get("hp", 0)) / maxf(1.0, float(target.get("max_hp", 1)))
    if ratio > 0.40:
        return false
    var resource_id := COMBAT_INVENTORY_RULES.strongest_healing_item(enemy, item_rules)
    if resource_id == "":
        return false
    var item: Dictionary = item_rules.get(resource_id, {})
    if not COMBAT_INVENTORY_RULES.consume(enemy, resource_id, 1):
        return false
    var amount := int(item.get("heal", 0))
    target["hp"] = mini(int(target.get("max_hp", 1)), int(target.get("hp", 0)) + amount)
    GameState.add_log("%s utilise %s sur %s : +%d PV. Son action est consommée." % [
        str(enemy.get("name", "Ennemi")),
        str(item.get("label", _item_label(resource_id))),
        str(target.get("name", "Allié")),
        amount
    ])
    return true

func _enemy_try_free_item_transfer(enemy: Dictionary, allies: Array, item_rules: Dictionary) -> bool:
    var target := COMBAT_INVENTORY_RULES.most_wounded(allies)
    if target.is_empty() or target == enemy:
        return false
    var target_ratio := float(target.get("hp", 0)) / maxf(1.0, float(target.get("max_hp", 1)))
    var giver_ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1)))
    if target_ratio >= 0.75 or target_ratio >= giver_ratio:
        return false
    var resource_id := COMBAT_INVENTORY_RULES.strongest_healing_item(enemy, item_rules)
    if resource_id == "" or COMBAT_INVENTORY_RULES.quantity(target, resource_id) > 0:
        return false
    if not COMBAT_INVENTORY_RULES.transfer(enemy, target, resource_id, 1):
        return false
    var item: Dictionary = item_rules.get(resource_id, {})
    GameState.add_log("%s donne %s à %s sans perdre son action." % [
        str(enemy.get("name", "Ennemi")),
        str(item.get("label", _item_label(resource_id))),
        str(target.get("name", "Allié"))
    ])
    return true

func _reset_combat_turn_state() -> void:
    _clear_pending_item_transfer()
    super._reset_combat_turn_state()
