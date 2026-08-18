extends "res://scripts/ui/main_v3.gd"

# Combat v4 : le positionnement tactique v3 reste intact et les coups peuvent
# désormais préparer des démembrements fonctionnels via une jauge de trauma.

func show_combat() -> void:
    super.show_combat()
    if GameState.battle_enemies.is_empty():
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(target.get("hp", 0)) <= 0:
        return
    var status := DismembermentRuntime.status_text(target)
    var label := make_label("DÉMEMBREMENT · %s" % status, 12, MUTED)
    label.position = Vector2(760, 118)
    label.size = Vector2(470, 28)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(label)

func _hero_attack_action(hero: Dictionary, action: String) -> void:
    var target := _selected_target_for(hero, action)
    if target.is_empty():
        return
    var hp_before := int(target.get("hp", 0))
    super._hero_attack_action(hero, action)
    var inflicted := maxi(0, hp_before - int(target.get("hp", 0)))
    var result := DismembermentRuntime.register_hit(target, action, inflicted)
    _report_dismemberment(result)

func _technique_damage(hero: Dictionary, target: Dictionary, power: float) -> int:
    var damage := super._technique_damage(hero, target, power)
    if str(hero.get("id", "")) == "malvor":
        var result := DismembermentRuntime.register_hit(target, "technique", damage, "malvor_guard_break")
        _report_dismemberment(result)
    return damage

func _report_dismemberment(result: Dictionary) -> void:
    if not bool(result.get("severed", false)):
        return
    GameState.add_log("DÉMEMBREMENT — %s" % str(result.get("message", "Un membre est perdu.")))
    if bool(result.get("boss", false)):
        GameState.add_log("La perte de ce membre altère la mécanique du boss sans l'éliminer instantanément.")
