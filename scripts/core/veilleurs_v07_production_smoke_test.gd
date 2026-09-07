extends Node

const DB_SCRIPT := preload("res://scripts/core/veilleurs_content_db_v07.gd")
const PROGRESSION_SCRIPT := preload("res://scripts/core/veilleurs_progression_runtime.gd")
const RECRUITMENT_SCRIPT := preload("res://scripts/core/veilleurs_recruitment_runtime.gd")
const ARCHIVES_SCRIPT := preload("res://scripts/core/veilleurs_archives_runtime.gd")
const REFUGE_SCRIPT := preload("res://scripts/core/veilleurs_refuge_runtime.gd")
const TACTICAL_V07_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v07.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var db: VeilleursContentDBV07 = DB_SCRIPT.new() as VeilleursContentDBV07
    db.reload()
    var summary: Dictionary = db.production_summary()
    _check((summary.get("errors", []) as Array).is_empty(), "production ContentDB loads without errors")
    _check(int(summary.get("watchers", 0)) == 4, "four Watchers remain loaded")
    _check(int(summary.get("standard_enemies", 0)) == 24, "24 standard enemies remain loaded")
    _check(int(summary.get("bosses", 0)) == 5, "five bosses load")
    _check(int(summary.get("watcher_skills", 0)) == 180, "180 Watcher skills remain available")
    _check(int(summary.get("enemy_trees", 0)) == 72, "72 enemy trees load")
    _check(int(summary.get("enemy_skills", 0)) == 1080, "1080 enemy skills generate")
    _check(int(summary.get("boss_trees", 0)) == 15, "15 boss trees load")
    _check(int(summary.get("boss_skills", 0)) == 225, "225 boss skills generate")
    _check(int(summary.get("all_normal_skills", 0)) == 1485, "1485 normal skills total")
    _check(int(summary.get("khar_sen_nodes", 0)) == 18, "expanded Khar-Sen has 18 nodes")
    _check(int(summary.get("planned_dungeons", 0)) == 6, "six production dungeons planned")

    for enemy_id_value: Variant in db.enemies_by_id.keys():
        var enemy_id := str(enemy_id_value)
        _check(db.production_skills_for(enemy_id).size() == 45, "%s has 45 generated skills" % enemy_id)
    for boss_id_value: Variant in db.bosses_by_id.keys():
        var boss_id := str(boss_id_value)
        _check(db.production_skills_for(boss_id).size() == 45, "%s has 45 generated skills" % boss_id)
        _check(not bool(db.boss(boss_id).get("recruitable", true)), "%s cannot be recruited" % boss_id)

    var progression: VeilleursProgressionRuntime = PROGRESSION_SCRIPT.new() as VeilleursProgressionRuntime
    progression.configure(db.progression)
    var progress_state := progression.new_state("ENT_WATCHER_SAHEN", 1)
    progress_state = progression.unlock_skill(progress_state, db.skill("SK_SAHEN_BRISEUR_LIGNES_01"))
    _check(str(progress_state.get("chosen_tree", "")) == "TREE_SAHEN_BRISEUR_LIGNES", "first spent point locks Sahen tree")
    var blocked_state := progression.unlock_skill(progress_state, db.skill("SK_SAHEN_GARDIEN_MARTIAL_01"))
    _check(str(blocked_state.get("last_error", "")) == "tree_locked", "second Watcher tree is rejected")
    _check(progression.ultimate_charges_for_level(15) == 0, "ultimate unavailable before 16")
    _check(progression.ultimate_charges_for_level(16) == 1, "one ultimate charge at 16")
    _check(progression.ultimate_charges_for_level(32) == 2, "two ultimate charges at 32")
    _check(progression.ultimate_charges_for_level(48) == 3, "three ultimate charges at 48")
    var leveled := progression.gain_xp(progression.new_state("ENT_ENEMY_GOULE_AFFAMEE", 1), 1000000)
    _check(int(leveled.get("level", 0)) == 50, "captured/persistent combatant progression clamps at 50")

    var recruitment: VeilleursRecruitmentRuntime = RECRUITMENT_SCRIPT.new() as VeilleursRecruitmentRuntime
    recruitment.configure(db.recruitment)
    var candidate := {"entity_id":"ENT_ENEMY_GOULE_AFFAMEE", "family":"GOULES", "hp":10, "alive":true, "level":4, "traits":[]}
    var recruit_context := {"refuge_slots_free":6, "recruits_this_expedition":0, "condition_flags":["fed_without_exploitation","corpse_denied_then_spared"], "respect":2, "shared_event":0, "fear":0, "knowledge_level":1}
    var recruit_eval := recruitment.evaluate(candidate, recruit_context)
    _check(str(recruit_eval.get("outcome", "")) == "accept", "qualified Ghoul recruitment is accepted")
    var recruit_result := recruitment.recruit(candidate, recruit_context, [])
    _check(bool(recruit_result.get("ok", false)) and (recruit_result.get("roster", []) as Array).size() == 1, "accepted candidate enters roster")
    var boss_eval := recruitment.evaluate({"entity_id":"ENT_BOSS_GARDIEN_SEUIL", "family":"PORTE_CENDRES", "hp":100, "alive":true}, recruit_context)
    _check((boss_eval.get("blocked_by", []) as Array).has("boss"), "boss recruitment is structurally blocked")

    var archives: VeilleursArchivesRuntime = ARCHIVES_SCRIPT.new() as VeilleursArchivesRuntime
    archives.configure(db.archives)
    archives.record_identity("REM_TEST_ENEMY", "enemy", {"name":"Goule mémorielle"})
    for index in range(10):
        archives.record_combat_observation("REM_TEST_ENEMY", {"pattern":"pattern_%d" % index, "round":index})
    archives.record_body("REM_TEST_ENEMY", {"persistent_injuries":[{"zone":"left_arm","state":"L3"}]})
    archives.record_relation("REM_TEST_ENEMY", {"relation_id":"REL_TEST", "respect":2})
    var dossier := archives.dossier("REM_TEST_ENEMY")
    _check((dossier.get("observations", []) as Array).size() == 8, "Archives tactical observations remain bounded to eight")
    _check(int(dossier.get("knowledge_level", 0)) >= 2, "body knowledge raises dossier knowledge")
    var archive_copy: VeilleursArchivesRuntime = ARCHIVES_SCRIPT.new() as VeilleursArchivesRuntime
    archive_copy.configure(db.archives)
    archive_copy.deserialize(archives.serialize())
    _check(not archive_copy.dossier("REM_TEST_ENEMY").is_empty(), "Archives serialize and restore")

    var refuge: VeilleursRefugeRuntime = REFUGE_SCRIPT.new() as VeilleursRefugeRuntime
    refuge.configure_v07(db.economy)
    _check(refuge.recruit_slots() == 6, "Refuge starts with six recruit slots")
    refuge.add_rewards(1000, 100, 0)
    _check(bool(refuge.upgrade("BUILDING_FORGE").get("ok", false)), "Forge can upgrade with resources and dependency")
    for index in range(6):
        refuge.add_recruit({"entity_id":"RECRUIT_%d" % index})
    _check(not refuge.can_add_recruit(), "initial Refuge recruit capacity is enforced")
    refuge.resources["gold"] = 0
    var emergency := refuge.emergency_recovery(false)
    _check(bool(emergency.get("ok", false)) and int(refuge.resources.get("gold", 0)) > 0, "catastrophic softlock recovery grants emergency stock")

    var tactical: VeilleursTacticalCombatRuntimeV07 = TACTICAL_V07_SCRIPT.new() as VeilleursTacticalCombatRuntimeV07
    var tactical_setup := tactical.setup_first_combat(["ENT_ENEMY_GOULE_AFFAMEE"])
    _check(bool(tactical_setup.get("ok", false)), "v0.7 tactical runtime initializes")
    _check(str((tactical.combatants["ENT_ENEMY_GOULE_AFFAMEE"] as Dictionary).get("chosen_tree", "")) != "", "enemy receives persistent personal tree")
    tactical.grid.move("ENT_ENEMY_GOULE_AFFAMEE", Vector2i(1, 0))
    var ghoul_action := tactical.enemy_step("ENT_ENEMY_GOULE_AFFAMEE")
    _check(bool(ghoul_action.get("generated_skill", false)), "Ghoul executes a generated skill instead of generic basic attack")
    _check(str(ghoul_action.get("skill_id", "")).begins_with("SK_GOULE_AFFAMEE_"), "Ghoul action exposes authored generated skill ID")

    var ranged: VeilleursTacticalCombatRuntimeV07 = TACTICAL_V07_SCRIPT.new() as VeilleursTacticalCombatRuntimeV07
    var ranged_setup := ranged.setup_first_combat(["ENT_ENEMY_TIREUR"])
    _check(bool(ranged_setup.get("ok", false)), "ranged v0.7 encounter initializes")
    _check(ranged.set_enemy_level("ENT_ENEMY_TIREUR", 50), "Tireur level can be configured")
    _check(ranged.set_enemy_tree("ENT_ENEMY_TIREUR", "TREE_TIREUR_TIR_ANATOMIQUE"), "Tireur can use ranged personal tree")
    ranged.grid.move("ENT_ENEMY_TIREUR", Vector2i(4, 0))
    var ranged_action := ranged.enemy_step("ENT_ENEMY_TIREUR")
    _check(bool(ranged_action.get("generated_skill", false)), "Tireur executes generated ranged skill")
    _check(str(ranged_action.get("skill_id", "")).begins_with("SK_TIREUR_TIR_ANATOMIQUE_"), "Tireur uses ranged tree skill at distance")

    var boss_runtime: VeilleursTacticalCombatRuntimeV07 = TACTICAL_V07_SCRIPT.new() as VeilleursTacticalCombatRuntimeV07
    var boss_setup := boss_runtime.setup_boss_combat("ENT_BOSS_GARDIEN_SEUIL")
    _check(bool(boss_setup.get("ok", false)), "boss tactical setup initializes")
    _check(str(boss_setup.get("chosen_tree", "")) != "", "boss receives one of three personal trees")
    _check(boss_runtime.content_db.skills_for("ENT_BOSS_GARDIEN_SEUIL").size() == 45, "boss exposes 45 generated skills to tactical runtime")

    _check(int(db.recruitment.get("max_recruits_per_expedition", 0)) == 2, "recruitment cap per expedition is two")
    _check(int(db.recruitment.get("refuge_recruit_cap", 0)) == 12, "Refuge hard recruit cap is twelve")
    _check(int(db.progression.get("level_cap", 0)) == 50, "level cap is 50")
    _check((db.archives.get("tabs", []) as Array).size() == 5, "Archives expose five tabs")
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_V07_PRODUCTION_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V07_PRODUCTION: " + failure)
    print("VEILLEURS_V07_PRODUCTION_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
