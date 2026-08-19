extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    DialogueDirector.reset_run()
    await get_tree().process_frame

    for hero_id in ["aurelien", "malvor", "lysandra", "darius"]:
        _check(not DialogueDirector.voice_profile(hero_id).is_empty(), "Every starter hero must have a voice profile: " + hero_id)

    var discovery: Dictionary = DialogueDirector.request_line("discovery", {"speaker_id": "lysandra", "fourth_wall_allowed": false})
    _check(str(discovery.get("speaker_id", "")) == "lysandra", "Requested living speaker must be selected when an authored line exists")
    _check(not bool(discovery.get("fourth_wall", false)), "Ordinary discovery line must not become meta")

    DialogueDirector.reset_run()
    var direct_meta: Dictionary = DialogueDirector.request_line("choice_wait", {"speaker_id": "darius", "force_fourth_wall": true})
    _check(bool(direct_meta.get("fourth_wall", false)), "Forced test path must expose a fourth-wall line")
    _check(str(direct_meta.get("meta_level", "")) in ["fissure", "direct", "abyssal"], "Fourth-wall line must declare its intensity")

    DialogueDirector.reset_run()
    var critical: Dictionary = DialogueDirector.request_line("critical_story", {"critical_story": true, "force_fourth_wall": true})
    _check(str(critical.get("speaker_id", "")) == "narrator", "Critical story information must not depend on a mortal hero")
    _check(not bool(critical.get("fourth_wall", false)), "Fourth-wall dialogue must never carry critical story information")

    DialogueDirector.reset_run()
    var first_meta: Dictionary = DialogueDirector.request_line("choice_wait", {"speaker_id": "darius", "force_fourth_wall": true})
    var second_meta: Dictionary = DialogueDirector.request_line("choice_wait", {"speaker_id": "aurelien", "force_fourth_wall": true})
    var third_meta: Dictionary = DialogueDirector.request_line("idle_long", {"speaker_id": "lysandra", "force_fourth_wall": true})
    _check(bool(first_meta.get("fourth_wall", false)) and bool(second_meta.get("fourth_wall", false)), "Two fourth-wall fractures may occur in one expedition")
    _check(str(third_meta.get("mode", "")) == "silence", "Fourth-wall budget must stop a third meta line in the same expedition")
    _check(int(DialogueDirector.fourth_wall_state().get("count", 0)) == 2, "Fourth-wall counter must remain bounded")

    DialogueDirector.reset_run()
    var darius_index: int = _hero_index("darius")
    _check(darius_index >= 0, "Darius must exist in the starter party")
    if darius_index >= 0:
        var darius: Dictionary = GameState.party[darius_index]
        darius["hp"] = 0
        GameState.party[darius_index] = darius
        var dead_voice: Dictionary = DialogueDirector.request_line("combat_start", {"speaker_id": "darius", "fourth_wall_allowed": false})
        _check(str(dead_voice.get("mode", "")) == "silence", "A dead hero must never keep speaking through fallback substitution")
        var shared_event: Dictionary = DialogueDirector.request_line("combat_start", {"fourth_wall_allowed": false})
        _check(str(shared_event.get("speaker_id", "")) != "darius", "An event may continue with another living hero, never with the dead speaker")

    GameState.reset_new_game()
    DialogueDirector.reset_run()
    await get_tree().process_frame
    _finish()

func _hero_index(hero_id: String) -> int:
    for index in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[index]
        if str(hero.get("id", "")) == hero_id:
            return index
    return -1

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("DIALOGUE_DIRECTOR_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("DIALOGUE_DIRECTOR_SMOKE: " + failure)
    print("DIALOGUE_DIRECTOR_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
