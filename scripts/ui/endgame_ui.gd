extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const WARNING := Color("#c98776")
const PANEL := Color(0.025,0.028,0.038,0.985)

var access_button: Button
var panel: PanelContainer
var body: VBoxContainer
var opened := false
var auto_offer_queued := false
var ngplus_confirmation_open := false
var pending_ngplus_perk := ""

func _ready() -> void:
    layer = 36
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    CampaignState.campaign_changed.connect(_refresh_visibility)
    EndgameState.endgame_changed.connect(_on_endgame_changed)
    _refresh_visibility()

func _style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.45,0.34,0.20,0.9)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _label(text_value: String, size := 14, color := TEXT) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(text_value: String, callback: Callable, width := 310) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(width, 44)
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_stylebox_override("normal", _style())
    button.pressed.connect(callback)
    return button

func _build() -> void:
    access_button = _button("MONDE D'APRÈS", _open, 210)
    access_button.position = Vector2(830, 18)
    access_button.visible = false
    add_child(access_button)

    panel = PanelContainer.new()
    panel.position = Vector2(150, 42)
    panel.size = Vector2(980, 640)
    panel.add_theme_stylebox_override("panel", _style())
    panel.visible = false
    add_child(panel)

    var scroll := ScrollContainer.new()
    panel.add_child(scroll)
    body = VBoxContainer.new()
    body.custom_minimum_size = Vector2(925, 0)
    body.add_theme_constant_override("separation", 9)
    scroll.add_child(body)

func _on_screen_requested(_screen_name: String) -> void:
    if GameState.current_screen != "sanctuary": _close()
    _refresh_visibility()

func _refresh_visibility() -> void:
    if not is_instance_valid(access_button): return
    var available := GameState.current_screen == "sanctuary" and EndgameState.is_postgame_unlocked()
    access_button.text = "CHOISIR LA SUITE" if not EndgameState.postgame_choice_presented else "MONDE D'APRÈS"
    access_button.visible = available and not opened
    if available and not EndgameState.postgame_choice_presented and not opened and not auto_offer_queued:
        auto_offer_queued = true
        call_deferred("_auto_open_choice")

func _auto_open_choice() -> void:
    auto_offer_queued = false
    if GameState.current_screen == "sanctuary" and EndgameState.is_postgame_unlocked() and not EndgameState.postgame_choice_presented and not opened:
        _open()

func _on_endgame_changed() -> void:
    _refresh_visibility()
    if opened: call_deferred("_render")

func _open() -> void:
    if not EndgameState.is_postgame_unlocked(): return
    EndgameState.record_current_ending()
    EndgameState.mark_postgame_choice_presented()
    opened = true
    access_button.visible = false
    panel.visible = true
    _render()

func _close() -> void:
    opened = false
    ngplus_confirmation_open = false
    pending_ngplus_perk = ""
    if is_instance_valid(panel): panel.visible = false
    _refresh_visibility()

func _clear() -> void:
    for child in body.get_children(): child.queue_free()

func _choose_continue() -> void:
    if EndgameState.choose_continue_postgame():
        SaveManager.save_game()
        _close()
        GameState.request_screen("sanctuary")

func _request_ngplus(perk_id: String = "") -> void:
    if not EndgameState.can_begin_new_game_plus(perk_id):
        return
    pending_ngplus_perk = perk_id
    ngplus_confirmation_open = true
    _render()

func _cancel_ngplus() -> void:
    ngplus_confirmation_open = false
    pending_ngplus_perk = ""
    _render()

func _confirm_ngplus() -> void:
    if not EndgameState.begin_new_game_plus(pending_ngplus_perk):
        return
    SaveManager.save_game()
    ngplus_confirmation_open = false
    pending_ngplus_perk = ""
    _close()
    GameState.request_screen("sanctuary")

func _render() -> void:
    if not opened: return
    _clear()
    var ending := EndgameState.current_epilogue()
    body.add_child(_label("LE MONDE D'APRÈS", 22, GOLD))
    body.add_child(_label("%s · %s" % [String(ending.get("title", "Épilogue")), EndgameState.cycle_label()], 17, TEXT))
    for key in ["opening", "middle", "political", "closing"]:
        var text := String(ending.get(key, ""))
        if text != "": body.add_child(_label(text, 13, TEXT))

    var vignettes := EndgameState.visible_vignettes()
    if not vignettes.is_empty():
        body.add_child(_label("DESTINS ET TRACES", 16, GOLD))
        for value in vignettes:
            var vignette: Dictionary = value
            body.add_child(_label(String(vignette.get("title", "")), 14, TEXT))
            body.add_child(_label(String(vignette.get("text", "")), 12, MUTED))

    body.add_child(_label("APRÈS LA FIN — CHOISIS TON RYTHME", 18, GOLD))
    body.add_child(_label("La campagne est terminée. Tu peux rester dans cette sauvegarde aussi longtemps que tu veux : explorer, refaire des donjons, terminer des quêtes, gérer le Sanctuaire et accomplir les opérations du monde d'après. Le Nouveau Cycle+ restera disponible plus tard. Tu peux aussi repartir immédiatement en NG+.", 13, TEXT))

    var continue_text := "CONTINUER CETTE PARTIE" if not EndgameState.postgame_continuation_selected else "CONTINUER DANS LE MONDE D'APRÈS"
    body.add_child(_button(continue_text, _choose_continue, 390))

    var immediate_ng_button := _button("PASSER EN NG+ SANS HÉRITAGE", func(): _request_ngplus(""), 390)
    immediate_ng_button.disabled = not EndgameState.can_begin_new_game_plus("")
    body.add_child(immediate_ng_button)

    if ngplus_confirmation_open:
        var selected_name := "Sans héritage"
        if pending_ngplus_perk != "":
            selected_name = String(EndgameState.perk(pending_ngplus_perk).get("name", pending_ngplus_perk))
        body.add_child(_label("CONFIRMATION DU NOUVEAU CYCLE+", 16, WARNING))
        body.add_child(_label("Choix : %s. Le NG+ recommencera la campagne et remettra à zéro la progression de campagne, la politique, les niveaux, l'inventaire, les créatures et les ressources du Sanctuaire. Les archives de fins et les éléments d'héritage prévus seront conservés. Cette action n'est lancée qu'après confirmation." % selected_name, 12, WARNING))
        body.add_child(_button("CONFIRMER LE NOUVEAU CYCLE+", _confirm_ngplus, 390))
        body.add_child(_button("ANNULER", _cancel_ngplus, 240))

    body.add_child(_label("RECONSTRUCTION OPTIONNELLE — %d opération(s) accomplie(s) · %d point(s) d'héritage" % [EndgameState.operation_count(), EndgameState.legacy_points], 16, GOLD))
    body.add_child(_label("Ces opérations ne sont plus obligatoires pour accéder au NG+. Elles permettent de prolonger cette partie, de modifier le monde d'après et de gagner des points d'héritage si tu veux préparer ton prochain cycle.", 12, MUTED))
    for value in EndgameState.operations():
        var operation: Dictionary = value
        var operation_id := String(operation.get("id", ""))
        var done := bool(EndgameState.completed_operations.get(operation_id, false))
        var title := "✓ %s" % String(operation.get("name", operation_id)) if done else String(operation.get("name", operation_id))
        body.add_child(_label(title, 14, TEXT if not done else MUTED))
        body.add_child(_label(String(operation.get("description", "")), 11, MUTED))
        if not done:
            var button := _button("ACCOMPLIR", func(id_value=operation_id):
                if EndgameState.complete_operation(String(id_value)):
                    SaveManager.save_game()
                    _render())
            button.disabled = not EndgameState.operation_available(operation_id)
            body.add_child(button)

    body.add_child(_label("NOUVEAU CYCLE+", 17, GOLD))
    body.add_child(_label("Le NG+ est disponible dès la fin de la campagne. Tu peux partir sans héritage, ou rester ici pour gagner des points puis choisir un héritage optionnel. Continuer le postgame ne ferme jamais cette possibilité.", 12, MUTED))
    body.add_child(_label("NOUVELLE RÈGLE — tous les mini-boss et boss, y compris ceux des Vestiges profonds, deviennent recrutables avec CAPTURER. Leur version alliée se synchronise au niveau moyen de la compagnie et ne conserve jamais les PV bruts de sa version boss.", 12, GOLD))

    for value in EndgameState.perks():
        var perk: Dictionary = value
        var perk_id := String(perk.get("id", ""))
        body.add_child(_label("%s — coût %d" % [String(perk.get("name", perk_id)), int(perk.get("cost", 0))], 14, TEXT))
        body.add_child(_label(String(perk.get("description", "")), 11, MUTED))
        var button := _button("CHOISIR CET HÉRITAGE ET PASSER EN NG+", func(id_value=perk_id): _request_ngplus(String(id_value)), 390)
        button.disabled = not EndgameState.perk_available(perk_id)
        body.add_child(button)

    if not EndgameState.ending_history.is_empty():
        body.add_child(_label("CHRONIQUE DES CYCLES", 16, GOLD))
        for value in EndgameState.ending_history:
            var record: Dictionary = value
            body.add_child(_label("• Cycle %d — %s" % [int(record.get("cycle", 0)), String(record.get("name", record.get("ending_id", "")))], 12, MUTED))

    body.add_child(_button("REFERMER LA CHRONIQUE", _close, 330))
