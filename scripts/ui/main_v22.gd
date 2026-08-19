extends "res://scripts/ui/main_v21.gd"

# v22 : les quêtes secondaires émergentes sont présentées comme des histoires,
# pas comme des tâches. Le texte visible dépend de leur état et provient du
# contrat narratif de la quête, tandis que l'objectif jouable reste explicite.

func _render_quest_column() -> void:
    var header := make_label("QUÊTES NÉES DE LA CAMPAGNE", 18, GOLD)
    header.position = Vector2(846, 128)
    content.add_child(header)

    var quests: Array[Dictionary] = CommunityRuntime.quest_entries()
    if quests.is_empty():
        var empty := make_label(
            "Aucune histoire secondaire n'a encore émergé. Certaines n'existeront que si des personnes précises survivent, reviennent et ont encore quelque chose à demander.",
            14,
            MUTED
        )
        empty.position = Vector2(846, 166)
        empty.size = Vector2(390, 120)
        content.add_child(empty)
        return

    var y: float = 166.0
    for quest in quests:
        var quest_id: String = str(quest.get("id", ""))
        var state: String = str(quest.get("state", ""))
        var objective_value: Variant = quest.get("objective", {})
        var objective: Dictionary = objective_value if objective_value is Dictionary else {}
        var story_text: String = NarrativeLibrary.quest_state_text(quest, state)
        var label_text := "%s — %s\n%s" % [
            _quest_state_label(state),
            str(quest.get("name", quest_id)),
            story_text
        ]
        if state != "completed":
            label_text += "\nObjectif : %s" % str(objective.get("text", ""))
        else:
            var reframe: String = NarrativeLibrary.quest_reframe(quest)
            if reframe != "":
                label_text += "\nCe qui a changé : %s" % reframe

        var text := make_label(label_text, 12, TEXT if state != "completed" else MUTED)
        text.position = Vector2(846, y)
        text.size = Vector2(390, 176 if state != "completed" else 196)
        content.add_child(text)
        y += 184.0 if state != "completed" else 204.0

        if state == "offered":
            var accept := make_button(
                "ACCEPTER L'HISTOIRE",
                func(id_value = quest_id):
                    CommunityRuntime.accept_quest(str(id_value))
                    SaveManager.save_game()
                    show_screen("community"),
                Vector2(200, 42)
            )
            accept.position = Vector2(846, y)
            content.add_child(accept)
            y += 52.0
