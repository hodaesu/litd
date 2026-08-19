extends "res://scripts/ui/main_v18.gd"

# v19 : mémoire des décisions et convictions individuelles.
# Les convictions restent cachées comme valeurs numériques ; le joueur n'en voit
# que les traces narratives lorsque des choix reviennent dans la vie du groupe.

func show_tavern() -> void:
    super.show_tavern()
    DecisionMemoryRuntime.prepare_party()
    var lines := DecisionMemoryRuntime.recent_memory_lines(3)
    var text := "MÉMOIRES DE DÉCISION\n"
    if lines.is_empty():
        text += "Aucun choix politique n'a encore assez marqué la compagnie pour revenir dans les conversations."
    else:
        text += "\n".join(lines)
    var memory_label := make_label(text, 12, MUTED)
    memory_label.position = Vector2(40, 544)
    memory_label.size = Vector2(1120, 68)
    content.add_child(memory_label)
