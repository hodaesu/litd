extends "res://scripts/ui/main_v44.gd"

# v45 — inspection contextuelle des combattants.
# Le champ de bataille reste volontairement léger : toucher un héros ou un ennemi
# ouvre une fiche temporaire avec PV, rang et états. Le ciblage explicite de v44
# garde la priorité dès qu'une compétence attend une cible.

var inspected_combat_side: String = ""
var inspected_combat_key: String = ""

func show_combat() -> void:
    super.show_combat()
    if GameState.current_screen != "combat" or not is_instance_valid(content):
        return
    _compact_combat_card_labels()
    if pending_target_skill_slot < 0:
        _install_combat_inspection_hotspots()
        _render_combat_inspection_panel()

func _compact_combat_card_labels() -> void:
    # Les informations détaillées passent dans le panneau contextuel. Sur le champ
    # de bataille on conserve seulement l'identité et le rang pour réduire le bruit.
    for node_value: Variant in content.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label == null:
            continue
        for hero_value: Variant in GameState.party:
            var hero: Dictionary = hero_value
            var hero_name := str(hero.get("name", ""))
            if hero_name != "" and label.text.contains(hero_name) and label.text.contains("PV ") and label.text.contains("P"):
                var active := str(hero.get("id", "")) == combat_active_hero_id
                label.text = "%s%s\nR%d" % ["▶ " if active else "", hero_name, int(hero.get("combat_position", 0)) + 1]
                break
        for enemy_value: Variant in GameState.battle_enemies:
            var enemy: Dictionary = enemy_value
            var enemy_name := str(enemy.get("name", ""))
            if enemy_name != "" and label.text.contains(enemy_name) and label.text.contains("PV "):
                label.text = "%s\nE%d" % [enemy_name, int(enemy.get("combat_position", 0)) + 1]
                break

func _install_combat_inspection_hotspots() -> void:
    # Les cartes héritées n'ont pas toutes le même type de Control. Des zones
    # transparentes stables évitent de réécrire toute la scène de combat.
    var heroes := _heroes_by_position()
    for visual_index in range(heroes.size()):
        var hero: Dictionary = heroes[visual_index]
        var hotspot := Button.new()
        hotspot.name = "InspectHeroV45_%d" % visual_index
        hotspot.flat = true
        hotspot.position = Vector2(35.0 + float(visual_index) * 132.0, 160.0)
        hotspot.size = Vector2(132.0, 320.0)
        hotspot.z_index = 65
        hotspot.focus_mode = Control.FOCUS_ALL
        hotspot.tooltip_text = "Voir l'état de %s" % str(hero.get("name", "Héros"))
        hotspot.pressed.connect(func(hero_id = str(hero.get("id", ""))): _inspect_combatant("hero", hero_id))
        content.add_child(hotspot)

    for enemy_index in range(GameState.battle_enemies.size()):
        var enemy: Dictionary = GameState.battle_enemies[enemy_index]
        var hotspot := Button.new()
        hotspot.name = "InspectEnemyV45_%d" % enemy_index
        hotspot.flat = true
        hotspot.position = Vector2(650.0 + float(enemy_index) * 140.0, 155.0)
        hotspot.size = Vector2(140.0, 330.0)
        hotspot.z_index = 65
        hotspot.focus_mode = Control.FOCUS_ALL
        hotspot.tooltip_text = "Voir l'état de %s" % str(enemy.get("name", "Ennemi"))
        hotspot.pressed.connect(func(index = enemy_index, uid = str(enemy.get("combat_uid", ""))): _inspect_enemy(int(index), uid))
        content.add_child(hotspot)

func _inspect_enemy(index: int, uid: String) -> void:
    if index >= 0 and index < GameState.battle_enemies.size():
        selected_enemy = index
    inspected_combat_side = "enemy"
    inspected_combat_key = uid
    if inspected_combat_key == "" and index >= 0 and index < GameState.battle_enemies.size():
        inspected_combat_key = str((GameState.battle_enemies[index] as Dictionary).get("id", "enemy_%d" % index))
    show_screen("combat")

func _inspect_combatant(side: String, key: String) -> void:
    inspected_combat_side = side
    inspected_combat_key = key
    show_screen("combat")

func _close_combat_inspection() -> void:
    inspected_combat_side = ""
    inspected_combat_key = ""
    show_screen("combat")

func _render_combat_inspection_panel() -> void:
    if inspected_combat_side == "" or inspected_combat_key == "":
        return
    var combatant := _inspected_combatant()
    if combatant.is_empty():
        inspected_combat_side = ""
        inspected_combat_key = ""
        return

    var panel := PanelContainer.new()
    panel.name = "CombatInspectionV45"
    panel.position = Vector2(390, 185)
    panel.size = Vector2(500, 286)
    panel.z_index = 120
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.012, 0.014, 0.020, 0.97)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)

    var rank_prefix := "R" if inspected_combat_side == "hero" else "E"
    var title := make_label("%s · %s%d" % [str(combatant.get("name", "Combattant")), rank_prefix, int(combatant.get("combat_position", 0)) + 1], 20, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var hp := int(combatant.get("hp", 0))
    var max_hp := maxi(1, int(combatant.get("max_hp", 1)))
    var health := make_label("SANTÉ  %d / %d  ·  %d%%" % [hp, max_hp, int(round(100.0 * float(hp) / float(max_hp)))], 15, TEXT)
    health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(health)

    if inspected_combat_side == "hero":
        var resources := make_label(
            "ESPOIR %d  ·  PEUR %d  ·  FOLIE %d" % [int(combatant.get("hope", 0)), int(combatant.get("fear", 0)), int(combatant.get("madness", 0))],
            13,
            MUTED
        )
        resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(resources)

    var states := _combatant_state_lines(combatant)
    var state_text := "Aucun effet temporaire" if states.is_empty() else "  ·  ".join(states)
    var state_label := make_label("ÉTATS\n%s" % state_text, 13, TEXT)
    state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    state_label.custom_minimum_size = Vector2(460, 74)
    box.add_child(state_label)

    var close := make_button("FERMER", func(): _close_combat_inspection(), Vector2(180, 48))
    close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    box.add_child(close)

func _inspected_combatant() -> Dictionary:
    if inspected_combat_side == "hero":
        for hero_value: Variant in GameState.party:
            var hero: Dictionary = hero_value
            if str(hero.get("id", "")) == inspected_combat_key:
                return hero
        return {}

    for enemy_value: Variant in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if str(enemy.get("combat_uid", "")) == inspected_combat_key or str(enemy.get("id", "")) == inspected_combat_key:
            return enemy
    return {}

func _combatant_state_lines(combatant: Dictionary) -> Array[String]:
    var result: Array[String] = []
    if bool(combatant.get("guarding", false)):
        var guard_power := int(combatant.get("guard_power", 0))
        result.append("Garde%s" % (" +%d" % guard_power if guard_power > 0 else ""))
    if bool(combatant.get("stunned", false)):
        result.append("Étourdi")
    var bleeding := int(combatant.get("bleeding", 0))
    if bleeding > 0:
        result.append("Saignement %d" % bleeding)
    var broken := int(combatant.get("broken", 0))
    if broken > 0:
        result.append("Rupture %d" % broken)
    var riposte := int(combatant.get("riposte", combatant.get("riposte_chance", 0)))
    if riposte > 0:
        result.append("Riposte %d" % riposte)
    var marked := int(combatant.get("marked", 0))
    if marked > 0:
        result.append("Marqué %d" % marked)
    var vulnerable := int(combatant.get("vulnerable", 0))
    if vulnerable > 0:
        result.append("Vulnérable %d" % vulnerable)
    return result
