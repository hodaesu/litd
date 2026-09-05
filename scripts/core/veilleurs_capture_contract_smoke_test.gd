extends Node

const VeilleursCaptureRuntime := preload("res://scripts/core/veilleurs_capture_runtime.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _prepare_capture_scope()
    _test_t23_unmet_condition_explains_why()
    _test_t24_failed_capture_keeps_enemy_and_updates_resistance_intent()
    _test_t25_success_removes_enemy_to_auxiliaries_not_quartet()
    _finish()

func _prepare_capture_scope() -> void:
    GameState.reset_new_game()
    ContentScopeDirector.grant_capability("capture")
    CreatureManager.reset_new_game(23025)
    GameState.essence = 100

func _test_t23_unmet_condition_explains_why() -> void:
    var enemy := _capturable_enemy(20, 24)
    var preview := VeilleursCaptureRuntime.preview(enemy)
    _check(bool(preview.get("visible", false)), "Tests_48/T23 : le contrôle de capture doit être visible pour une espèce capturable")
    _check(not bool(preview.get("ready", true)), "Tests_48/T23 : une cible trop vigoureuse ne doit pas être admissible")
    _check(str(preview.get("reason_code", "")) == "target_too_strong", "Tests_48/T23 : la condition non remplie doit exposer un code de raison stable")
    _check(str(preview.get("reason_text", "")).contains("Affaiblir"), "Tests_48/T23 : le bouton/aperçu doit dire au joueur pourquoi le lien est impossible")

func _test_t24_failed_capture_keeps_enemy_and_updates_resistance_intent() -> void:
    RemanenceRuntime.reset_new_game()
    var enemy := _capturable_enemy(1, 24)
    var entity_id := RemanenceRuntime.prepare_enemy(enemy, "premier_voile")
    var before_resistance := int(enemy.get("remanence_capture_resistance", 0))
    var result := VeilleursCaptureRuntime.attempt(enemy, 100)
    _check(not bool(result.get("success", true)), "Tests_48/T24 : un jet supérieur à la chance doit échouer")
    _check(bool(result.get("consumed", false)), "Tests_48/T24 : le sceau tenté doit consommer son coût même en cas d'échec")
    _check(bool(result.get("target_remains_enemy", false)), "Tests_48/T24 : la cible doit rester ennemie après l'échec")
    _check(int(enemy.get("hp", 0)) > 0 and not bool(enemy.get("captured", false)), "Tests_48/T24 : l'échec ne doit ni tuer ni rallier la cible")
    _check(int(enemy.get("remanence_capture_resistance", 0)) > before_resistance, "Tests_48/T24 : la résistance au sceau doit augmenter immédiatement")
    _check(str(enemy.get("intent", "")) == "aggressive_rejection", "Tests_48/T24 : l'intention interne doit être actualisée vers un rejet agressif")
    _check(str(result.get("updated_intent", "")).contains("agress"), "Tests_48/T24 : le retour UI doit exposer la nouvelle intention agressive")
    var saw_failure_memory := false
    for event: Dictionary in RemanenceRuntime.recent_events(entity_id, 6):
        if str(event.get("type", "")) == "capture_escaped":
            saw_failure_memory = true
            break
    _check(saw_failure_memory, "Tests_48/T24 : l'échec doit devenir une preuve mémorielle pour les rencontres futures")

func _test_t25_success_removes_enemy_to_auxiliaries_not_quartet() -> void:
    CreatureManager.reset_new_game(25025)
    GameState.essence = 100
    var party_before := GameState.party.size()
    var auxiliaries_before := CreatureManager.captured_creatures.size()
    var enemy := _capturable_enemy(1, 24)
    GameState.battle_enemies = [enemy]
    var result := VeilleursCaptureRuntime.attempt(enemy, 1)
    _check(bool(result.get("success", false)), "Tests_48/T25 : un jet minimal sur cible admissible doit permettre la réussite")
    _check(bool(result.get("removed_from_combat", false)), "Tests_48/T25 : une cible ralliée doit être retirée proprement du combat")
    _check(int(enemy.get("hp", 1)) == 0 and bool(enemy.get("captured", false)), "Tests_48/T25 : l'instance ennemie doit être marquée résolue/capturée")
    _check(CreatureManager.captured_creatures.size() == auxiliaries_before + 1, "Tests_48/T25 : la recrue doit être enregistrée dans les auxiliaires")
    _check(GameState.party.size() == party_before, "Tests_48/T25 : la capture ne doit jamais ajouter un cinquième membre au quatuor des Veilleurs")
    _check(bool(result.get("auxiliary_only", false)), "Tests_48/T25 : le contrat doit identifier explicitement la recrue comme auxiliaire")

func _capturable_enemy(hp: int, max_hp: int) -> Dictionary:
    return {
        "id": 1,
        "species_id": "hungry_ghoul",
        "name": "Goule de contrat",
        "hp": hp,
        "max_hp": max_hp,
        "damage": [2, 4],
        "captured": false
    }

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    GameState.battle_enemies = []
    if failures.is_empty():
        print("VEILLEURS_CAPTURE_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_CAPTURE_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_CAPTURE_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
