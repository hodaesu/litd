extends Node

func _check(condition: bool, message: String) -> bool:
    if not condition:
        push_error(message)
        get_tree().quit(1)
        return false
    return true

func _ready() -> void:
    var runtime := VeilleursCombatSandboxRuntime.new()
    if not _check(bool(runtime.setup().get("ok", false)), "setup failed"): return

    # Formation: R1 -> R4 is logical data order; moving swaps occupied slots and costs AP.
    if not _check(int(runtime.heroes[0].get("formation_slot")) == 1, "Mathilde should start R1"): return
    var move := runtime.move_hero(0, 3, 1)
    if not _check(bool(move.get("ok", false)), "formation move failed"): return
    if not _check(int(runtime.heroes[0].get("formation_slot")) == 3, "Mathilde should reach R3"): return
    if not _check(int(runtime.heroes[2].get("formation_slot")) == 1, "Anouk should swap into R1"): return

    # Persistent control decays by completed round, not immediately.
    var control := runtime.apply_persistent_control(0, "trame_bound", 2, 15)
    if not _check(bool(control.get("ok", false)), "persistent control failed"): return
    if not _check(int(runtime.enemies[0].get("control_rounds")) == 2, "control duration should start at 2"): return

    # Synergy is explicit and temporary.
    var synergy := runtime.trigger_synergy(1, 0, "shared_guard")
    if not _check(bool(synergy.get("ok", false)), "shared guard synergy failed"): return
    if not _check(str(runtime.heroes[0].get("protected_by")) == "marec", "Marec should protect Mathilde"): return

    # Ultimate charge thresholds: locked before 16, then 1/2/3 at 16/32/48.
    if not _check(runtime.ultimate_charges_for_level(15) == 0, "ultimate must be locked before 16"): return
    if not _check(runtime.ultimate_charges_for_level(16) == 1, "level 16 should grant 1 charge"): return
    if not _check(runtime.ultimate_charges_for_level(32) == 2, "level 32 should grant 2 charges"): return
    if not _check(runtime.ultimate_charges_for_level(48) == 3, "level 48 should grant 3 charges"): return

    var ultimate := runtime.use_tree_ultimate(2, "trame", 16, 0)
    if not _check(bool(ultimate.get("ok", false)), "Anouk ultimate failed"): return
    if not _check(int(ultimate.get("charges_remaining")) == 0, "level-16 ultimate charge should be consumed"): return
    var second := runtime.use_tree_ultimate(2, "trame", 16, 0)
    if not _check(not bool(second.get("ok", true)) and str(second.get("reason")) == "no_ultimate_charge", "second level-16 ultimate must be blocked"): return

    # Finish one full round to tick persistent state.
    runtime.active_hero_index = 3
    runtime.end_active_turn()
    if not _check(int(runtime.enemies[0].get("control_rounds")) == 1, "persistent control should tick to 1"): return
    if not _check(str(runtime.heroes[0].get("synergy_state")) == "none", "synergy should reset after round"): return

    print("VEILLEURS_COMBAT_ADVANCED_SYSTEMS_SMOKE_OK")
    get_tree().quit(0)
