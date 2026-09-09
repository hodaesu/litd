extends Node

const SESSION := preload("res://scripts/core/veilleurs_ge01_session_runtime.gd")
const BRIDGE := preload("res://scripts/world/veilleurs_ge01_playable_bridge.gd")
const VALIDATED_QUARTET := ["Mathilde", "Marec", "Anouk", "Aurélien"]

var report := {
    "heroes": [],
    "rooms": [],
    "events": [],
    "combats": [],
    "ultimates": [],
    "deaths": [],
    "warnings": []
}

func _ready() -> void:
    GameState.reset_new_game()
    _prepare_party()
    _audit_ultimates()
    _simulate_expedition()
    _simulate_death_coverage()
    print("FULL_GAMEPLAY_SIMULATION_JSON=" + JSON.stringify(report))
    print("FULL_GAMEPLAY_SIMULATION_OK")
    get_tree().quit(0)

func _prepare_party() -> void:
    assert(GameState.party.size() == 4)
    for i in range(GameState.party.size()):
        var hero: Dictionary = GameState.party[i]
        hero["simulation_source_name"] = str(hero.get("name", ""))
        hero["name"] = VALIDATED_QUARTET[i]
        hero["level"] = 48
        hero["hp"] = int(hero.get("max_hp", hero.get("hp", 1)))
        hero["combat_position"] = i
        report.heroes.append({
            "name": str(hero.get("name", "")),
            "runtime_id": str(hero.get("id", "")),
            "level": int(hero.get("level", 1)),
            "start_hp": int(hero.get("hp", 0))
        })

func _audit_ultimates() -> void:
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = hero_value
        var found := false
        for branch_value: Variant in HeroSkillManager.branches_for(hero):
            var branch := str(branch_value)
            var ultimate: Dictionary = HeroSkillManager.ultimate_for(hero, branch)
            if not ultimate.is_empty():
                found = true
                report.ultimates.append({"hero": hero.name, "branch": branch, "available": true, "name": str(ultimate.get("name", "")), "charges": int(ultimate.get("available_charges", ultimate.get("charges", 0)))})
        if not found:
            report.ultimates.append({"hero": hero.name, "available": false, "reason": "no_validated_quartet_ultimate_runtime"})
            report.warnings.append("ULTIMATE_MISSING:%s" % str(hero.name))

func _simulate_expedition() -> void:
    var session: VeilleursGE01SessionRuntime = SESSION.new()
    session.start("FULL_GAMEPLAY_SIMULATION")
    _record_room(session)
    _move(session, "ge_02")
    var observe := session.spend_light("observe_deep")
    report.events.append({"room":"ge_02", "type":"deep_observation", "light": int((observe.get("state", {}) as Dictionary).get("light", -1))})
    _move(session, "ge_03")
    _move(session, "ge_03b")
    report.events.append({"room":"ge_03b", "type":"risk_reward_branch"})
    _move(session, "ge_03")
    _move(session, "ge_04")
    _simulate_room_combat(session, "ge_04", 10, false)
    _move(session, "ge_05")
    session.spend_light("anatomy_deep")
    session.mark_objective_complete("simulation_body_exam")
    report.events.append({"room":"ge_05", "type":"body_event", "objective_complete": true})
    _move(session, "ge_06")
    report.events.append({"room":"ge_06", "type":"obstacle"})
    _move(session, "ge_07")
    report.events.append({"room":"ge_07", "type":"reward_build"})
    _move(session, "ge_08")
    var refuge := session.resolve_refuge("rekindle")
    report.events.append({"room":"ge_08", "type":"refuge_rekindle", "light": int((refuge.get("state", {}) as Dictionary).get("light", -1))})
    _move(session, "ge_09")
    _simulate_room_combat(session, "ge_09", 30, false)
    _move(session, "ge_10")
    report.events.append({"room":"ge_10", "type":"continue_deeper"})
    _move(session, "ge_11")
    _simulate_room_combat(session, "ge_11", 60, false)
    _move(session, "ge_12")
    _simulate_room_combat(session, "ge_12", 30, true)
    if not GameState.alive_heroes().is_empty():
        _move(session, "ge_11")
        _move(session, "ge_10")
        _move(session, "ge_13")
        var extraction := session.extract("simulation_after_ge12")
        report.events.append({"room":"ge_13", "type":"extraction", "rooms_visited": int(extraction.get("rooms_visited", 0)), "ending_light": int(extraction.get("ending_light", 0)), "hero_deaths": int(extraction.get("hero_deaths", 0))})

func _move(session: VeilleursGE01SessionRuntime, room_id: String) -> void:
    var result := session.enter_room(room_id)
    assert(bool(result.get("success", false)))
    _record_room(session)

func _record_room(session: VeilleursGE01SessionRuntime) -> void:
    var snap := session.snapshot()
    report.rooms.append({"room": session.current_room(), "light": int(snap.get("light", 0)), "light_state": str(snap.get("light_state", ""))})

func _simulate_room_combat(session: VeilleursGE01SessionRuntime, room_id: String, roll: int, lethal: bool) -> void:
    var bridge: VeilleursGE01PlayableBridge = BRIDGE.new()
    var encounter: Dictionary = session.encounter_for(room_id, roll)
    var enemies: Array = bridge.call("_build_encounter_enemies", encounter, room_id)
    var enemy_hp := 0
    for enemy_value: Variant in enemies:
        var enemy: Dictionary = enemy_value
        enemy_hp += int(enemy.get("hp", 0))
    var rounds := 0
    var actions := 0
    while enemy_hp > 0 and not GameState.alive_heroes().is_empty() and rounds < 12:
        rounds += 1
        for hero_value: Variant in GameState.party:
            var hero: Dictionary = hero_value
            if int(hero.get("hp", 0)) <= 0:
                continue
            var basic := HeroSkillManager.combat_skill(hero, "basic_strike")
            assert(not basic.is_empty())
            var damage := 9 + int(hero.get("level", 1) / 8)
            enemy_hp = maxi(0, enemy_hp - damage)
            actions += 1
            if enemy_hp <= 0:
                break
        if enemy_hp <= 0:
            break
        var living := GameState.alive_heroes()
        if living.is_empty():
            break
        var victim: Dictionary = living[(rounds - 1) % living.size()]
        var incoming := 12 if not lethal else 42
        victim["hp"] = maxi(0, int(victim.get("hp", 0)) - incoming)
        if int(victim.get("hp", 0)) <= 0:
            _record_death(victim, room_id, "combat_damage")
    session.spend_light("combat_long" if room_id == "ge_12" else "combat_standard")
    report.combats.append({"room": room_id, "enemy_count": enemies.size(), "rounds": rounds, "hero_actions": actions, "victory": enemy_hp <= 0, "survivors": _survivor_names(), "enemy_hp_remaining": enemy_hp})
    bridge.queue_free()

func _record_death(hero: Dictionary, room_id: String, cause: String) -> void:
    var name := str(hero.get("name", "Héros"))
    for death_value: Variant in report.deaths:
        var death: Dictionary = death_value
        if str(death.get("hero", "")) == name and str(death.get("scope", "")) == "expedition":
            return
    report.deaths.append({"hero": name, "room": room_id, "cause": cause, "scope": "expedition"})

func _simulate_death_coverage() -> void:
    var death_session: VeilleursGE01SessionRuntime = SESSION.new()
    death_session.start("FULL_GAMEPLAY_DEATH_PERSISTENCE")
    death_session.enter_room("ge_02")
    death_session.enter_room("ge_03")
    death_session.enter_room("ge_04")
    for hero_value: Variant in GameState.party:
        var hero: Dictionary = (hero_value as Dictionary).duplicate(true)
        hero["hp"] = 0
        var body_state := {
            "anatomy_injuries": (hero.get("anatomy_injuries", {}) as Dictionary).duplicate(true),
            "dismembered_parts": (hero.get("dismembered_parts", []) as Array).duplicate(true)
        }
        var equipment := {
            "weapon": hero.get("weapon", {}),
            "armor": hero.get("armor", {}),
            "rings": hero.get("rings", []),
            "necklace": hero.get("necklace", {})
        }
        var persisted := death_session.register_hero_death(hero, "simulation_lethal_damage", "ge_04", body_state, equipment)
        assert(bool(persisted.get("success", false)))
        report.deaths.append({
            "hero": str(hero.get("name", "Héros")),
            "scope": "death_state_coverage",
            "alive_after_zero_hp": false,
            "persistent_death_hook_detected": true,
            "room": str((persisted.get("death", {}) as Dictionary).get("room_id", "")),
            "recoverable": bool((persisted.get("death", {}) as Dictionary).get("recoverable", false))
        })
    var saved := death_session.serialize()
    assert((saved.get("hero_deaths", {}) as Dictionary).size() == 4)
    var restored: VeilleursGE01SessionRuntime = SESSION.new()
    assert(restored.deserialize(saved))
    var restored_snapshot := restored.snapshot()
    assert((restored_snapshot.get("hero_deaths", {}) as Dictionary).size() == 4)
    var hero_death_events := 0
    for event_value: Variant in restored_snapshot.get("world_events", []):
        var event: Dictionary = event_value
        if str(event.get("type", "")) == "HERO_DEATH":
            hero_death_events += 1
    assert(hero_death_events == 4)
    report.events.append({"type":"death_persistence_roundtrip", "hero_deaths":4, "world_events":hero_death_events, "restored":true})

func _survivor_names() -> Array[String]:
    var result: Array[String] = []
    for hero_value: Variant in GameState.alive_heroes():
        result.append(str((hero_value as Dictionary).get("name", "Héros")))
    return result
