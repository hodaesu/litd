extends "res://scripts/ui/main_v45.gd"

# v46 — Combat Sandbox 0.1 contextual inspection.
# The permanent HUD is deliberately minimal. Touching a hero/enemy hotspot opens
# read-only health/effect/anatomy information without consuming AP.

const COMBAT_CONTEXT_RUNTIME := preload("res://scripts/core/veilleurs_combat_context_runtime.gd")

var combat_context_actor_id: String = ""
var combat_context_side: String = ""
var combat_context_knowledge: Dictionary = {}

func show_combat() -> void:
    super.show_combat()
    _replace_verbose_combat_hud()
    _install_actor_inspection_hotspots()
    if combat_context_actor_id != "":
        _render_actor_context_panel()

func _replace_verbose_combat_hud() -> void:
    var old := content.get_node_or_null("CanonicalCombatHUD")
    if old != null:
        old.queue_free()
    var strip := PanelContainer.new()
    strip.name = "CombatMinimalHUDV46"
    strip.position = Vector2(905, 8)
    strip.size = Vector2(340, 58)
    strip.z_index = 30
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.add_theme_stylebox_override("panel", panel_style(Color(0.01, 0.01, 0.014, 0.78)))
    content.add_child(strip)
    var active := _active_combat_hero()
    var active_name := str(active.get("name", "Veilleur"))
    var ap := int(active.get("ap", active.get("action_points", 2)))
    strip.add_child(make_label("%s · %d PA · touchez un combattant pour examiner" % [active_name, ap], 11, CANON_TEXT))

func _install_actor_inspection_hotspots() -> void:
    # Hotspots are intentionally compact and semi-transparent. They sit close to
    # actor lanes instead of adding permanent stat panels.
    var hero_by_rank: Array[Dictionary] = [{}, {}, {}, {}]
    for hero_value: Variant in GameState.party:
        if not hero_value is Dictionary:
            continue
        var hero: Dictionary = hero_value
        var rank := clampi(int(hero.get("combat_position", 0)), 0, 3)
        hero_by_rank[rank] = hero
    for rank in range(4):
        var hero: Dictionary = hero_by_rank[rank]
        if hero.is_empty():
            continue
        # R1 -> R4 is right-to-left.
        var x := 790.0 - float(rank) * 118.0
        _add_actor_hotspot(hero, "hero", Vector2(x, 452), "R%d · %s" % [rank + 1, str(hero.get("name", "Veilleur"))])

    var enemy_rank := 0
    for enemy_value: Variant in GameState.battle_enemies:
        if not enemy_value is Dictionary:
            continue
        var enemy: Dictionary = enemy_value
        if int(enemy.get("hp", 1)) <= 0:
            continue
        var rank := clampi(int(enemy.get("combat_position", enemy_rank)), 0, 3)
        var x := 188.0 + float(rank) * 118.0
        _add_actor_hotspot(enemy, "enemy", Vector2(x, 158), "E%d · %s" % [rank + 1, str(enemy.get("name", "Ennemi"))])
        enemy_rank += 1

func _add_actor_hotspot(actor: Dictionary, side: String, pos: Vector2, label_text: String) -> void:
    var actor_id := str(actor.get("id", actor.get("instance_id", label_text)))
    var button := make_button(label_text, func(id = actor_id, s = side): _open_actor_context(str(id), str(s)), Vector2(112, 48))
    button.name = "Inspect_%s_%s" % [side, actor_id]
    button.position = pos
    button.z_index = 35
    button.modulate.a = 0.82
    button.tooltip_text = "Examiner sans consommer de PA"
    content.add_child(button)

func _open_actor_context(actor_id: String, side: String) -> void:
    combat_context_actor_id = actor_id
    combat_context_side = side
    show_screen("combat")

func _close_actor_context() -> void:
    combat_context_actor_id = ""
    combat_context_side = ""
    show_screen("combat")

func _context_actor() -> Dictionary:
    var source: Array = GameState.party if combat_context_side == "hero" else GameState.battle_enemies
    for value: Variant in source:
        if not value is Dictionary:
            continue
        var actor: Dictionary = value
        var candidate := str(actor.get("id", actor.get("instance_id", "")))
        if candidate == combat_context_actor_id:
            return actor
    return {}

func _render_actor_context_panel() -> void:
    var actor := _context_actor()
    if actor.is_empty():
        combat_context_actor_id = ""
        combat_context_side = ""
        return

    var normalized := _normalize_context_actor(actor, combat_context_side)
    var details: Dictionary = COMBAT_CONTEXT_RUNTIME.detailed_inspection(normalized, combat_context_knowledge)

    var panel := PanelContainer.new()
    panel.name = "CombatActorContextV46"
    panel.position = Vector2(350, 105)
    panel.size = Vector2(580, 410)
    panel.z_index = 90
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.012, 0.013, 0.018, 0.985)))
    content.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    panel.add_child(box)
    box.add_child(make_label("%s · EXAMEN" % str(details.get("name", "Combattant")), 20, CANON_GOLD))
    box.add_child(make_label("État %s · Douleur %s · Saignement %s · Psyché %s" % [
        _fr_state(str(details.get("vital_state", "unknown"))),
        _fr_state(str(details.get("pain_state", "unknown"))),
        _fr_state(str(details.get("bleeding_state", "unknown"))),
        _fr_state(str(details.get("psych_state", "unknown")))
    ], 13, CANON_TEXT))

    var effects: Array = details.get("priority_effects", [])
    var effect_lines: Array[String] = []
    for effect_value: Variant in effects:
        if effect_value is Dictionary:
            effect_lines.append(str((effect_value as Dictionary).get("name", (effect_value as Dictionary).get("id", "Effet"))))
        else:
            effect_lines.append(str(effect_value))
    var more := int(details.get("more_effects", 0))
    box.add_child(make_label("EFFETS · %s%s" % [" · ".join(effect_lines) if not effect_lines.is_empty() else "Aucun effet prioritaire", " · +%d" % more if more > 0 else ""], 12, CANON_TEXT))

    box.add_child(make_label("CORPS", 12, CANON_GOLD))
    var anatomy_lines: Array[String] = []
    for zone_value: Variant in details.get("anatomy", []):
        if not zone_value is Dictionary:
            continue
        var zone: Dictionary = zone_value
        anatomy_lines.append("%s · %s · armure %s · fonction %s" % [
            _zone_label_context(str(zone.get("id", ""))),
            _fr_state(str(zone.get("state", "unknown"))),
            _fr_state(str(zone.get("armor", "unknown"))),
            _fr_state(str(zone.get("function", "unknown")))
        ])
    var anatomy := make_label("\n".join(anatomy_lines), 11, CANON_MUTED)
    anatomy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(anatomy)

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 8)
    box.add_child(footer)
    footer.add_child(make_label("Consultation · 0 PA", 11, CANON_MUTED))
    footer.add_child(make_button("FERMER", func(): _close_actor_context(), Vector2(130, 48)))

func _normalize_context_actor(actor: Dictionary, side: String) -> Dictionary:
    var max_hp := maxi(1, int(actor.get("max_hp", actor.get("hp", 1))))
    var hp := clampi(int(actor.get("hp", max_hp)), 0, max_hp)
    var ratio := float(hp) / float(max_hp)
    var vital := "stable" if ratio > 0.66 else ("wounded" if ratio > 0.33 else ("critical" if hp > 0 else "agony"))
    var result := actor.duplicate(true)
    result["side"] = side
    result["vital_state"] = str(actor.get("vital_state", vital))
    result["public_vital_state"] = result["vital_state"]
    result["pain_state"] = str(actor.get("pain_state", "unknown" if side == "enemy" else "controlled"))
    result["bleeding_state"] = str(actor.get("bleeding_state", "unknown" if side == "enemy" else "none"))
    result["psych_state"] = str(actor.get("psych_state", "unknown" if side == "enemy" else "stable"))
    result["buffs"] = actor.get("buffs", [])
    result["debuffs"] = actor.get("debuffs", [])
    result["anatomy"] = actor.get("anatomy", actor.get("anatomy_state", {}))
    if side == "enemy":
        _seed_visible_enemy_context(result)
    return result

func _seed_visible_enemy_context(enemy: Dictionary) -> void:
    var enemy_id := str(enemy.get("id", enemy.get("instance_id", "")))
    if enemy_id.is_empty():
        return
    if not combat_context_knowledge.has(enemy_id):
        combat_context_knowledge[enemy_id] = {}
    var known: Dictionary = combat_context_knowledge[enemy_id]
    # Only directly visible information is seeded automatically.
    known["vital_state"] = str(enemy.get("public_vital_state", "unknown"))
    if enemy.has("visible_buffs"): known["buffs"] = (enemy.get("visible_buffs", []) as Array).duplicate(true)
    if enemy.has("visible_debuffs"): known["debuffs"] = (enemy.get("visible_debuffs", []) as Array).duplicate(true)

func _fr_state(value: String) -> String:
    return str({
        "stable":"stable", "controlled":"contrôlée", "none":"aucun",
        "wounded":"blessé", "critical":"critique", "agony":"agonie",
        "severe":"sévère", "light":"léger", "significant":"important",
        "impaired":"diminuée", "functional":"fonctionnelle", "injured":"lésé",
        "weak":"faible", "strong":"forte", "unknown":"inconnu"
    }.get(value, value))

func _zone_label_context(zone: String) -> String:
    return str({
        "head":"Tête", "torso":"Torse", "left_arm":"Bras gauche",
        "right_arm":"Bras droit", "left_leg":"Jambe gauche", "right_leg":"Jambe droite"
    }.get(zone, zone))
