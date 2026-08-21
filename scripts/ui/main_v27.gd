extends "res://scripts/ui/main_v26.gd"

# v27 : première passe jouable des Cryptes du Premier Voile comme espace réel.
# La carte devient une carte macro/fog-of-war ; cliquer un nœud entre dans une
# vraie salle logique. Les combats et événements partent de cette salle, puis le
# joueur y revient avant de choisir un passage physique vers la suivante.

const FIRST_VEIL_DUNGEON_RUNTIME := preload("res://scripts/core/first_veil_dungeon_runtime.gd")
var first_veil_dungeon: RefCounted = FIRST_VEIL_DUNGEON_RUNTIME.new()

func show_screen(name: String) -> void:
    if name == "dungeon_room":
        GameState.current_screen = name
        clear_content()
        show_dungeon_room()
        call_deferred("_postprocess_mobile_screen")
        return
    super.show_screen(name)

func _ensure_physical_first_veil() -> Dictionary:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null or not ExpeditionManager.expedition_active:
        return {"initialized": false, "reason": "no_active_expedition"}
    var result: Dictionary = first_veil_dungeon.ensure_run(runtime)
    if bool(result.get("initialized", false)):
        GameState.add_log("Les Cryptes prennent forme : chaque nœud correspond désormais à une salle réelle.")
        SaveManager.save_game()
    return result

func _render_roguelike_map() -> void:
    _ensure_physical_first_veil()
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        GameState.add_log("Le runtime roguelike est indisponible.")
        return
    var active_run: Dictionary = runtime.active_run
    var dungeon: Array = first_veil_dungeon.visible_layout(runtime)
    var current_room_id := str(active_run.get("current_room_id", ""))
    var visited: Array = active_run.get("visited", [])
    var risk: Dictionary = ExpeditionManager.current_risk_profile()

    var bg: TextureRect = full_texture("res://assets/backgrounds/crypts.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var title := make_label("CRYPTES DU PREMIER VOILE · DESCENTE VERTICALE", 25, GOLD)
    title.position = Vector2(24, 14)
    title.size = Vector2(760, 38)
    content.add_child(title)
    var subtitle := make_label("CARTE MACRO · 1 NŒUD = 1 SALLE VISITABLE · SEED %d" % int(active_run.get("seed", 0)), 13, MUTED)
    subtitle.position = Vector2(24, 48)
    subtitle.size = Vector2(760, 28)
    content.add_child(subtitle)

    var risk_text := make_label(
        "Palier atteint %d/4 · Lumière %d · Danger ×%.2f · Butin ×%.2f · Sac %d/%d" % [
            int(active_run.get("deepest_depth", 0)),
            int(risk.get("light", 0)),
            float(risk.get("danger_multiplier", 1.0)),
            float(risk.get("loot_multiplier", 1.0)),
            ExpeditionManager.inventory_slots_used(),
            ExpeditionManager.inventory_capacity()
        ],
        14,
        TEXT
    )
    risk_text.position = Vector2(24, 78)
    risk_text.size = Vector2(780, 34)
    content.add_child(risk_text)

    var dim_button := make_button("ÉTEINDRE 1 LUMIÈRE", func():
        ExpeditionManager.deliberately_dim_light(1)
        GameState.add_log("La compagnie étouffe volontairement une source de lumière.")
        refresh_header()
        show_screen("expedition"), Vector2(205, 42))
    dim_button.position = Vector2(680, 68)
    dim_button.disabled = int(ExpeditionManager.inventory.get("light", 0)) <= 0
    content.add_child(dim_button)

    var extract := make_button("EXTRAIRE", func(): _extract_roguelike_run("extracted"), Vector2(160, 42))
    extract.position = Vector2(895, 68)
    extract.disabled = visited.is_empty()
    content.add_child(extract)

    var map_scroll := ScrollContainer.new()
    map_scroll.position = Vector2(24, 122)
    map_scroll.size = Vector2(900, 500)
    content.add_child(map_scroll)
    var map_root := VBoxContainer.new()
    map_root.custom_minimum_size = Vector2(870, 0)
    map_root.add_theme_constant_override("separation", 10)
    map_scroll.add_child(map_root)

    var entry_rooms: Array = _physical_rooms_for_palier(dungeon, 0)
    if not entry_rooms.is_empty():
        var entry_row := HBoxContainer.new()
        entry_row.add_theme_constant_override("separation", 8)
        map_root.add_child(entry_row)
        var entry_label := make_label("ENTRÉE", 13, MUTED)
        entry_label.custom_minimum_size = Vector2(72, 66)
        entry_row.add_child(entry_label)
        for entry_value in entry_rooms:
            _add_physical_map_room_button(entry_row, entry_value as Dictionary, current_room_id, visited, runtime)

    for palier in range(1, 5):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        map_root.add_child(row)
        var danger_label := _palier_danger_label(palier)
        var palier_label := make_label("P%d\n%s" % [palier, danger_label], 12, MUTED)
        palier_label.custom_minimum_size = Vector2(72, 70)
        row.add_child(palier_label)
        var rooms: Array = _physical_rooms_for_palier(dungeon, palier)
        if rooms.is_empty():
            var fog := make_label("INCONNU — avance dans les salles déjà révélées pour cartographier ce palier.", 12, MUTED)
            fog.custom_minimum_size = Vector2(650, 70)
            row.add_child(fog)
            continue
        for room_value in rooms:
            _add_physical_map_room_button(row, room_value as Dictionary, current_room_id, visited, runtime)

    var fog_note := make_label(
        "FOG OF WAR : seules les salles visitées et les passages immédiatement repérés sont dessinés. Les salles secrètes sont totalement absentes jusqu'à leur découverte.",
        11,
        MUTED
    )
    fog_note.custom_minimum_size = Vector2(820, 42)
    map_root.add_child(fog_note)

    _render_roguelike_side_panel(active_run, risk)

func _physical_rooms_for_palier(layout: Array, palier: int) -> Array:
    var result: Array = []
    for room_value in layout:
        var room: Dictionary = room_value
        if int(room.get("palier", room.get("depth", 1))) == palier:
            result.append(room)
    return result

func _add_physical_map_room_button(parent: Control, room: Dictionary, current_room_id: String, visited: Array, runtime: Node) -> void:
    var room_id := str(room.get("id", ""))
    var was_visited := visited.has(room_id)
    var is_current := room_id == current_room_id
    var is_secret := bool(room.get("secret", false))
    var label := "? SALLE INCONNUE"
    if was_visited or str(room.get("room_role", "")) == "entry":
        label = "%s\n%s" % [str(room.get("name", "Salle")), _room_type_label(str(room.get("type", "")))]
    elif is_secret:
        label = "✦ PASSAGE SECRET\nDÉCOUVERT"
    if is_current:
        label = "◆ " + label
    elif bool(room.get("cleared", false)):
        label = "✓ " + label
    var room_button := make_button(label, func(id_value = room_id): _enter_roguelike_room(str(id_value)), Vector2(178, 68))
    room_button.disabled = not first_veil_dungeon.is_reachable(runtime, room_id) or is_current
    parent.add_child(room_button)

func _palier_danger_label(palier: int) -> String:
    match palier:
        1: return "FAIBLE"
        2: return "MOYEN"
        3: return "ÉLEVÉ"
        4: return "EXTRÊME"
        _: return "INCONNU"

func _room_is_reachable(room_id: String, current_room_id: String, visited: Array, dungeon: Array) -> bool:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime != null and int((runtime.active_run as Dictionary).get("physical_dungeon_version", 0)) > 0:
        return first_veil_dungeon.is_reachable(runtime, room_id)
    return super._room_is_reachable(room_id, current_room_id, visited, dungeon)

func _enter_roguelike_room(room_id: String) -> void:
    _ensure_physical_first_veil()
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null or not first_veil_dungeon.is_reachable(runtime, room_id):
        GameState.add_log("Ce passage n'est pas accessible depuis la salle actuelle.")
        show_screen("expedition")
        return

    var active_before: Dictionary = runtime.active_run
    var visited_before: Array = active_before.get("visited", [])
    var previous_room_id := str(active_before.get("current_room_id", ""))

    # Conserve la cadence de Lumière équilibrée de v25 : une consommation tous
    # les N nouveaux espaces, même si l'on navigue désormais salle par salle.
    if not visited_before.has(room_id):
        var light_rules: Dictionary = level_scaling_policy._load_roguelike_rules().get("light", {})
        var interval := maxi(1, int(light_rules.get("room_decay_interval", 1)))
        var next_room_count := int(active_before.get("rooms_cleared", 0)) + 1
        if interval > 1 and next_room_count % interval != 0:
            var decay := maxi(0, int(light_rules.get("room_decay", 1)))
            ExpeditionManager.inventory["light"] = int(ExpeditionManager.inventory.get("light", 0)) + decay

    var result: Dictionary = ExpeditionManager.enter_dungeon_room(room_id)
    if not bool(result.get("success", false)):
        GameState.add_log("La salle ne peut pas être atteinte.")
        show_screen("expedition")
        return

    if previous_room_id != "":
        first_veil_dungeon.record_transition(runtime, previous_room_id, room_id)
    var room: Dictionary = result.get("room", {})
    var palier := int(room.get("palier", room.get("depth", 1)))
    GameState.add_log("%s : %s." % ["Entrée" if palier == 0 else "Palier %d" % palier, str(room.get("name", "Salle inconnue"))])
    if bool(room.get("secret", false)):
        GameState.add_log("Un passage dissimulé mène à une salle qui n'existait pas encore sur la carte.")
    refresh_header()
    GameState.request_screen("dungeon_room")

func show_dungeon_room() -> void:
    _ensure_physical_first_veil()
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        GameState.request_screen("expedition")
        return
    var active: Dictionary = runtime.active_run
    var room_id := str(active.get("current_room_id", ""))
    var room: Dictionary = first_veil_dungeon.room_by_id(runtime, room_id)
    if room.is_empty():
        GameState.request_screen("expedition")
        return

    var depth := int(room.get("depth", 1))
    var bg_path := "res://assets/backgrounds/crypts.webp" if depth <= 2 else "res://assets/backgrounds/ossuary.webp"
    var bg: TextureRect = full_texture(bg_path)
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.70 if depth <= 2 else 0.76)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var is_secret := bool(room.get("secret", false))
    var palier := int(room.get("palier", depth))
    var title_prefix := "SALLE SECRÈTE — " if is_secret else ""
    var title := make_label(title_prefix + str(room.get("name", "Salle")), 28, GOLD)
    title.position = Vector2(34, 22)
    title.size = Vector2(1160, 42)
    content.add_child(title)

    var meta := make_label(
        "%s · %s · %s · variante : %s" % [
            "ENTRÉE" if palier == 0 else "PALIER %d / 4" % palier,
            _room_type_label(str(room.get("type", "salle"))),
            first_veil_dungeon.space_kind_text(room).to_upper(),
            first_veil_dungeon.room_variant_text(room)
        ],
        13,
        MUTED
    )
    meta.position = Vector2(34, 66)
    meta.size = Vector2(1160, 30)
    content.add_child(meta)

    var description := make_label(str(room.get("description", "La salle demeure silencieuse.")), 16, TEXT)
    description.position = Vector2(34, 108)
    description.size = Vector2(720, 92)
    content.add_child(description)

    var detail_panel := VBoxContainer.new()
    detail_panel.position = Vector2(34, 215)
    detail_panel.size = Vector2(720, 330)
    detail_panel.add_theme_constant_override("separation", 10)
    content.add_child(detail_panel)
    detail_panel.add_child(make_label("POINTS D'INTÉRÊT", 16, GOLD))
    var interactions: Array = room.get("interactions", [])
    var interaction_lines: Array[String] = []
    for interaction_value in interactions:
        interaction_lines.append("• " + str(interaction_value))
    detail_panel.add_child(make_label("\n".join(interaction_lines), 13, TEXT))

    var hazards: Array = room.get("hazards", [])
    if not hazards.is_empty():
        detail_panel.add_child(make_label("DANGER ENVIRONNEMENTAL", 15, GOLD))
        detail_panel.add_child(make_label(" · ".join(hazards), 12, MUTED))

    var cleared := bool(room.get("cleared", false))
    detail_panel.add_child(make_label("ÉTAT : %s" % ("SÉCURISÉE" if cleared else "NON RÉSOLUE"), 14, GOLD if cleared else TEXT))
    if not cleared:
        var action_label := _physical_room_action_label(room)
        detail_panel.add_child(make_button(action_label, func(): _resolve_current_physical_room(), Vector2(470, 54)))
        detail_panel.add_child(make_label("Les passages restent verrouillés tant que l'événement principal de la salle n'est pas résolu.", 11, MUTED))
    else:
        if not first_veil_dungeon.was_searched(runtime, room_id):
            detail_panel.add_child(make_button("FOUILLER MURS ET PASSAGES", func(): _search_current_room_for_secret(), Vector2(360, 46)))
        else:
            detail_panel.add_child(make_label("Murs et passages déjà fouillés.", 11, MUTED))

    var exits_panel := VBoxContainer.new()
    exits_panel.position = Vector2(785, 108)
    exits_panel.size = Vector2(450, 465)
    exits_panel.add_theme_constant_override("separation", 8)
    content.add_child(exits_panel)
    exits_panel.add_child(make_label("ISSUES ET PASSAGES", 17, GOLD))

    if not cleared:
        exits_panel.add_child(make_label("Les issues ne peuvent pas encore être empruntées.", 13, MUTED))
    else:
        var exits: Array[String] = first_veil_dungeon.player_connections(runtime, room_id)
        if exits.is_empty():
            exits_panel.add_child(make_label("Aucune issue utilisable.", 13, MUTED))
        for target_id in exits:
            var exit_label := first_veil_dungeon.transition_label(runtime, room_id, target_id)
            exits_panel.add_child(make_button(exit_label, func(id_value = target_id): _enter_roguelike_room(str(id_value)), Vector2(430, 48)))

    var map_button := make_button("OUVRIR LA CARTE MACRO", func(): GameState.request_screen("expedition"), Vector2(260, 46))
    map_button.position = Vector2(34, 620)
    content.add_child(map_button)
    var extract_button := make_button("EXTRAIRE DU DONJON", func(): _extract_roguelike_run("extracted"), Vector2(260, 46))
    extract_button.position = Vector2(310, 620)
    content.add_child(extract_button)

func _physical_room_action_label(room: Dictionary) -> String:
    var room_type := str(room.get("type", ""))
    var role := str(room.get("room_role", ""))
    if role == "entry":
        return "FRANCHIR ET INSPECTER LE SEUIL"
    if role == "preboss":
        return "ROMPRE LE DERNIER SCEAU"
    if room_type == "boss":
        return "AFFRONTER L'ANGE DU PREMIER VOILE"
    if room_type in ROGUELIKE_COMBAT_TYPES:
        return "ENGAGER LE COMBAT DANS CETTE SALLE"
    if room_type == "trap":
        return "TRAVERSER ET DÉJOUER LE PIÈGE"
    if room_type == "puzzle":
        return "RÉSOUDRE L'ÉNIGME"
    if room_type == "treasure" or room_type == "secret":
        return "FOUILLER LA SALLE"
    return "EXPLORER ET INTERAGIR"

func _resolve_current_physical_room() -> void:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        return
    var room_id := str((runtime.active_run as Dictionary).get("current_room_id", ""))
    var room: Dictionary = first_veil_dungeon.room_by_id(runtime, room_id)
    if room.is_empty() or bool(room.get("cleared", false)):
        show_screen("dungeon_room")
        return

    if ROGUELIKE_COMBAT_TYPES.has(str(room.get("type", ""))):
        _start_roguelike_room_battle(room)
        return

    if str(room.get("room_role", "")) == "preboss":
        roguelike_room_reward = {
            "room": room.duplicate(true),
            "loot": [],
            "gold": 0,
            "essence": 0,
            "message": "Le dernier sceau cède. La Porte de l'Ange ouvre désormais sur la chambre terminale."
        }
        _mark_current_room_cleared()
        first_veil_dungeon.mark_interaction_resolved(runtime, room_id)
        GameState.add_log("La Porte de l'Ange est ouverte.")
        GameState.request_screen("rewards")
        return

    _resolve_noncombat_room(room)
    _mark_current_room_cleared()
    first_veil_dungeon.mark_interaction_resolved(runtime, room_id)
    GameState.request_screen("rewards")

func finish_victory() -> void:
    if ExpeditionManager.expedition_active:
        var runtime: Node = ExpeditionManager.roguelike_runtime
        if runtime != null:
            var room_id := str((runtime.active_run as Dictionary).get("current_room_id", ""))
            first_veil_dungeon.mark_interaction_resolved(runtime, room_id)
    super.finish_victory()

func _search_current_room_for_secret() -> void:
    var runtime: Node = ExpeditionManager.roguelike_runtime
    if runtime == null:
        return
    var room_id := str((runtime.active_run as Dictionary).get("current_room_id", ""))
    var result: Dictionary = first_veil_dungeon.search_for_secret(runtime, room_id)
    if bool(result.get("found", false)):
        GameState.add_log("PASSAGE SECRET DÉCOUVERT : %s. La salle apparaît maintenant sur la carte." % str(result.get("secret_name", "Salle secrète")))
    elif str(result.get("reason", "")) == "already_searched":
        GameState.add_log("Cette salle a déjà été fouillée avec attention.")
    else:
        GameState.add_log("La fouille ne révèle aucun passage dissimulé.")
    SaveManager.save_game()
    show_screen("dungeon_room")

func show_rewards() -> void:
    if not ExpeditionManager.expedition_active:
        super.show_rewards()
        return
    var runtime: Node = ExpeditionManager.roguelike_runtime
    var room: Dictionary = _current_roguelike_room()
    if runtime == null or room.is_empty() or int((runtime.active_run as Dictionary).get("physical_dungeon_version", 0)) <= 0:
        super.show_rewards()
        return

    var bg: TextureRect = full_texture("res://assets/backgrounds/ossuary.webp")
    content.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(shade)

    var box := VBoxContainer.new()
    box.position = Vector2(170, 72)
    box.size = Vector2(940, 570)
    box.add_theme_constant_override("separation", 11)
    content.add_child(box)
    box.add_child(make_label("%s — SALLE SÉCURISÉE" % str(room.get("name", "Salle")), 27, GOLD))
    box.add_child(make_label(str(roguelike_room_reward.get("message", "La salle est franchie.")), 15, TEXT))

    var loot: Array = roguelike_room_reward.get("loot", [])
    for item_value in loot:
        var item: Dictionary = item_value
        box.add_child(make_label(
            "Butin : %s · %s%s · affixes : %s" % [
                str(item.get("rarity", "common")).to_upper(),
                "NON IDENTIFIÉE" if not bool(item.get("identified", true)) else "relique",
                " · MAUDITE" if bool(item.get("cursed", false)) else "",
                ", ".join(item.get("affixes", []))
            ],
            13,
            GOLD
        ))

    var summary: Dictionary = ExpeditionManager.extraction_summary()
    box.add_child(make_label(
        "Run : %d salle(s) visitées · %d relique(s) · %d or potentiel · %d essence potentielle · profondeur %d" % [
            int(summary.get("rooms_cleared", 0)),
            (summary.get("cargo", []) as Array).size(),
            int(summary.get("gold_found", 0)),
            int(summary.get("essence_found", 0)),
            int(summary.get("deepest_depth", 0))
        ],
        13,
        MUTED
    ))

    var boss_defeated := bool((runtime.active_run as Dictionary).get("boss_defeated", false))
    if boss_defeated:
        box.add_child(make_label("L'Ange est tombé. La Première Descente sera validée si cette tentative était la première.", 16, GOLD))
        box.add_child(make_button("EXTRAIRE APRÈS LE BOSS", func(): _extract_roguelike_run("boss_defeated"), Vector2(520, 56)))
    else:
        box.add_child(make_button("RETOURNER DANS LA SALLE", func(): GameState.request_screen("dungeon_room"), Vector2(520, 54)))
        box.add_child(make_button("OUVRIR LA CARTE MACRO", func(): GameState.request_screen("expedition"), Vector2(520, 48)))
        box.add_child(make_button("EXTRAIRE ET SÉCURISER", func(): _extract_roguelike_run("extracted"), Vector2(520, 48)))
