extends Node

const CORPSE_UI_SCRIPT := preload("res://scripts/ui/veilleurs_corpse_context_ui.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GameState.reset_new_game()
    await get_tree().process_frame
    VeilleursSkillResolverRouter.reload()
    VeilleursSkillCatalog.reload()

    var summary: Dictionary = VeilleursSkillCatalog.catalog_summary()
    _check(int(summary.get("watchers", 0)) == 4, "Canonical catalog must contain four Watchers")
    _check(int(summary.get("trees", 0)) == 12, "Canonical catalog must contain twelve trees")
    _check(int(summary.get("skills", 0)) == 180, "Canonical catalog must contain 180 normal skills")
    _check(int(summary.get("ultimates", 0)) == 12, "Canonical catalog must contain twelve ultimates")
    _check((summary.get("load_errors", []) as Array).is_empty(), "Canonical catalog must load without errors")
    _check((VeilleursSkillResolverRouter.summary().get("load_errors", []) as Array).is_empty(), "Resolver router must load without errors")

    var original_ids := _party_ids(GameState.party)
    VeilleursVS001PlayableBridge.activate_watchers_party()
    await get_tree().process_frame
    _check(_party_ids(GameState.party) == ["nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"], "Runtime party must be the canonical Watcher quartet")
    _check(not _party_ids(GameState.party).has("aurelien"), "Aurélien must never enter the Watcher skill runtime")

    for hero_value: Variant in GameState.party:
        if not (hero_value is Dictionary):
            continue
        var hero: Dictionary = hero_value
        hero["level"] = 50
        hero["skill_points"] = 100
        hero["unlocked_skills"] = []
        hero["specialization"] = ""
        hero["combat_loadout"] = []
        HeroSkillManager.prepare_hero(hero)
        var branches: Array[String] = HeroSkillManager.branches_for(hero)
        _check(branches.size() == 3, "%s must expose three canonical trees" % str(hero.get("name", "Watcher")))
        for branch: String in branches:
            var nodes: Array = HeroSkillManager.skill_nodes(hero, branch)
            _check(nodes.size() == 15, "%s/%s must expose fifteen skills" % [str(hero.get("name", "Watcher")), branch])

    var nayra := _hero("nayra_orun")
    _check(not nayra.is_empty(), "Nayra must exist in the Watcher party")
    if not nayra.is_empty():
        var nayra_branches: Array[String] = HeroSkillManager.branches_for(nayra)
        var bastion_nodes: Array = HeroSkillManager.skill_nodes(nayra, nayra_branches[0])
        var brisure_nodes: Array = HeroSkillManager.skill_nodes(nayra, nayra_branches[1])
        var first_bastion := str((bastion_nodes[0] as Dictionary).get("id", ""))
        var first_brisure := str((brisure_nodes[0] as Dictionary).get("id", ""))
        _check(HeroSkillManager.can_unlock(nayra, first_bastion), "Nayra must be able to choose her first Bastion skill")
        _check(HeroSkillManager.unlock(nayra, first_bastion), "First canonical Watcher skill must unlock")
        _check(str(nayra.get("specialization", "")) == nayra_branches[0], "First Watcher skill must permanently choose its tree")
        _check(not HeroSkillManager.can_unlock(nayra, first_brisure), "A second Watcher tree must remain locked after specialization")
        var unsupported_profile: Dictionary = HeroSkillManager.combat_skill(nayra, first_bastion)
        _check(str(unsupported_profile.get("effect", "")) == "resolver_required", "Unsupported canonical skills must never collapse into generic damage")
        _check(not bool(unsupported_profile.get("manual_combat_usable", true)), "Unsupported canonical skill must not be manually equipable")
        _check(not HeroSkillManager.equip_combat_skill(nayra, 0, first_bastion), "Unsupported canonical skill must be rejected by loadout")

    _check(VeilleursSkillCatalog.ultimate_charges(15) == 0, "Ultimates must be locked before level 16")
    _check(VeilleursSkillCatalog.ultimate_charges(16) == 1, "Level 16 must grant one ultimate charge")
    _check(VeilleursSkillCatalog.ultimate_charges(32) == 2, "Level 32 must grant two ultimate charges")
    _check(VeilleursSkillCatalog.ultimate_charges(48) == 3, "Level 48 must grant three ultimate charges")
    _check(_ultimate_names_are_canonical(), "All twelve canonical ultimate names must be available through runtime")

    var aisha := _hero("aisha_maren")
    var tarek := _hero("tarek_senn")
    var aisha_node := _skill(aisha, "AÏ-ANA-12")
    var tarek_node := _skill(tarek, "TA-DIS-12")
    _check(str(aisha_node.get("resolver_status", "")) == "implemented" and str(aisha_node.get("activation_mode", "")) == "context_action", "Aïsha corpse analysis must use implemented context resolver")
    _check(str(tarek_node.get("resolver_status", "")) == "implemented" and str(tarek_node.get("activation_mode", "")) == "context_action", "Tarek corpse cover must use implemented context resolver")

    RemanenceRuntime.reset_new_game()
    var scar_id := RemanenceRuntime.create_world_scar(
        "vs001_canonical_smoke_corpse",
        "persistent_corpse",
        "regional",
        {
            "zone_id": VeilleursVS001WorldRuntime.ZONE_ID,
            "owner_name": "Goule témoin",
            "summary": "Un corps de validation persiste ici.",
            "corpse_state": "intact",
            "body_snapshot": {
                "persistent_injuries": [{"id":"deep_wound"}],
                "dismembered_parts": [],
                "anatomy_part_states": {"leg_left":"wounded"}
            }
        }
    )
    _check(not scar_id.is_empty(), "Smoke must create a persistent corpse WorldScar")

    var preview_before: Dictionary = VeilleursCorpseInteractionRuntime.preview(scar_id)
    _check(not _option_ids(preview_before).has("study_aisha"), "Aïsha corpse action must stay hidden before skill is known")
    _check(not _option_ids(preview_before).has("cover_tarek"), "Tarek corpse action must stay hidden before skill is known")
    _check(_irreversible_option(preview_before, "mutilate"), "Mutilation option must be explicitly marked irreversible")

    if not aisha.is_empty():
        (aisha.get("unlocked_skills", []) as Array).append("AÏ-ANA-12")
    if not tarek.is_empty():
        (tarek.get("unlocked_skills", []) as Array).append("TA-DIS-12")
    var preview_after: Dictionary = VeilleursCorpseInteractionRuntime.preview(scar_id)
    _check(_option_ids(preview_after).has("study_aisha"), "Aïsha corpse action must appear after Lecture des morts is known")
    _check(_option_ids(preview_after).has("cover_tarek"), "Tarek corpse action must appear after Derrière les morts is known")

    var move_result: Dictionary = VeilleursCorpseInteractionRuntime.execute(scar_id, "move")
    _check(bool(move_result.get("ok", false)), "Corpse move action must resolve")
    var moved_payload: Dictionary = (RemanenceRuntime.world_scars.get(scar_id, {}) as Dictionary).get("payload", {})
    _check((moved_payload.get("corpse_offset", []) as Array).size() == 3, "Corpse movement must persist a physical offset")

    var study_result: Dictionary = VeilleursCorpseInteractionRuntime.execute(scar_id, "study_aisha")
    _check(bool(study_result.get("ok", false)), "Aïsha corpse study must resolve")
    var studied_payload: Dictionary = (RemanenceRuntime.world_scars.get(scar_id, {}) as Dictionary).get("payload", {})
    _check(bool(studied_payload.get("studied_by_aisha", false)), "Aïsha study flag must persist in Remanence")

    var cover_result: Dictionary = VeilleursCorpseInteractionRuntime.execute(scar_id, "cover_tarek")
    _check(bool(cover_result.get("ok", false)), "Tarek corpse cover must resolve")
    var cover_payload: Dictionary = (RemanenceRuntime.world_scars.get(scar_id, {}) as Dictionary).get("payload", {})
    _check(bool(cover_payload.get("prepared_as_cover", false)), "Tarek cover state must persist in Remanence")

    var corpse_ui: VeilleursCorpseContextUI = CORPSE_UI_SCRIPT.new() as VeilleursCorpseContextUI
    add_child(corpse_ui)
    await get_tree().process_frame
    VeilleursCorpseInteractionRuntime.preview(scar_id)
    await get_tree().process_frame
    corpse_ui.call("_choose", "mutilate", true)
    var pre_confirm_payload: Dictionary = (RemanenceRuntime.world_scars.get(scar_id, {}) as Dictionary).get("payload", {})
    _check(int(pre_confirm_payload.get("postmortem_mutilation_count", 0)) == 0, "Choosing mutilation must not mutate corpse before explicit confirmation")
    _check(str(corpse_ui.pending_irreversible) == "mutilate", "Corpse UI must hold irreversible action pending confirmation")
    corpse_ui.call("_confirm", "mutilate")
    await get_tree().process_frame
    var post_confirm_payload: Dictionary = (RemanenceRuntime.world_scars.get(scar_id, {}) as Dictionary).get("payload", {})
    _check(int(post_confirm_payload.get("postmortem_mutilation_count", 0)) == 1, "Confirmed mutilation must persist exactly one postmortem alteration")
    corpse_ui.queue_free()

    _finish(original_ids)

func _ultimate_names_are_canonical() -> bool:
    var expected := {
        "nayra_orun": ["La Ligne ne rompt pas", "Le Poids du Mur", "Pas un de plus"],
        "tarek_senn": ["La Proie n’a plus d’ombre", "Les Sept Ouvertures", "Là où nul ne regarde"],
        "aisha_maren": ["Carte parfaite du vivant", "Tout ce qui peut être sauvé", "Le Dernier Battement"],
        "idris_vael": ["Le Verdict tombe", "Un seul mouvement", "Que l’ordre se brise"]
    }
    for watcher_id: String in expected.keys():
        var hero := _hero(watcher_id)
        if hero.is_empty():
            return false
        var names: Array[String] = []
        for branch: String in HeroSkillManager.branches_for(hero):
            names.append(str(HeroSkillManager.ultimate_for(hero, branch).get("name", "")))
        if names != expected[watcher_id]:
            return false
    return true

func _hero(hero_id: String) -> Dictionary:
    for value: Variant in GameState.party:
        if value is Dictionary and str((value as Dictionary).get("id", "")) == hero_id:
            return value
    return {}

func _skill(hero: Dictionary, skill_id: String) -> Dictionary:
    if hero.is_empty():
        return {}
    for branch: String in HeroSkillManager.branches_for(hero):
        for value: Variant in HeroSkillManager.skill_nodes(hero, branch):
            if value is Dictionary and str((value as Dictionary).get("id", "")) == skill_id:
                return value
    return {}

func _option_ids(preview: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for value: Variant in preview.get("options", []):
        if value is Dictionary:
            result.append(str((value as Dictionary).get("id", "")))
    return result

func _irreversible_option(preview: Dictionary, action_id: String) -> bool:
    for value: Variant in preview.get("options", []):
        if value is Dictionary:
            var option: Dictionary = value
            if str(option.get("id", "")) == action_id:
                return bool(option.get("irreversible", false))
    return false

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
    RemanenceRuntime.reset_new_game()
    if VeilleursVS001PlayableBridge.is_watcher_party_active():
        VeilleursVS001PlayableBridge.restore_previous_party()
    if not original_ids.is_empty() and _party_ids(GameState.party) != original_ids:
        failures.append("Smoke cleanup must restore the original party")
    if failures.is_empty():
        print("VEILLEURS_CANONICAL_SKILLS_CORPSES_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_CANONICAL_SKILLS_CORPSES_SMOKE: " + failure)
    print("VEILLEURS_CANONICAL_SKILLS_CORPSES_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
