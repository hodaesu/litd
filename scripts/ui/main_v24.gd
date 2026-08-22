extends "res://scripts/ui/main_v23.gd"

# v24 : le prototype visible utilise désormais la boucle roguelike d'ExpeditionManager.
# Cette couche remplace seulement expédition/combat/récompenses afin de préserver
# les écrans, la narration et les systèmes des versions précédentes.

var roguelike_room_reward: Dictionary = {}
var roguelike_last_summary: Dictionary = {}

const ROGUELIKE_COMBAT_TYPES: Array[String] = ["combat", "elite", "ambush", "creature", "boss"]

func refresh_header() -> void:
    super.refresh_header()
    if not ExpeditionManager.expedition_active or not is_instance_valid(root):
        return
    var header: Node = root.get_node_or_null("Header")
    if header == null:
        return
    var light_label: Label = header.get_node_or_null("Lumière") as Label
    var supplies_label: Label = header.get_node_or_null("Vivres") as Label
    if light_label != null:
        light_label.text = "✦ %d" % int(ExpeditionManager.inventory.get("light", 0))
    if supplies_label != null:
        supplies_label.text = "▣ %d" % int(ExpeditionManager.inventory.get("food", 0))

func show_expedition() -> void:
    var bg: TextureRect = full_texture("res://assets/backgrounds/crypts.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    if not ExpeditionManager.expedition_active:
        _render_roguelike_departure()
        return

    _render_roguelike_map()

func _render_roguelike_departure() -> void:
    var title := make_label("EXPÉDITION — SOUS LE PREMIER VOILE", 30, GOLD)
    title.position = Vector2(34, 24)
    content.add_child(title)

    var intro := make_label(
        "Chaque descente reconstruit le donjon. Les salles, raccourcis et dangers changent avec le seed. " +
        "La Lumière protège la compagnie, mais l'obscurité augmente la qualité du butin et l'Essence trouvée.",
        17,
        TEXT
    )
    intro.position = Vector2(34, 82)
    intro.size = Vector2(720, 120)
    content.add_child(intro)

    var rules_text := make_label(
        "MORT PERMANENTE\nLes héros tombés ne reviennent pas après le retour au Sanctuaire.\n\n" +
        "EXTRACTION\nTu peux sécuriser ton butin avant le boss, ou continuer plus profond.\n\n" +
        "INVENTAIRE\n20 emplacements maximum : les fournitures sont empilées, chaque relique occupe une place.",
        15,
        MUTED
    )
    rules_text.position = Vector2(34, 220)
    rules_text.size = Vector2(650, 250)
    content.add_child(rules_text)

    var supplies: Dictionary = ExpeditionManager.inventory
    var prep := make_label(
        "Préparation actuelle\nNourriture %d · Eau %d · Bandages %d · Lumière %d · Médecine %d" % [
            int(supplies.get("food", 0)),
            int(supplies.get("water", 0)),
            int(supplies.get("bandages", 0)),
            int(supplies.get("light", 0)),
            int(supplies.get("medicine", 0))
        ],
        16,
        GOLD
    )
    prep.position = Vector2(735, 110)
    prep.size = Vector2(500, 130)
    content.add_child(prep)

    var launch := make_button("DESCENDRE DANS LE DONJON", func(): _start_roguelike_expedition(), Vector2(480, 62))
    launch.position = Vector2(735, 275)
    content.add_child(launch)
    var back := make_button("RETOUR AU SANCTUAIRE", func(): GameState.request_screen("sanctuary"), Vector2(480, 52))
    back.position = Vector2(735, 352)
    content.add_child(back)

func _start_roguelike_expedition() -> void:
    ExpeditionManager.reset_to_full_resupply()
    ExpeditionManager.start_expedition()
    roguelike_room_reward = {}
    roguelike_last_summary = {}
    GameState.add_log("Le donjon se recompose derrière la Porte.")
    refresh_header()
    show_screen("expedition")

func _render_roguelike_map() -> void:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        GameState.add_log("Le runtime roguelike est indisponible.")
        return
    var active_run: Dictionary = runtime.active_run
    var dungeon: Array = ExpeditionManager.dungeon_layout()
    var current_room_id: String = str(active_run.get("current_room_id", ""))
    var visited: Array = active_run.get("visited", [])
    var risk: Dictionary = ExpeditionManager.current_risk_profile()

    var title := make_label("CARTE DU DONJON · SEED %d" % int(active_run.get("seed", 0)), 26, GOLD)
    title.position = Vector2(24, 16)
    content.add_child(title)

    var risk_text := make_label(
        "Profondeur %d · Lumière %d · Danger ×%.2f · Butin ×%.2f\nInventaire %d/%d" % [
            int(risk.get("depth", 1)),
            int(risk.get("light", 0)),
            float(risk.get("danger_multiplier", 1.0)),
            float(risk.get("loot_multiplier", 1.0)),
            ExpeditionManager.inventory_slots_used(),
            ExpeditionManager.inventory_capacity()
        ],
        15,
        TEXT
    )
    risk_text.position = Vector2(24, 58)
    risk_text.size = Vector2(610, 70)
    content.add_child(risk_text)

    var dim_button := make_button("ÉTEINDRE 1 LUMIÈRE", func():
        ExpeditionManager.deliberately_dim_light(1)
        GameState.add_log("La compagnie étouffe volontairement une source de lumière.")
        refresh_header()
        show_screen("expedition"), Vector2(220, 44))
    dim_button.position = Vector2(650, 54)
    dim_button.disabled = int(ExpeditionManager.inventory.get("light", 0)) <= 0
    content.add_child(dim_button)

    var extract := make_button("EXTRAIRE LE BUTIN", func(): _extract_roguelike_run("extracted"), Vector2(220, 44))
    extract.position = Vector2(885, 54)
    extract.disabled = visited.is_empty()
    content.add_child(extract)

    var map_scroll := ScrollContainer.new()
    map_scroll.position = Vector2(24, 132)
    map_scroll.size = Vector2(900, 500)
    content.add_child(map_scroll)
    var map_root := VBoxContainer.new()
    map_root.custom_minimum_size = Vector2(860, 0)
    map_root.add_theme_constant_override("separation", 9)
    map_scroll.add_child(map_root)

    var max_depth := 1
    for room_value in dungeon:
        var room_depth: int = int((room_value as Dictionary).get("depth", 1))
        max_depth = maxi(max_depth, room_depth)

    for depth in range(1, max_depth + 1):
        var depth_row := HBoxContainer.new()
        depth_row.add_theme_constant_override("separation", 8)
        map_root.add_child(depth_row)
        var depth_label := make_label("P%d" % depth, 14, MUTED)
        depth_label.custom_minimum_size = Vector2(42, 56)
        depth_row.add_child(depth_label)
        for room_value in dungeon:
            var room: Dictionary = room_value
            if int(room.get("depth", 1)) != depth:
                continue
            var room_id: String = str(room.get("id", ""))
            var known: bool = visited.has(room_id) or _room_is_reachable(room_id, current_room_id, visited, dungeon)
            var room_type: String = str(room.get("type", "unknown"))
            var label: String = "?"
            if known:
                label = _room_type_label(room_type)
            if room_id == current_room_id:
                label = "◆ " + label
            elif visited.has(room_id):
                label = "✓ " + label
            var room_button := make_button(label, func(id_value = room_id): _enter_roguelike_room(str(id_value)), Vector2(142, 56))
            room_button.disabled = not _room_is_reachable(room_id, current_room_id, visited, dungeon)
            if room_id == current_room_id:
                room_button.disabled = true
            depth_row.add_child(room_button)

    _render_roguelike_side_panel(active_run, risk)

func _render_roguelike_side_panel(active_run: Dictionary, risk: Dictionary) -> void:
    var panel := VBoxContainer.new()
    panel.position = Vector2(948, 132)
    panel.size = Vector2(300, 500)
    panel.add_theme_constant_override("separation", 8)
    content.add_child(panel)
    panel.add_child(make_label("SAC D'EXPÉDITION", 17, GOLD))

    var inv: Dictionary = ExpeditionManager.inventory
    panel.add_child(make_label(
        "Nourriture %d\nEau %d\nBandages %d\nLumière %d\nOutils %d\nMédecine %d" % [
            int(inv.get("food", 0)), int(inv.get("water", 0)), int(inv.get("bandages", 0)),
            int(inv.get("light", 0)), int(inv.get("camp_tools", 0)), int(inv.get("medicine", 0))
        ],
        13,
        TEXT
    ))
    panel.add_child(make_label("BUTIN", 16, GOLD))
    var cargo: Array = active_run.get("cargo", [])
    if cargo.is_empty():
        panel.add_child(make_label("Rien n'est encore sécurisé.", 12, MUTED))
    else:
        var cargo_lines: Array[String] = []
        for item_value in cargo.slice(0, 7):
            var item: Dictionary = item_value
            cargo_lines.append("%s · %s%s" % [
                str(item.get("rarity", "common")).to_upper(),
                "? " if not bool(item.get("identified", true)) else "",
                "MAUDIT" if bool(item.get("cursed", false)) else str(item.get("source", "relique"))
            ])
        panel.add_child(make_label("\n".join(cargo_lines), 11, MUTED))
    panel.add_child(make_label(
        "Or potentiel %d\nEssence potentielle %d\nPression : obscurité %.0f %%" % [
            int(active_run.get("gold_found", 0)),
            int(active_run.get("essence_found", 0)),
            float(risk.get("darkness", 0.0)) * 100.0
        ],
        12,
        TEXT
    ))

func _room_is_reachable(room_id: String, current_room_id: String, visited: Array, dungeon: Array) -> bool:
    if visited.is_empty():
        for room_value in dungeon:
            var start_room: Dictionary = room_value
            return room_id == str(start_room.get("id", ""))
        return false
    if room_id == current_room_id:
        return false
    var current: Dictionary = _dungeon_room_by_id(current_room_id, dungeon)
    if current.is_empty():
        return false
    return (current.get("connections", []) as Array).has(room_id)

func _dungeon_room_by_id(room_id: String, dungeon: Array) -> Dictionary:
    for room_value in dungeon:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            return room
    return {}

func _room_type_label(room_type: String) -> String:
    var labels := {
        "start": "ENTRÉE", "combat": "COMBAT", "elite": "ÉLITE", "ambush": "EMBUSCADE",
        "treasure": "TRÉSOR", "trap": "PIÈGE", "sanctuary": "SANCTUAIRE", "camp": "CAMP",
        "merchant": "MARCHAND", "survivor": "SURVIVANT", "creature": "CRÉATURE", "ruins": "RUINES",
        "puzzle": "ÉNIGME", "altar": "AUTEL", "secret": "SECRET", "anomaly": "ANOMALIE",
        "corpse": "CADAVRE", "boss": "BOSS"
    }
    return str(labels.get(room_type, room_type.to_upper()))

func _enter_roguelike_room(room_id: String) -> void:
    var result: Dictionary = ExpeditionManager.enter_dungeon_room(room_id)
    if not bool(result.get("success", false)):
        GameState.add_log("La salle ne peut pas être atteinte.")
        show_screen("expedition")
        return
    var room: Dictionary = result.get("room", {})
    var room_type: String = str(room.get("type", "combat"))
    var depth: int = int(room.get("depth", 1))
    GameState.add_log("Profondeur %d : %s." % [depth, _room_type_label(room_type)])
    refresh_header()

    if ROGUELIKE_COMBAT_TYPES.has(room_type):
        _start_roguelike_room_battle(room)
        return

    _resolve_noncombat_room(room)
    _mark_current_room_cleared()
    show_screen("rewards")

func _resolve_noncombat_room(room: Dictionary) -> void:
    roguelike_room_reward = {"room": room.duplicate(true), "loot": [], "gold": 0, "essence": 0, "message": ""}
    var room_type: String = str(room.get("type", ""))
    var depth: int = int(room.get("depth", 1))
    match room_type:
        "treasure", "secret", "anomaly", "ruins", "altar", "corpse":
            var item: Dictionary = ExpeditionManager.generate_roguelike_loot(depth, room_type, int(room.get("index", 0)))
            if not item.is_empty() and ExpeditionManager.add_loot_to_expedition(item):
                roguelike_room_reward["loot"] = [item]
                roguelike_room_reward["message"] = "Une relique rejoint le sac d'expédition."
            else:
                roguelike_room_reward["message"] = "Le sac est plein : la relique reste dans l'ombre."
            if room_type in ["ruins", "anomaly"]:
                ExpeditionManager.archive_expedition_lore(str(room.get("id", "")), {"type": room_type, "depth": depth, "seed": ExpeditionManager.expedition_seed})
        "camp":
            var camp_result: Dictionary = ExpeditionManager.use_campfire()
            if bool(camp_result.get("success", false)):
                var effects: Dictionary = camp_result.get("effects", {})
                var heal_ratio: float = float(effects.get("party_heal_ratio", 0.20))
                for hero_value in GameState.party:
                    var hero: Dictionary = hero_value
                    if int(hero.get("hp", 0)) > 0:
                        var max_hp: int = int(hero.get("max_hp", hero.get("hp", 1)))
                        hero["hp"] = mini(max_hp, int(hero.get("hp", 0)) + int(round(float(max_hp) * heal_ratio)))
                ExpeditionManager.reduce_pressure(int(effects.get("stress_reduction", 12)))
                roguelike_room_reward["message"] = "Le camp rend des forces et calme la peur."
            else:
                roguelike_room_reward["message"] = "Les réserves ne suffisent pas pour établir le camp."
        "trap":
            ExpeditionManager.apply_pressure(7 + depth, "dungeon_trap")
            roguelike_room_reward["message"] = "Le piège se referme ; la compagnie encaisse la pression."
        "sanctuary":
            ExpeditionManager.reduce_pressure(10 + depth)
            roguelike_room_reward["message"] = "Un sanctuaire oublié apaise la compagnie."
        "merchant":
            ExpeditionManager.add_resource("bandages", 1)
            roguelike_room_reward["message"] = "Le marchand échange des restes contre un bandage."
        "survivor":
            ExpeditionManager.add_resource("food", 1)
            ExpeditionManager.unlock_horizontal_meta("survivor_%s" % str(room.get("id", "")), {"depth": depth})
            roguelike_room_reward["message"] = "Un survivant partage une ration et laisse une piste pour les prochaines descentes."
        "puzzle":
            ExpeditionManager.unlock_horizontal_meta("puzzle_%s" % str(room.get("id", "")), {"depth": depth})
            roguelike_room_reward["message"] = "L'énigme révèle une nouvelle connaissance persistante."
        "start":
            roguelike_room_reward["message"] = "La Porte se referme. Le seul chemin est désormais devant."
        _:
            roguelike_room_reward["message"] = "La salle ne livre rien d'évident."

func _start_roguelike_room_battle(room: Dictionary) -> void:
    GameState.battle_enemies = []
    var room_type: String = str(room.get("type", "combat"))
    var depth: int = int(room.get("depth", 1))
    var ids: Array[int] = [1, 8, 10]
    if room_type == "elite":
        ids = [10, 10, 8]
    elif room_type == "ambush":
        ids = [8, 8, 1]
    elif room_type == "creature":
        ids = [10]
    elif room_type == "boss":
        ids = [38]
    for enemy_id in ids:
        var enemy: Dictionary = DataLoader.find_by_id(DataLoader.enemies, enemy_id).duplicate(true)
        if enemy.is_empty():
            continue
        var base_hp: int = int(enemy.get("hp", 1))
        var depth_scale: float = 1.0 + float(depth - 1) * 0.10
        var risk: Dictionary = ExpeditionManager.current_risk_profile()
        enemy["hp"] = maxi(1, int(round(float(base_hp) * depth_scale * float(risk.get("danger_multiplier", 1.0)))))
        enemy["max_hp"] = int(enemy["hp"])
        enemy["guarding"] = false
        if room_type == "boss":
            enemy["boss"] = true
            enemy["is_boss"] = true
        GameState.battle_enemies.append(enemy)
        ExpeditionManager.record_enemy_knowledge(str(enemy.get("id", enemy_id)), false)
    battle_locked = false
    selected_enemy = 0
    GameState.add_log("La salle verrouille ses issues. Le combat commence.")
    GameState.request_screen("combat")

func hero_action(action: String) -> void:
    if action != "capture" or not ExpeditionManager.expedition_active:
        super.hero_action(action)
        return
    if battle_locked:
        return
    battle_locked = true
    var living_targets: Array = GameState.alive_enemies()
    if living_targets.is_empty():
        finish_victory()
        return
    selected_enemy = clampi(selected_enemy, 0, GameState.battle_enemies.size() - 1)
    var capture_target: Dictionary = GameState.battle_enemies[selected_enemy]
    if int(capture_target.get("hp", 0)) <= 0:
        capture_target = living_targets[0]
    var zone_id: String = _current_roguelike_room_id()
    var gate: Dictionary = ExpeditionManager.capture_check(capture_target, zone_id)
    if not bool(gate.get("allowed", false)):
        GameState.add_log(_capture_denial_message(str(gate.get("reason", "capture_denied"))))
        battle_locked = false
        show_screen("combat")
        return
    var capture_result: Dictionary = CreatureManager.attempt_capture(capture_target)
    GameState.add_log(str(capture_result.get("message", "Le sceau échoue.")))
    if bool(capture_result.get("success", false)):
        ExpeditionManager.register_roguelike_capture(capture_target, zone_id)
        CaptureWoundRuntime.apply_to_latest_capture(capture_target)
        ExpeditionManager.record_enemy_knowledge(str(capture_target.get("id", "unknown")), true)
        if GameState.alive_enemies().is_empty():
            finish_victory()
            return
    if bool(capture_result.get("consumed", false)):
        enemy_turn()
    else:
        battle_locked = false
        show_screen("combat")

func _capture_denial_message(reason: String) -> String:
    match reason:
        "boss_not_capturable": return "Cette présence ne peut pas être liée : les boss et l'Ange restent hors de portée."
        "manifestation_destructrice": return "La Manifestation destructrice brise toute tentative de lien."
        "enemy_not_wounded_enough": return "La cible doit être davantage blessée avant la capture."
        "zone_capture_limit": return "Deux créatures ont déjà été liées dans cette zone."
        _: return "La capture est impossible dans ces conditions."

func finish_victory() -> void:
    if not ExpeditionManager.expedition_active:
        super.finish_victory()
        return
    var runtime: Node = ExpeditionManager.roguelike_runtime
    var active_run: Dictionary = runtime.active_run if runtime != null else {}
    var room: Dictionary = _current_roguelike_room()
    var depth: int = int(room.get("depth", maxi(1, int(active_run.get("deepest_depth", 1)))))
    var room_type: String = str(room.get("type", "combat"))
    var risk: Dictionary = ExpeditionManager.current_risk_profile()
    var gold_gain: int = maxi(6, int(round((10.0 + float(depth) * 4.0) * float(risk.get("loot_multiplier", 1.0)))))
    var essence_gain: int = maxi(1, int(round((1.0 + float(depth)) * float(risk.get("essence_multiplier", 1.0)))))
    active_run["gold_found"] = int(active_run.get("gold_found", 0)) + gold_gain
    active_run["essence_found"] = int(active_run.get("essence_found", 0)) + essence_gain
    if room_type == "boss":
        active_run["boss_defeated"] = true
    if runtime != null:
        runtime.active_run = active_run

    for enemy_value in GameState.battle_enemies:
        var enemy: Dictionary = enemy_value
        if not bool(enemy.get("captured", false)):
            ExpeditionManager.record_enemy_knowledge(str(enemy.get("id", "unknown")), true)

    var loot: Dictionary = ExpeditionManager.generate_roguelike_loot(depth, room_type, int(room.get("index", 0)) + GameState.battle_enemies.size())
    var loot_added: bool = not loot.is_empty() and ExpeditionManager.add_loot_to_expedition(loot)
    roguelike_room_reward = {
        "room": room.duplicate(true),
        "loot": [loot] if loot_added else [],
        "gold": gold_gain,
        "essence": essence_gain,
        "message": "Le combat est gagné. Le butin n'est sécurisé qu'en cas d'extraction."
    }
    _mark_current_room_cleared()
    CreatureManager.grant_active_xp(30 + depth * 5)
    for hero_value in GameState.party:
        HeroSkillManager.grant_xp(hero_value, 30 + depth * 5)
    GameState.add_log("Victoire : +%d or potentiel, +%d essence potentielle." % [gold_gain, essence_gain])
    GameState.request_screen("rewards")

func finish_defeat() -> void:
    if not ExpeditionManager.expedition_active:
        super.finish_defeat()
        return
    roguelike_last_summary = ExpeditionManager.extraction_summary()
    GameState.add_log("La descente s'achève. Les morts sont inscrits au registre.")
    ExpeditionManager.return_to_hub("defeat")
    SaveManager.save_game()
    refresh_header()
    GameState.request_screen("sanctuary")

func show_rewards() -> void:
    if not ExpeditionManager.expedition_active:
        super.show_rewards()
        return
    var bg: TextureRect = full_texture("res://assets/backgrounds/ossuary.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.66)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var room: Dictionary = roguelike_room_reward.get("room", _current_roguelike_room())
    var box := VBoxContainer.new()
    box.position = Vector2(170, 90)
    box.size = Vector2(940, 535)
    box.add_theme_constant_override("separation", 11)
    content.add_child(box)
    box.add_child(make_label("%s — PROFONDEUR %d" % [_room_type_label(str(room.get("type", "salle"))), int(room.get("depth", 1))], 28, GOLD))
    box.add_child(make_label(str(roguelike_room_reward.get("message", "La salle est franchie.")), 16, TEXT))

    var loot: Array = roguelike_room_reward.get("loot", [])
    if not loot.is_empty():
        for item_value in loot:
            var item: Dictionary = item_value
            box.add_child(make_label(
                "Butin : %s · %s%s · affixes : %s" % [
                    str(item.get("rarity", "common")).to_upper(),
                    "NON IDENTIFIÉE" if not bool(item.get("identified", true)) else "relique",
                    " · MAUDITE" if bool(item.get("cursed", false)) else "",
                    ", ".join(item.get("affixes", []))
                ],
                14,
                GOLD
            ))
    var summary: Dictionary = ExpeditionManager.extraction_summary()
    box.add_child(make_label(
        "Butin de run : %d relique(s) · %d or potentiel · %d essence potentielle · profondeur maximale %d" % [
            (summary.get("cargo", []) as Array).size(),
            int(summary.get("gold_found", 0)),
            int(summary.get("essence_found", 0)),
            int(summary.get("deepest_depth", 0))
        ],
        14,
        MUTED
    ))

    var runtime: Node = ExpeditionManager.roguelike_runtime
    var boss_defeated: bool = runtime != null and bool((runtime.active_run as Dictionary).get("boss_defeated", false))
    if boss_defeated:
        box.add_child(make_label("Le cœur du donjon est vaincu. La sortie peut être forcée.", 17, GOLD))
        box.add_child(make_button("EXTRAIRE APRÈS LE BOSS", func(): _extract_roguelike_run("boss_defeated"), Vector2(520, 58)))
    else:
        box.add_child(make_button("CONTINUER PLUS PROFOND", func(): GameState.request_screen("expedition"), Vector2(520, 58)))
        box.add_child(make_button("EXTRAIRE ET SÉCURISER", func(): _extract_roguelike_run("extracted"), Vector2(520, 54)))

func _extract_roguelike_run(reason: String) -> void:
    if not ExpeditionManager.expedition_active:
        GameState.request_screen("sanctuary")
        return
    var summary: Dictionary = ExpeditionManager.extraction_summary()
    roguelike_last_summary = summary.duplicate(true)
    GameState.gold += int(summary.get("gold_found", 0))
    GameState.essence += int(summary.get("essence_found", 0))
    ExpeditionManager.return_to_hub(reason)
    SaveManager.save_game()
    GameState.add_log("Extraction réussie : le butin et les connaissances sont sécurisés.")
    refresh_header()
    GameState.request_screen("sanctuary")

func _current_roguelike_room_id() -> String:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        return ""
    return str((runtime.active_run as Dictionary).get("current_room_id", ""))

func _current_roguelike_room() -> Dictionary:
    var room_id: String = _current_roguelike_room_id()
    return _dungeon_room_by_id(room_id, ExpeditionManager.dungeon_layout())

func _mark_current_room_cleared() -> void:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        return
    var active_run: Dictionary = runtime.active_run
    var room_id: String = str(active_run.get("current_room_id", ""))
    var dungeon: Array = active_run.get("dungeon", [])
    for room_value in dungeon:
        var room: Dictionary = room_value
        if str(room.get("id", "")) == room_id:
            room["cleared"] = true
            break
    active_run["dungeon"] = dungeon
    runtime.active_run = active_run
