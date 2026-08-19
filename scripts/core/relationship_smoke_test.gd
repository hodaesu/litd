extends Node

var failures: Array[String] = []

func run() -> void:
    GameState.reset_new_game()
    RelationshipRuntime.reset_battle_runtime()
    RelationshipRuntime.prepare_party()
    await _frames(2)

    _check(GameState.party.size() >= 2, "Relationship smoke requires at least two heroes")
    if GameState.party.size() < 2:
        _finish()
        return

    var actor: Dictionary = GameState.party[0]
    var target: Dictionary = GameState.party[1]
    var actor_id := str(actor.get("id", ""))
    var target_id := str(target.get("id", ""))

    var initial := RelationshipRuntime.relation(target, actor)
    _check(int(initial.get("trust", -1)) == 0, "New relationships must start without hidden affinity")
    _check(int(initial.get("admiration", -1)) == 0, "New relationships must start without hidden admiration")

    var critical_before := maxi(1, int(target.get("max_hp", 1)) / 5)
    RelationshipRuntime.record_heal(actor, target, critical_before)
    var healed_relation := RelationshipRuntime.relation(target, actor)
    _check(int(healed_relation.get("trust", 0)) == 10, "A critical heal must build trust through heal + critical-heal events")
    _check(int(healed_relation.get("admiration", 0)) == 5, "A critical heal must build admiration")
    _check(int(RelationshipRuntime.relation(actor, target).get("trust", 0)) == 1, "Supporting someone must also create a small actor-side bond")

    var target_to_actor := RelationshipRuntime.relation(target, actor)
    target_to_actor["trust"] = 70
    target["relationships"][actor_id] = target_to_actor
    var actor_to_target := RelationshipRuntime.relation(actor, target)
    actor_to_target["trust"] = 45
    actor["relationships"][target_id] = actor_to_target
    target["fear"] = 82
    target["hp"] = int(target.get("max_hp", 1))
    var enemy := {"name": "Prédateur de test", "fear": 8, "damage": [2, 3]}
    var protected := RelationshipRuntime.try_interpose(target, enemy, 1)
    _check(str(protected.get("id", "")) == actor_id, "A mutually trusted ally must be able to interpose for a terrified hero")
    var second_try := RelationshipRuntime.try_interpose(target, enemy, 1)
    _check(str(second_try.get("id", "")) == target_id, "The same protector must not interpose twice in one round")

    var modifiers := RelationshipRuntime.combat_modifiers(target)
    _check(int(modifiers.get("fear_resistance", 0)) >= 3, "Strong trust must give a small fear-resistance benefit while the ally lives")

    var grief_relation := RelationshipRuntime.relation(target, actor)
    grief_relation["trust"] = 85
    grief_relation["admiration"] = 60
    target["relationships"][actor_id] = grief_relation
    target["fear"] = 0
    actor["hp"] = 0
    RelationshipRuntime.reset_battle_runtime()
    RelationshipRuntime.on_hero_fallen(actor)
    _check(int(target.get("fear", 0)) == 12, "Losing a deeply trusted and admired ally must carry a larger fear cost")
    var fear_after_first_loss := int(target.get("fear", 0))
    RelationshipRuntime.on_hero_fallen(actor)
    _check(int(target.get("fear", 0)) == fear_after_first_loss, "A fall must only be recorded once per battle")

    actor["hp"] = maxi(1, int(actor.get("max_hp", 1)))
    var conversation := RelationshipRuntime.sanctuary_conversation()
    _check(bool(conversation.get("applied", false)), "The Sanctuary must be able to produce one meaningful pair conversation")
    _check(str(conversation.get("text", "")) != "", "A Sanctuary relationship scene must expose readable narrative text")

    var serialized := JSON.stringify(GameState.party)
    _check(serialized.contains("relationships"), "Relationship state must live inside the party payload for existing save persistence")
    _finish()

func _frames(count: int) -> void:
    for _index in range(count):
        await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("RELATIONSHIP_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("RELATIONSHIP_SMOKE: " + failure)
    print("RELATIONSHIP_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
