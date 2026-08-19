extends "res://scripts/ui/main_v22.gd"

# v23 : les espaces du Sanctuaire et les moments narratifs pilotent désormais
# NarrativeAudioDirector. Les écrans sont déjà reliés par GameState.screen_requested ;
# cette couche ajoute le cas de la rumeur réellement racontée à la Taverne.

func _tavern_rumor() -> void:
    NarrativeAudioDirector.trigger_beat("rumor", {"tag": "tavern_rumor"})
    super._tavern_rumor()
