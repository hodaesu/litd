extends Area3D
class_name QATestDialogueNPC

var interaction_id := "qa_witness_dialogue"
var giver := {
    "id": "qa_witness",
    "name": "Ilyan, témoin d'essai",
    "role": "Archiviste du laboratoire",
    "location": "Salle de validation",
    "body_profile": {
        "posture": "attentive et prudente",
        "gesture": "désigne successivement le coffre et l'arène",
        "stance_height": 1.0,
        "lean": -0.015,
        "stillness": 0.65,
        "tempo": 0.95,
        "orientation": "directe"
    },
    "staging": {
        "idle": "Ilyan attend sans interrompre le déplacement du groupe.",
        "offered": "Il vérifie que le dialogue, la posture, les commandes et la fermeture de la fenêtre répondent correctement."
    }
}

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func interact() -> void:
    AshlandsRuntime.record_interaction(interaction_id)
    AshlandsRuntime.record_dialogue(interaction_id)
    QuestGiverPresentation.open_dialogue(giver, {}, "offered")
    HUDDirector.notify_interaction("Parler", str(giver.get("name", "Personnage")))

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player_party"):
        HUDDirector.notify_interaction("Parler", str(giver.get("name", "Personnage")))
