extends CanvasLayer

const GOLD := Color("#d5b26c")
const TEXT := Color("#e5dccb")
const MUTED := Color("#a49884")
const PANEL := Color(0.025, 0.028, 0.038, 0.98)

var panel: PanelContainer
var body: VBoxContainer

func _ready() -> void:
    layer = 29
    _build()
    GameState.screen_requested.connect(_on_screen_requested)
    SideQuestRuntime.quests_changed.connect(_refresh_if_visible)
    CampaignState.campaign_changed.connect(_refresh_if_visible)
    _on_screen_requested(GameState.current_screen)

func _on_screen_requested(screen_name: String) -> void:
    panel.visible = screen_name == "quest_journal" and CampaignState.current_chapter_number() >= 2 and EndgameState.active_cycle <= 0
    if panel.visible:
        _render()

func _refresh_if_visible() -> void:
    if panel.visible:
        call_deferred("_render")

func _build() -> void:
    panel = PanelContainer.new()
    panel.position = Vector2(640, 100)
    panel.size = Vector2(600, 560)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color(0.48, 0.36, 0.21, 0.9)
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var scroll := ScrollContainer.new()
    panel.add_child(scroll)
    body = VBoxContainer.new()
    body.custom_minimum_size = Vector2(550, 520)
    body.add_theme_constant_override("separation", 8)
    scroll.add_child(body)
    panel.visible = false

func _render() -> void:
    for child in body.get_children():
        child.queue_free()
    body.add_child(_label("HISTOIRES DU MONDE", 18, GOLD))
    body.add_child(_label("Facultatives · elles approfondissent le monde sans bloquer la campagne principale.", 12, MUTED))
    var chapter := CampaignState.current_chapter_number()
    var found := false
    for quest_id_value: Variant in SideQuestRuntime.definitions.keys():
        var quest_id := String(quest_id_value)
        var quest := SideQuestRuntime.quest(quest_id)
        if not quest_id.begins_with("c%02d_side_" % chapter):
            continue
        found = true
        _render_quest(quest)
    if not found:
        body.add_child(_label("Aucune histoire secondaire nouvelle pour ce chapitre.", 13, MUTED))

func _render_quest(quest: Dictionary) -> void:
    var quest_id := String(quest.get("id", ""))
    var status := SideQuestRuntime.status(quest_id)
    var marker := "✓" if status == "completed" else ("◆" if status == "active" else "◇")
    body.add_child(_label("%s %s" % [marker, String(quest.get("name", "Histoire"))], 16, TEXT))
    body.add_child(_label(String(quest.get("summary", "")), 12, MUTED))
    var narrative: Dictionary = quest.get("narrative", {})
    if status in ["offered", "refused"]:
        body.add_child(_label(String(narrative.get("hook", "")), 12, TEXT))
        for line_value: Variant in narrative.get("offer_lines", []):
            body.add_child(_label(String(line_value), 12, MUTED))
        var row := HBoxContainer.new()
        var accept := Button.new()
        accept.text = "ACCEPTER"
        accept.custom_minimum_size = Vector2(160, 38)
        accept.pressed.connect(func():
            SideQuestRuntime.accept(quest_id)
            SaveManager.save_game()
            _render()
        )
        row.add_child(accept)
        var refuse := Button.new()
        refuse.text = "REFUSER"
        refuse.custom_minimum_size = Vector2(160, 38)
        refuse.pressed.connect(func():
            SideQuestRuntime.refuse(quest_id)
            SaveManager.save_game()
            _render()
        )
        row.add_child(refuse)
        body.add_child(row)
    elif status == "active":
        var state := SideQuestRuntime.state(quest_id)
        var progress: Dictionary = state.get("progress", {})
        for objective_value: Variant in quest.get("objectives", []):
            var objective: Dictionary = objective_value
            var objective_id := String(objective.get("id", ""))
            var current := int(progress.get(objective_id, 0))
            var required := int(objective.get("count", 1))
            body.add_child(_label("%s %s — %d/%d" % ["✓" if current >= required else "□", String(objective.get("journal_text", objective_id)), current, required], 11, MUTED))
        var track := Button.new()
        track.text = "SUIVRE"
        track.custom_minimum_size = Vector2(160, 36)
        track.pressed.connect(func(): SideQuestRuntime.track(quest_id))
        body.add_child(track)
    elif status == "completed":
        for line_value: Variant in narrative.get("completion_lines", []):
            body.add_child(_label(String(line_value), 12, MUTED))
    body.add_child(HSeparator.new())

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label
