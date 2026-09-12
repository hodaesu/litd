extends Node

const CURRENT_QUARTET := [
    {"id": "marec", "name": "Marec"},
    {"id": "mathilde", "name": "Mathilde"},
    {"id": "anouk", "name": "Anouk"},
    {"id": "aurelien", "name": "Aurélien"}
]

const LEGACY_SKILL_PREFIXES := ["TA-ENT-", "AÏ-ANA-", "AÏ-SUT-", "AÏ-HÉM-"]

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    GameState.reset_new_game()
    await get_tree().process_frame
    VeilleursSkillResolverRouter.reload()
    VeilleursSkillCatalog.reload()

    var summary: Dictionary = VeilleursSkillCatalog.catalog_summary()
    _check(int(summary.get("watchers", 0)) == 4, "Current clinical smoke requires exactly four canonical Watchers")
    _check(int(summary.get("trees", 0)) == 12, "Current quartet must expose twelve canonical trees")
    _check(int(summary.get("skills", 0)) == 180, "Current quartet must expose 180 normal skills")
    _check((summary.get("load_errors", []) as Array).is_empty(), "Current quartet catalog must load without errors")
    _check((VeilleursSkillResolverRouter.summary().get("load_errors", []) as Array).is_empty(), "Skill resolver router must load without errors")

    var heroes: Array[Dictionary] = []
    for spec_value: Variant in CURRENT_QUARTET:
        var spec: Dictionary = spec_value
        var hero := {
            "id": str(spec.get("id", "")),
            "name": str(spec.get("name", "")),
            "level": 50,
            "skill_points": 100,
            "unlocked_skills": [],
            "specialization": "",
            "combat_loadout": [],
            "hp": 100,
            "max_hp": 100,
            "bleeding": 0
        }
        HeroSkillManager.prepare_hero(hero)
        heroes.append(hero)

        var branches: Array[String] = HeroSkillManager.branches_for(hero)
        _check(branches.size() == 3, "%s must expose three canonical trees" % str(hero.get("name", "Watcher")))
        var total_nodes := 0
        for branch: String in branches:
            var nodes: Array = HeroSkillManager.skill_nodes(hero, branch)
            total_nodes += nodes.size()
            _check(nodes.size() == 15, "%s/%s must expose fifteen skills" % [str(hero.get("name", "Watcher")), branch])
            for node_value: Variant in nodes:
                if not (node_value is Dictionary):
                    continue
                var skill_id := str((node_value as Dictionary).get("id", ""))
                for legacy_prefix: String in LEGACY_SKILL_PREFIXES:
                    _check(not skill_id.begins_with(legacy_prefix), "Legacy clinical skill IDs must not re-enter the current quartet catalog: %s" % skill_id)
        _check(total_nodes == 45, "%s must expose exactly 45 normal skills" % str(hero.get("name", "Watcher")))

    var marec: Dictionary = heroes[0]
    PersistentInjuryRuntime.prepare_character(marec)
    PersistentInjuryRuntime.apply_injury(marec, "fracture_leg", "serious")
    PersistentInjuryRuntime.apply_injury(marec, "deep_wound", "critical")
    marec["bleeding"] = 8
    _check(_has_injury(marec, "fracture_leg"), "Persistent fracture must be represented on a current Watcher")
    _check(_has_injury(marec, "deep_wound"), "Persistent deep wound must be represented on a current Watcher")
    _check(int(marec.get("bleeding", 0)) == 8, "Bleeding state must remain concrete and readable")

    var enemy := {
        "id": "clinical_target",
        "name": "Cible clinique",
        "hp": 120,
        "max_hp": 120,
        "damage": [6, 10],
        "fear": 10,
        "dismemberment_profile": "humanoid",
        "dismembered_parts": []
    }
    AnatomyRuntime.ensure_state(enemy)
    var targetable: Array = AnatomyRuntime.targetable_parts(enemy)
    _check(not targetable.is_empty(), "Clinical target must expose real anatomy parts")
    _check((enemy.get("anatomy_part_trauma", {}) as Dictionary).size() > 0, "Anatomy runtime must create concrete per-part trauma state")

    _check(VeilleursSkillCatalog.ultimate_charges(15) == 0, "Ultimates must stay locked before level 16")
    _check(VeilleursSkillCatalog.ultimate_charges(16) == 1, "Level 16 must grant one ultimate charge")
    _check(VeilleursSkillCatalog.ultimate_charges(32) == 2, "Level 32 must grant two ultimate charges")
    _check(VeilleursSkillCatalog.ultimate_charges(48) == 3, "Level 48 must grant three ultimate charges")

    _finish()

func _has_injury(character: Dictionary, injury_id: String) -> bool:
    for value: Variant in character.get("persistent_injuries", []):
        if value is Dictionary and str((value as Dictionary).get("id", "")) == injury_id:
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_ENTAILLE_ANATOMIE_SUTURE_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_ENTAILLE_ANATOMIE_SUTURE_SMOKE: " + failure)
    print("VEILLEURS_ENTAILLE_ANATOMIE_SUTURE_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
