extends "res://scripts/ui/main_v45.gd"

const GE01_SKILL_BRIDGE_SCRIPT := preload("res://scripts/core/veilleurs_ge01_skill_bridge.gd")
var _ge01_skill_bridge: RefCounted = GE01_SKILL_BRIDGE_SCRIPT.new()
var canonical_corpse_skill_pending: String = ""

func show_combat() -> void:
    super.show_combat()
    if _ge01_combat_active() and _ge01_room_id() == "ge_09":
        _decorate_canonical_ge01_skill_buttons()
        if canonical_corpse_skill_pending == "AÏ-ANA-12":
            _render_read_the_dead_targets()

func _decorate_canonical_ge01_skill_buttons() -> void:
    var hero := _active_combat_hero()
    if hero.is_empty(): return
    var loadout := HeroSkillManager.combat_loadout(hero)
    var corpse_ids := _ge01_corpse_ids()
    var target := _selected_living_enemy()
    var buttons := content.find_children("*", "Button", true, false)
    for slot in range(mini(HeroSkillManager.COMBAT_LOADOUT_SIZE, loadout.size())):
        var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
        var id := str(skill.get("id", ""))
        if not _ge01_skill_bridge.call("is_supported_skill", id): continue
        var preview: Dictionary = _ge01_skill_bridge.call("preview", hero, skill, target, corpse_ids)
        var prefix := "%d · " % (slot + 1)
        for node_value: Variant in buttons:
            var button := node_value as Button
            if button == null or not button.text.begins_with(prefix): continue
            button.tooltip_text += "\nGE09 · %s" % str(preview.get("summary", "Interaction tactique"))
            if id == "AÏ-ANA-12" and corpse_ids.is_empty(): button.disabled = true
            break

func _use_combat_skill(slot: int) -> void:
    var hero := _active_combat_hero()
    if not hero.is_empty() and _ge01_combat_active() and _ge01_room_id() == "ge_09":
        var loadout := HeroSkillManager.combat_loadout(hero)
        if slot >= 0 and slot < loadout.size():
            var skill := HeroSkillManager.combat_skill(hero, str(loadout[slot]))
            if str(skill.get("id", "")) == "AÏ-ANA-12":
                canonical_corpse_skill_pending = "AÏ-ANA-12"
                show_screen("combat")
                return
    await super._use_combat_skill(slot)

func _render_read_the_dead_targets() -> void:
    var corpse_ids := _ge01_corpse_ids()
    if corpse_ids.is_empty():
        canonical_corpse_skill_pending = ""
        return
    var panel := PanelContainer.new()
    panel.name = "ReadTheDeadTargetsV46"
    panel.position = Vector2(430, 330)
    panel.size = Vector2(790, 150)
    panel.z_index = 60
    panel.add_theme_stylebox_override("panel", panel_style(Color(0.015, 0.016, 0.022, 0.98)))
    content.add_child(panel)
    var box := VBoxContainer.new(); panel.add_child(box)
    box.add_child(make_label("LECTURE DES MORTS · choisir un cadavre à analyser", 13, GOLD))
    box.add_child(make_label("Conséquence : cause de mort + indice anatomique + connaissance persistante.", 11, CANON_TEXT))
    var row := HBoxContainer.new(); box.add_child(row)
    for index in range(corpse_ids.size()):
        var scar_id := str(corpse_ids[index])
        row.add_child(make_button("CADAVRE %d" % (index + 1), func(id = scar_id): _execute_read_the_dead(str(id)), Vector2(170, 48)))
    row.add_child(make_button("ANNULER", func(): canonical_corpse_skill_pending = ""; show_screen("combat"), Vector2(150, 48)))

func _execute_read_the_dead(scar_id: String) -> void:
    if battle_locked: return
    var hero := _active_combat_hero()
    var result: Dictionary = _ge01_skill_bridge.call("resolve_read_the_dead", hero, scar_id)
    if not bool(result.get("ok", false)):
        GameState.add_log("Lecture des morts impossible.")
        return
    GameState.add_log("Aïsha lit le cadavre : %s · %s" % [str(result.get("cause_or_clue", "indice inconnu")), str(result.get("anatomy_hint", ""))])
    canonical_corpse_skill_pending = ""
    battle_locked = true
    _complete_active_hero_turn()
