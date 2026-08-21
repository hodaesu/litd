extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    ExpeditionManager.reset_new_game()
    _check(not GameState.party.is_empty(), "A party is required for the first descent smoke test")

    ExpeditionManager.start_expedition(771001)
    var first_status := ExpeditionManager.first_descent_status("first_veil_crypts")
    _check(int(first_status.get("attempts", 0)) == 1, "The first dungeon entry must be attempt 1")
    _check(bool(first_status.get("eligible", false)), "Attempt 1 must be eligible for First Descent")

    var run: Dictionary = ExpeditionManager.roguelike_runtime.active_run
    run["boss_defeated"] = true
    run["rooms_cleared"] = 19
    run["deepest_depth"] = 5
    ExpeditionManager.roguelike_runtime.active_run = run
    if GameState.party.size() > 1:
        GameState.party[0]["hp"] = 0
        GameState.party[1]["level"] = maxi(4, int(GameState.party[1].get("level", 3)))

    var award := ExpeditionManager.return_to_hub("boss_defeated")
    _check(bool(award.get("unlocked", false)), "Boss victory on attempt 1 must unlock First Descent")
    _check(str(award.get("title", {}).get("name", "")) == "Celui qui n'a pas remonté", "The First Veil title must be awarded")
    _check(str(award.get("relic", {}).get("name", "")) == "Éclat du Premier Voile", "The First Veil relic must be awarded")

    var chronicles := ExpeditionManager.first_descent_chronicles()
    _check(chronicles.size() == 1, "Exactly one chronicle must be created for the achievement")
    if not chronicles.is_empty():
        var chronicle: Dictionary = chronicles[0]
        _check(int(chronicle.get("seed", 0)) == 771001, "Chronicle must record the dungeon seed")
        _check(int(chronicle.get("rooms_cleared", 0)) == 19, "Chronicle must record cleared rooms")
        _check(int(chronicle.get("deepest_depth", 0)) == 5, "Chronicle must record deepest depth")
        _check((chronicle.get("fallen", []) as Array).size() >= 1, "Chronicle must preserve fallen heroes")
        _check((chronicle.get("survivors", []) as Array).size() >= 1, "Chronicle must preserve survivors")

    var collection := ExpeditionManager.first_descent_collection()
    _check((collection.get("titles", {}) as Dictionary).has("title_never_ascended"), "Title collection must persist the reward")
    _check((collection.get("relics", {}) as Dictionary).has("first_veil_shard"), "Relic collection must persist the reward")
    _check((collection.get("achievements", {}) as Dictionary).has("first_descent_first_veil"), "Achievement collection must persist the reward")

    ExpeditionManager.start_expedition(771002)
    var second_status := ExpeditionManager.first_descent_status("first_veil_crypts")
    _check(int(second_status.get("attempts", 0)) == 2, "The second entry must increment the attempt counter")
    _check(not bool(second_status.get("eligible", true)), "Attempt 2 must never be eligible after a claimed First Descent")
    var second_run: Dictionary = ExpeditionManager.roguelike_runtime.active_run
    second_run["boss_defeated"] = true
    ExpeditionManager.roguelike_runtime.active_run = second_run
    var second_award := ExpeditionManager.return_to_hub("boss_defeated")
    _check(not bool(second_award.get("unlocked", false)), "The reward must not be farmable")
    _check(ExpeditionManager.first_descent_chronicles().size() == 1, "Repeated boss kills must not duplicate the chronicle")

    ExpeditionManager.reset_new_game()
    ExpeditionManager.start_expedition(771003)
    ExpeditionManager.return_to_hub("extracted")
    ExpeditionManager.start_expedition(771004)
    var post_extract_status := ExpeditionManager.first_descent_status("first_veil_crypts")
    _check(int(post_extract_status.get("attempts", 0)) == 2, "Extraction must consume the first attempt")
    _check(not bool(post_extract_status.get("eligible", true)), "A later run after extraction must not regain First Descent eligibility")
    _check(ExpeditionManager.first_descent_chronicles().is_empty(), "Extraction before the boss must not create a First Descent chronicle")
    ExpeditionManager.return_to_hub("extracted")

    if failures.is_empty():
        print("FIRST_DESCENT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("FIRST_DESCENT_SMOKE: " + failure)
    print("FIRST_DESCENT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
