extends "res://scripts/ui/main_v43.gd"

# v44 — raccorde le terrain tactique de GE01 au système de positions existant.
# Les héros conservent le contrat v42 (changement de rang = action). Un cadavre
# explicitement placé comme obstacle peut interdire un rang. Les ennemis utilisent
# la même topologie et peuvent dépenser leur action pour se repositionner.

const GE01_CORPSE_TACTICAL_SCRIPT := preload("res://scripts/core/veilleurs_corpse_tactical_runtime.gd")
var _ge01_corpse_tactical: RefCounted = GE01_CORPSE_TACTICAL_SCRIPT.new()

func show_combat() -> void:
    CombatPositionRuntime.initialize_battle(GameState.party, GameState.battle_enemies)
    super.show_combat()

func _render_combat_position_menu(hero: Dictionary) -> void:
    super._render_combat_position_menu(hero)
    if not _ge01_combat_active():
        return
    var panel := content.get_node_or_null("CombatPositionMenuV42") as Control
    if panel == null:
        return
    var corpse_ids := _ge01_corpse_ids()
    for node_value: Variant in panel.find_children("*", "Button", true, false):
        var button := node_value as Button
        if button == null or not button.text.begins_with("R"):
            continue
        var first_line := button.text.split("\n", false)[0]
        var rank_text := str(first_line).trim_prefix("R")
        if not rank_text.is_valid_int():
            continue
        var slot := int(rank_text) - 1
        if not bool(_ge01_corpse_tactical.call("can_move_to_slot", slot, corpse_ids, "hero")):
            button.disabled = true
            button.text = "R%d · ☠ BLOQUÉ\nCADAVRE" % (slot + 1)
            button.tooltip_text = "Un cadavre occupe cette ligne. Déplacez ou détruisez le corps avant d'y entrer."

func _change_combat_position_to(target_position: int) -> void:
    if _ge01_combat_active():
        var corpse_ids := _ge01_corpse_ids()
        if not bool(_ge01_corpse_tactical.call("can_move_to_slot", clampi(target_position, 0, 3), corpse_ids, "hero")):
            GameState.add_log("Déplacement impossible : un cadavre bloque R%d." % (clampi(target_position, 0, 3) + 1))
            combat_position_menu = true
            show_screen("combat")
            return
    super._change_combat_position_to(target_position)

func _clinical_enemy_attack_phase(attacking_enemies: Array) -> void:
    if not _ge01_combat_active():
        await super._clinical_enemy_attack_phase(attacking_enemies)
        return

    CombatPositionRuntime.initialize_battle(GameState.party, attacking_enemies)
    var remaining_attackers: Array = []
    for enemy_value: Variant in attacking_enemies:
        if not enemy_value is Dictionary:
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 0)) <= 0:
            remaining_attackers.append(enemy)
            continue
        var before := CombatPositionRuntime.position_of(enemy)
        var move_action: Dictionary = CombatPositionRuntime.enemy_move_action(enemy, attacking_enemies)
        if move_action.is_empty():
            remaining_attackers.append(enemy)
            continue
        var after := CombatPositionRuntime.position_of(enemy)
        GameState.add_log("%s se repositionne : R%d → R%d. Son action est consommée." % [
            str(enemy.get("name", "L'ennemi")), before + 1, after + 1
        ])
        var movement_reactions: Array[Dictionary] = _reaction_runtime().on_enemy_movement(
            enemy, before, after, combat_round_number, GameState.party
        )
        for reaction_value: Variant in movement_reactions:
            if reaction_value is Dictionary:
                _log_clinical_reaction(reaction_value, enemy, GameState.alive_heroes()[0] if not GameState.alive_heroes().is_empty() else {})

    if not remaining_attackers.is_empty():
        await super._clinical_enemy_attack_phase(remaining_attackers)

func _ge01_combat_active() -> bool:
    var runtime := get_node_or_null("/root/GE01Runtime")
    if runtime == null or not runtime.has_method("current_room"):
        return false
    return str(runtime.call("current_room")) in ["ge_04", "ge_09", "ge_11", "ge_12"] and not GameState.battle_enemies.is_empty()

func _ge01_corpse_ids() -> Array:
    var runtime := get_node_or_null("/root/GE01Runtime")
    if runtime == null or not runtime.has_method("tactical_corpse_context"):
        return []
    var context: Dictionary = runtime.call("tactical_corpse_context")
    return context.keys()
