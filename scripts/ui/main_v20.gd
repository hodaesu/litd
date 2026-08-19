extends "res://scripts/ui/main_v19.gd"

# v20 : mémoire des décisions de terrain.
# Les recrutements, retraites et choix post-boss deviennent des souvenirs persistants.
# Aucun nouveau compteur n'est exposé : la compagnie en parle avec des mots.

func show_rewards() -> void:
    super.show_rewards()
    if not AshlandsCombatBridge.active:
        return
    if str(AshlandsCombatBridge.encounter_type) != "boss":
        return
    var encounter_id := str(AshlandsCombatBridge.encounter_id)
    if not FieldMemoryRuntime.boss_outcome_eligible(encounter_id):
        return
    if FieldMemoryRuntime.has_boss_outcome(encounter_id):
        return
    _add_boss_outcome_overlay(encounter_id)

func _add_boss_outcome_overlay(encounter_id: String) -> void:
    var blocker := ColorRect.new()
    blocker.name = "BossOutcomeDecision"
    blocker.color = Color(0.01, 0.01, 0.015, 0.94)
    blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    content.add_child(blocker)

    var box := VBoxContainer.new()
    box.position = Vector2(250, 92)
    box.size = Vector2(780, 500)
    box.add_theme_constant_override("separation", 18)
    blocker.add_child(box)

    var title := make_label("APRÈS LA VICTOIRE — QUE FAIRE DU VAINCU ?", 28, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var boss := make_label(FieldMemoryRuntime.boss_name(encounter_id), 21, TEXT)
    boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(boss)

    var prompt := make_label(FieldMemoryRuntime.boss_outcome_prompt(encounter_id), 17, MUTED)
    prompt.custom_minimum_size = Vector2(760, 90)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(prompt)

    var note := make_label(
        "Il n'existe pas ici de réponse moralement correcte imposée par le jeu. Les héros présents se souviendront du choix selon leurs propres convictions.",
        14,
        MUTED
    )
    note.custom_minimum_size = Vector2(760, 66)
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(note)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 18)
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(actions)

    actions.add_child(make_button(
        "ÉPARGNER\nLe laisser vivre",
        func(): _choose_boss_outcome(encounter_id, "spared"),
        Vector2(330, 72)
    ))
    actions.add_child(make_button(
        "ACHEVER\nMettre fin à la menace",
        func(): _choose_boss_outcome(encounter_id, "executed"),
        Vector2(330, 72)
    ))

func _choose_boss_outcome(encounter_id: String, outcome: String) -> void:
    var result := FieldMemoryRuntime.record_boss_outcome(encounter_id, outcome)
    if bool(result.get("applied", false)):
        SaveManager.save_game()
    clear_content()
    show_rewards()

func show_tavern() -> void:
    super.show_tavern()
    FieldMemoryRuntime.prepare_party()
    var political := DecisionMemoryRuntime.recent_memory_lines(2)
    var field := FieldMemoryRuntime.recent_field_memory_lines(2)
    var combined: Array[String] = []
    for line_value in field:
        if not combined.has(str(line_value)):
            combined.append(str(line_value))
    for line_value in political:
        if combined.size() >= 3:
            break
        if not combined.has(str(line_value)):
            combined.append(str(line_value))

    for node_value in content.find_children("*", "Label", true, false):
        var label := node_value as Label
        if label == null or not label.text.begins_with("MÉMOIRES DE DÉCISION"):
            continue
        label.text = "MÉMOIRES DE LA COMPAGNIE\n"
        if combined.is_empty():
            label.text += "Aucun choix majeur n'a encore assez marqué la compagnie pour revenir dans les conversations."
        else:
            label.text += "\n".join(combined)
        label.size = Vector2(1120, 74)
        break
