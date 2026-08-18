extends "res://scripts/ui/main_v11.gd"

# Combat v12 : interface anatomique lisible sans asset final + suivi de convalescence.

func show_combat() -> void:
    super.show_combat()
    _decorate_full_anatomy_panel()

func show_creatures() -> void:
    super.show_creatures()
    var list: VBoxContainer = _creature_list_container()
    if list == null:
        return
    var wounded: Array = []
    for creature_value in CreatureManager.captured_creatures:
        var creature: Dictionary = creature_value
        if not CaptureWoundRuntime.can_fight(creature):
            wounded.append(creature)
    if wounded.is_empty():
        return
    list.add_child(make_label("SOINS DU SANCTUAIRE — CONVALESCENCE", 16, GOLD))
    for creature_value in wounded:
        var creature: Dictionary = creature_value
        var instance_id := str(creature.get("instance_id", ""))
        var row := HBoxContainer.new()
        var label := make_label("%s · confiance %d · %s" % [
            str(creature.get("evolution_name", creature.get("name", "Créature"))),
            int(creature.get("bond", 50)),
            CaptureWoundRuntime.care_status(creature)
        ], 13, MUTED)
        label.custom_minimum_size = Vector2(850, 42)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(label)
        row.add_child(make_button("SOIGNER", func(id_value = instance_id): _provide_creature_care(str(id_value)), Vector2(170, 42)))
        list.add_child(row)

func _creature_list_container() -> VBoxContainer:
    for child in content.get_children():
        if child is ScrollContainer and child.get_child_count() > 0 and child.get_child(0) is VBoxContainer:
            return child.get_child(0) as VBoxContainer
    return null

func _provide_creature_care(instance_id: String) -> void:
    var creature := CaptureWoundRuntime.provide_sanctuary_care(instance_id)
    if creature.is_empty():
        GameState.add_log("Aucun soin de créature n'a pu être appliqué.")
    elif CaptureWoundRuntime.can_fight(creature):
        GameState.add_log("%s termine sa convalescence et peut de nouveau combattre." % str(creature.get("name", "La créature")))
    else:
        GameState.add_log("Soin appliqué à %s : %s." % [str(creature.get("name", "la créature")), CaptureWoundRuntime.care_status(creature)])
    show_creatures()

func _decorate_full_anatomy_panel() -> void:
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var enemy: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(enemy.get("hp", 0)) <= 0:
        return
    AnatomyRuntime.ensure_state(enemy)
    var rows := AnatomyRuntime.anatomy_status(enemy)
    if rows.is_empty():
        return

    var title := make_label("SCHÉMA ANATOMIQUE", 12, GOLD)
    title.position = Vector2(760, 252)
    title.size = Vector2(470, 24)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(title)

    var silhouette := make_label("  ○\n╱ │ ╲\n  │\n╱   ╲", 18, MUTED)
    silhouette.position = Vector2(770, 278)
    silhouette.size = Vector2(70, 116)
    silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(silhouette)

    var row_y := 275.0
    var selected_consequence := ""
    var selected_tags: Array = []
    for row_value in rows:
        var row: Dictionary = row_value
        var state := str(row.get("state", "intact"))
        var marker := "▶" if bool(row.get("selected", false)) else "·"
        var state_text := _anatomy_state_label(state)
        var protected_text := " · PROTÉGÉE" if bool(row.get("protected", false)) else ""
        var text := "%s %s · %s%s · %d/%d" % [
            marker,
            str(row.get("name", row.get("id", "partie"))),
            state_text,
            protected_text,
            int(row.get("trauma", 0)),
            int(row.get("threshold", 1))
        ]
        var line := make_label(text, 11, GOLD if bool(row.get("selected", false)) else MUTED)
        line.position = Vector2(845, row_y)
        line.size = Vector2(380, 26)
        content.add_child(line)
        row_y += 32.0
        if bool(row.get("selected", false)):
            selected_consequence = str(row.get("consequence", ""))
            selected_tags = row.get("tags", [])

    if selected_consequence != "":
        var consequence := make_label("SI NEUTRALISÉE : %s" % selected_consequence, 10, MUTED)
        consequence.position = Vector2(760, 390)
        consequence.size = Vector2(470, 48)
        consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        consequence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        content.add_child(consequence)

    var hero := _active_round_hero()
    if not hero.is_empty():
        var specialization: Dictionary = AnatomyRuntime.data.get("hero_specializations", {}).get(str(hero.get("id", "")), {})
        var affinity := false
        for tag_value in selected_tags:
            if specialization.get("tags", []).has(tag_value):
                affinity = true
                break
        var affinity_text := make_label(
            "AFFINITÉ ANATOMIQUE · %s · %s" % [str(hero.get("name", "Héros")), "FORTE" if affinity else "STANDARD"],
            10, GOLD if affinity else MUTED
        )
        affinity_text.position = Vector2(760, 440)
        affinity_text.size = Vector2(470, 22)
        affinity_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        content.add_child(affinity_text)

func _anatomy_state_label(state: String) -> String:
    match state:
        "strained": return "[FRAGILE]"
        "injured": return "[BLESSÉ]"
        "critical": return "[CRITIQUE]"
        "lost": return "[PERDU]"
        _: return "[INTACT]"
