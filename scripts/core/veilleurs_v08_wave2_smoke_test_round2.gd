extends "res://scripts/core/veilleurs_v08_wave2_smoke_test.gd"

const DOCTRINE_V08_SCRIPT := preload("res://scripts/core/veilleurs_enemy_doctrine_runtime.gd")
const RUNTIME_V08_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v08.gd")

func _test_doctrines_and_real_skills() -> void:
    var doctrine: VeilleursEnemyDoctrineRuntime = DOCTRINE_V08_SCRIPT.new() as VeilleursEnemyDoctrineRuntime
    _check(doctrine.load_errors.is_empty(), "24-enemy doctrine data loads")
    _check(str(doctrine.doctrine("ENT_ENEMY_GOULE_AFFAMEE").get("doctrine", "")) == "predator", "Hungry Ghoul exposes predator doctrine")
    _check(str(doctrine.doctrine("ENT_ENEMY_CHIRURGIEN_NOIR").get("doctrine", "")) == "cruel_support", "Black Surgeon exposes support doctrine")

    var runtime: VeilleursTacticalCombatRuntimeV08 = RUNTIME_V08_SCRIPT.new() as VeilleursTacticalCombatRuntimeV08
    var setup := runtime.setup_first_combat(["ENT_ENEMY_GOULE_AFFAMEE", "ENT_ENEMY_ECORCHEUSE", "ENT_ENEMY_TIREUR"], "khar_sen")
    _check(bool(setup.get("ok", false)), "Wave 2 tactical runtime initializes")
    _check(runtime.combatants.has("ENT_WATCHER_NAYRA") and runtime.combatants.has("ENT_WATCHER_TAREK") and runtime.combatants.has("ENT_WATCHER_AISHA") and runtime.combatants.has("ENT_WATCHER_IDRIS"), "Wave 2 tactical runtime contains the canonical quartet")
    _check(not runtime.combatants.has("ENT_WATCHER_SAHEN") and not runtime.combatants.has("ENT_WATCHER_MIRA") and not runtime.combatants.has("ENT_WATCHER_NAREM") and not runtime.combatants.has("ENT_WATCHER_YSRA"), "obsolete quartet cannot re-enter Wave 2 runtime")
    _check(str((runtime.combatants["ENT_ENEMY_GOULE_AFFAMEE"] as Dictionary).get("remanence_id", "")) != "", "enemy receives Remanence identity at combat start")
    _check(runtime.set_enemy_level("ENT_ENEMY_GOULE_AFFAMEE", 50), "test Ghoul reaches full skill unlock")
    _check(runtime.set_enemy_tree("ENT_ENEMY_GOULE_AFFAMEE", "TREE_GOULE_AFFAMEE_ODEUR_SANG"), "test Ghoul selects authored hunter tree")
    runtime.round_index = 2
    _check(runtime.grid.move("ENT_ENEMY_GOULE_AFFAMEE", Vector2i(1, 1)), "Ghoul enters tactical range")
    var nayra: Dictionary = runtime.combatants["ENT_WATCHER_NAYRA"]
    nayra["hp"] = 25
    var nayra_body: VeilleursBodyComponent = nayra.get("body") as VeilleursBodyComponent
    nayra_body.apply_trauma("left_arm", 55)
    runtime.combatants["ENT_WATCHER_NAYRA"] = nayra
    var action := runtime.enemy_step("ENT_ENEMY_GOULE_AFFAMEE")
    _check(bool(action.get("ok", false)), "doctrine enemy produces action")
    _check(bool(action.get("generated_skill", false)), "enemy action resolves through one of the 1,080 real enemy skills")
    _check(str(action.get("skill_id", "")).begins_with("SK_GOULE_AFFAMEE_ODEUR_SANG"), "Ghoul uses skill from its locked personal tree")
    _check(bool(action.get("doctrine_used", false)), "doctrine layer participates in skill selection")
