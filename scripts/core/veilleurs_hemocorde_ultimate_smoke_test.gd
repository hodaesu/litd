extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GameState.reset_new_game()
    ExpeditionManager.reset_new_game()
    await get_tree().process_frame
    VeilleursSkillResolverRouter.reload()
    VeilleursSkillCatalog.reload()
    var original_ids := _party_ids(GameState.party)
    VeilleursVS001PlayableBridge.activate_watchers_party()
    await get_tree().process_frame

    var aisha := _hero("aisha_maren")
    _check(not aisha.is_empty(), "Hemocorde ultimate smoke requires Aïsha Maren")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Veilleurs ultimate runtime")
    _check(ExpeditionManager.ultimate_uses_for_level(15) == 0, "Ultimate charges must remain locked before level 16")
    _check(ExpeditionManager.ultimate_uses_for_level(16) == 1, "Level 16 must grant one dungeon ultimate charge")
    _check(ExpeditionManager.ultimate_uses_for_level(32) == 2, "Level 32 must grant two dungeon ultimate charges")
    _check(ExpeditionManager.ultimate_uses_for_level(48) == 3, "Level 48 must grant three dungeon ultimate charges")

    aisha["level"] = 48
    aisha["specialization"] = "hemocorde"
    aisha["unlocked_skills"] = ["AÏ-HÉM-06", "AÏ-HÉM-08", "AÏ-HÉM-15"]
    ExpeditionManager.start_expedition(880048, "hemocorde_ultimate_smoke")
    await get_tree().process_frame

    var hemocorde_contract := VeilleursSkillResolverRouter.ultimate_contract(aisha, "hemocorde")
    var anatomy_contract := VeilleursSkillResolverRouter.ultimate_contract(aisha, "anatomie")
    _check(str(hemocorde_contract.get("status", "")) == "implemented", "Le Dernier Battement must have an implemented dedicated override")
    _check(str(hemocorde_contract.get("entrypoint", "")) == "VeilleursUltimateRuntime.resolve", "Hemocorde ultimate must use the dedicated ultimate runtime")
    _check(str(anatomy_contract.get("status", "")) == "required", "Other Aïsha ultimates must remain unimplemented in this lot")

    var unknown := _enemy(970, "Physiologie inconnue")
    unknown["hp"] = 30
    unknown["bleeding"] = 6
    VeilleursSkillResolverRouter.begin_ultimate_encounter([unknown])
    var unknown_status := VeilleursSkillResolverRouter.ultimate_status(aisha, "hemocorde", unknown, [unknown])
    _check(not bool(unknown_status.get("available", false)), "Le Dernier Battement must not work without target-bound vascular knowledge")
    _check(str(unknown_status.get("reason", "")) == "vascular_knowledge_required", "Unknown physiology must fail for the correct reason")
    _check(int(unknown_status.get("charges_remaining", -1)) == 3, "A failed ultimate eligibility check must not consume a charge")

    var healthy := _enemy(971, "Sujet connu mais sain")
    var healthy_part := _first_part(healthy)
    healthy["vascular_known_parts"] = {healthy_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    var healthy_status := VeilleursSkillResolverRouter.ultimate_status(aisha, "hemocorde", healthy, [healthy])
    _check(not bool(healthy_status.get("available", false)), "Known physiology alone must not make a healthy target eligible")
    _check(str(healthy_status.get("reason", "")) == "target_not_compromised_enough", "Healthy known physiology must fail the compromise gate")
    _check(int(healthy_status.get("charges_remaining", -1)) == 3, "Healthy target rejection must not consume a charge")

    VeilleursSkillResolverRouter.end_ultimate_encounter()
    var compromised := _enemy(972, "Sujet très compromis")
    var compromised_part := _first_part(compromised)
    compromised["vascular_known_parts"] = {compromised_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    compromised["hp"] = 30
    compromised["bleeding"] = 6
    VeilleursSkillResolverRouter.begin_ultimate_encounter([compromised])
    var ready := VeilleursSkillResolverRouter.ultimate_status(aisha, "hemocorde", compromised, [compromised])
    _check(bool(ready.get("available", false)), "A known, severely compromised target must enable Le Dernier Battement")
    _check(int(ready.get("charges_remaining", -1)) == 3, "Level 48 must initialize three charges for the expedition")

    var first := VeilleursSkillResolverRouter.resolve_ultimate(aisha, "hemocorde", compromised, [compromised])
    _check(bool(first.get("ok", false)), "Le Dernier Battement must resolve through the dedicated sequence")
    _check(bool(first.get("circulatory_collapse", false)), "The ultimate must produce a real circulatory collapse")
    _check(int(first.get("charges_remaining", -1)) == 2, "A successful ultimate must consume exactly one dungeon charge")
    _check(str(first.get("part_id", "")) == compromised_part, "The ultimate must strike a known vascular anatomy part")
    _check((first.get("presentation", {}) as Dictionary).get("beats", []) == ["focus", "contact", "silence", "collapse"], "The ultimate must expose its dedicated presentation sequence")
    _check(int(compromised.get("bleeding", 0)) >= 8, "The sequence must act on real bleeding rather than a parallel blood pool")

    var same_encounter := VeilleursSkillResolverRouter.ultimate_status(aisha, "hemocorde", compromised, [compromised])
    _check(not bool(same_encounter.get("available", false)), "The same ultimate cannot be used twice in one encounter")
    _check(str(same_encounter.get("reason", "")) == "ultimate_already_used_this_encounter", "Second use in one encounter must be rejected by the encounter limit")
    _check(int(same_encounter.get("charges_remaining", -1)) == 2, "Encounter rejection must not consume another charge")

    VeilleursSkillResolverRouter.end_ultimate_encounter()
    var boss := _enemy(973, "Boss en collapsus")
    boss["boss"] = true
    var boss_part := _first_part(boss)
    boss["vascular_known_parts"] = {boss_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    boss["hp"] = 20
    boss["bleeding"] = 9
    VeilleursSkillResolverRouter.begin_ultimate_encounter([boss])
    var boss_result := VeilleursSkillResolverRouter.resolve_ultimate(aisha, "hemocorde", boss, [boss])
    _check(bool(boss_result.get("ok", false)), "The ultimate must resolve on a terminally compromised boss")
    _check(not bool(boss_result.get("fatal_collapse", true)), "Bosses must not be automatically killed by the ultimate resolver")
    _check(int(boss.get("hp", 0)) >= 1, "The boss HP floor must remain causal and explicit")
    _check(int(boss_result.get("charges_remaining", -1)) == 1, "Second encounter use must consume the second dungeon charge")

    # A new expedition resets the dungeon charge pool, while the level thresholds stay authoritative.
    VeilleursSkillResolverRouter.end_ultimate_encounter()
    ExpeditionManager.reset_new_game()
    ExpeditionManager.start_expedition(880049, "hemocorde_ultimate_smoke_second_run")
    await get_tree().process_frame
    var terminal := _enemy(974, "Sujet terminal")
    var terminal_part := _first_part(terminal)
    terminal["vascular_known_parts"] = {terminal_part: {"certainty": 3, "observer_id": "aisha_maren"}}
    terminal["hp"] = 20
    terminal["bleeding"] = 9
    VeilleursSkillResolverRouter.begin_ultimate_encounter([terminal])
    var reset_status := VeilleursSkillResolverRouter.ultimate_status(aisha, "hemocorde", terminal, [terminal])
    _check(int(reset_status.get("charges_remaining", -1)) == 3, "A new expedition must restore the level-based charge pool")
    var terminal_result := VeilleursSkillResolverRouter.resolve_ultimate(aisha, "hemocorde", terminal, [terminal])
    _check(bool(terminal_result.get("ok", false)), "Terminal non-boss physiology must resolve the ultimate")
    _check(bool(terminal_result.get("fatal_collapse", false)), "A non-boss already in terminal circulatory failure may suffer a fatal collapse")
    _check(int(terminal.get("hp", -1)) == 0, "Fatal collapse must be the result of severe pre-existing compromise, not a healthy-target execution")

    # Wrong specialization never exposes the Hemocorde ultimate.
    aisha["specialization"] = "anatomie"
    VeilleursSkillResolverRouter.end_ultimate_encounter()
    var wrong_tree := _enemy(975, "Mauvais arbre")
    var wrong_part := _first_part(wrong_tree)
    wrong_tree["vascular_known_parts"] = {wrong_part: {"certainty": 3}}
    wrong_tree["hp"] = 20
    wrong_tree["bleeding"] = 9
    VeilleursSkillResolverRouter.begin_ultimate_encounter([wrong_tree])
    var wrong_status := VeilleursSkillResolverRouter.ultimate_status(aisha, "hemocorde", wrong_tree, [wrong_tree])
    _check(str(wrong_status.get("reason", "")) == "wrong_specialization", "The chosen tree must remain authoritative for ultimate access")

    _finish(original_ids)

func _enemy(enemy_id: int, name_value: String) -> Dictionary:
    var enemy := {
        "id": enemy_id,
        "combat_uid": "ultimate_smoke_%d" % enemy_id,
        "name": name_value,
        "hp": 140,
        "max_hp": 140,
        "damage": [7, 11],
        "fear": 0,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": [],
        "bleeding": 0
    }
    AnatomyRuntime.ensure_state(enemy)
    return enemy

func _first_part(enemy: Dictionary) -> String:
    AnatomyRuntime.ensure_state(enemy)
    var parts := AnatomyRuntime.targetable_parts(enemy)
    return str((parts[0] as Dictionary).get("id", "")) if not parts.is_empty() else ""

func _hero(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == hero_id:
            return value
    return {}

func _party_ids(party_value: Array) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in party_value:
        if value is Dictionary:
            result.append(str((value as Dictionary).get("id", "")))
    return result

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish(original_ids: Array[String]) -> void:
    VeilleursSkillResolverRouter.end_ultimate_encounter()
    ExpeditionManager.reset_new_game()
    if VeilleursVS001PlayableBridge.is_watcher_party_active():
        VeilleursVS001PlayableBridge.restore_previous_party()
    if not original_ids.is_empty() and _party_ids(GameState.party) != original_ids:
        failures.append("Hemocorde ultimate smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_HEMOCORDE_ULTIMATE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_HEMOCORDE_ULTIMATE_SMOKE: " + failure)
    print("VEILLEURS_HEMOCORDE_ULTIMATE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
