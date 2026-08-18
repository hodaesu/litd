extends "res://scripts/ui/main_v11.gd"

# Combat v12 : interface anatomique lisible sans asset final.

func show_combat() -> void:
    super.show_combat()
    _decorate_full_anatomy_panel()

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
        var marker := "▶" if bool(row.get("selected", false)) else " "
        var state_text := _anatomy_state_label(state)
        var text := "%s %-22s %s · %d/%d" % [
            marker,
            str(row.get("name", row.get("id", "partie"))),
            state_text,
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
