extends Node

var layer: CanvasLayer
var launch_button: Button
var panel: PanelContainer
var list: ItemList
var detail: RichTextLabel
var _poll_accumulator := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    set_process(true)

func _process(delta: float) -> void:
    _poll_accumulator += delta
    if _poll_accumulator < 0.15:
        return
    _poll_accumulator = 0.0
    if launch_button == null:
        return
    var archives_open := RemanenceArchivesUI.panel != null and RemanenceArchivesUI.panel.visible
    launch_button.visible = GameState.current_screen == "sanctuary" and archives_open and (panel == null or not panel.visible)
    if panel != null and panel.visible and not archives_open:
        panel.visible = false

func _build() -> void:
    layer = CanvasLayer.new()
    layer.layer = 99
    add_child(layer)

    launch_button = Button.new()
    launch_button.text = "LIGNÉE NÉMÉSIS"
    launch_button.custom_minimum_size = Vector2(190, 48)
    launch_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    launch_button.offset_left = 44
    launch_button.offset_top = 138
    launch_button.offset_right = 234
    launch_button.offset_bottom = 186
    launch_button.visible = false
    launch_button.pressed.connect(open_chain)
    layer.add_child(launch_button)

    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 56
    panel.offset_top = 72
    panel.offset_right = -56
    panel.offset_bottom = -72
    panel.visible = false
    layer.add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    panel.add_child(root)

    var header := HBoxContainer.new()
    root.add_child(header)
    var title := Label.new()
    title.text = "LIGNÉES NÉMÉSIS — ARCHIVES DES VEILLEURS"
    title.add_theme_font_size_override("font_size", 24)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close := Button.new()
    close.text = "RETOUR AUX ARCHIVES"
    close.custom_minimum_size = Vector2(210, 48)
    close.pressed.connect(close_chain)
    header.add_child(close)

    var split := HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.split_offset = 420
    root.add_child(split)

    list = ItemList.new()
    list.custom_minimum_size = Vector2(390, 420)
    list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    list.item_selected.connect(_on_selected)
    split.add_child(list)

    detail = RichTextLabel.new()
    detail.fit_content = false
    detail.scroll_active = true
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail.add_theme_font_size_override("normal_font_size", 17)
    split.add_child(detail)

func open_chain() -> void:
    if panel == null:
        return
    panel.visible = true
    launch_button.visible = false
    refresh_chain()

func close_chain() -> void:
    if panel == null:
        return
    panel.visible = false

func refresh_chain() -> void:
    if list == null:
        return
    list.clear()
    var chains := chain_snapshot()
    for chain: Dictionary in chains:
        var predecessor: Dictionary = chain.get("predecessor", {})
        var successor: Dictionary = chain.get("successor", {})
        var successor_name := str(successor.get("name", "Aucun successeur hostile"))
        var row := "%s → %s" % [str(predecessor.get("name", "Ancien Némésis")), successor_name]
        var index := list.add_item(row)
        list.set_item_metadata(index, chain)
    if list.item_count > 0:
        list.select(0)
        _on_selected(0)
    else:
        detail.text = "Aucune lignée Némésis n'est encore inscrite dans la Rémanence."

func chain_snapshot() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in RemanenceRuntime.entities.values():
        if not (value is Dictionary):
            continue
        var predecessor: Dictionary = value
        var historical_stage := str(predecessor.get("historical_stage", predecessor.get("historical_hostile_stage", "")))
        var stage := str(predecessor.get("stage", ""))
        var status := str(predecessor.get("status", ""))
        if status != "recruited" or (stage != "former_nemesis" and historical_stage != "nemesis"):
            continue
        var predecessor_id := str(predecessor.get("id", ""))
        var successor_id := ""
        for link: Dictionary in RemanenceRuntime.linked_entries(predecessor_id):
            if str(link.get("relation", "")) == "nemesis_succeeded_by" and str(link.get("source_id", "")) == predecessor_id:
                successor_id = str(link.get("target_id", ""))
        var successor: Dictionary = RemanenceRuntime.entity_state(successor_id) if successor_id != "" else {}
        result.append({
            "predecessor": predecessor.duplicate(true),
            "successor": successor.duplicate(true),
            "predecessor_id": predecessor_id,
            "successor_id": successor_id,
            "region_id": str(predecessor.get("region_id", successor.get("region_id", ""))),
            "allied_reputation": int(predecessor.get("allied_reputation", 50)),
            "surrender_decisions": (predecessor.get("surrender_decisions", []) as Array).duplicate(true)
        })
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int((left.get("predecessor", {}) as Dictionary).get("recruited_run", 0)) > int((right.get("predecessor", {}) as Dictionary).get("recruited_run", 0))
    )
    return result

func _on_selected(index: int) -> void:
    if index < 0 or index >= list.item_count:
        return
    var value: Variant = list.get_item_metadata(index)
    if not (value is Dictionary):
        return
    var chain: Dictionary = value
    var predecessor: Dictionary = chain.get("predecessor", {})
    var successor: Dictionary = chain.get("successor", {})
    var lines: Array[String] = []
    lines.append("PRÉDÉCESSEUR DEVENU ALLIÉ")
    lines.append("%s · statut %s · ancien stade %s" % [str(predecessor.get("name", "Ancien Némésis")), str(predecessor.get("status", "recruited")), str(predecessor.get("historical_stage", predecessor.get("historical_hostile_stage", "nemesis")))])
    lines.append("Réputation alliée : %d/100" % int(chain.get("allied_reputation", 50)))
    lines.append("Région : %s" % str(chain.get("region_id", "inconnue")))
    lines.append("")
    lines.append("SUCCESSION HOSTILE")
    if successor.is_empty():
        lines.append("Aucun successeur Némésis actif relié pour le moment.")
    else:
        lines.append("%s · stade %s · statut %s · score %d" % [str(successor.get("name", "Successeur")), str(successor.get("stage", "nemesis")), str(successor.get("status", "active")), int(successor.get("score", 0))])
    lines.append("")
    lines.append("DÉCISIONS DE REDDITION")
    var decisions: Array = chain.get("surrender_decisions", [])
    if decisions.is_empty():
        lines.append("Aucune décision de reddition encore enregistrée.")
    else:
        for decision_value: Variant in decisions:
            if not (decision_value is Dictionary):
                continue
            var decision: Dictionary = decision_value
            var relation: Dictionary = decision.get("relationship", {})
            lines.append("• Run %d · %s · réputation %+d · C%d/R%d/P%d/Re%d" % [
                int(decision.get("run_index", 0)),
                str(decision.get("outcome", "inconnu")),
                int(decision.get("reputation_delta", 0)),
                int(relation.get("trust", 0)),
                int(relation.get("respect", 0)),
                int(relation.get("fear", 0)),
                int(relation.get("resentment", 0))
            ])
    lines.append("")
    lines.append("La chaîne reste historique : recruter le prédécesseur ne supprime ni ses actes passés ni le successeur qui émerge ensuite.")
    detail.text = "\n".join(lines)
