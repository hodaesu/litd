extends LITDBaseButton
class_name LITDSkillButton

signal skill_info_requested(skill_id: String)

@export var skill_id := ""
@export var blocked_reason := ""
@export var charges := -1
@export var is_ultimate := false

var armed := false
var targeting := false

func _ready() -> void:
    button_kind = "primary"
    super._ready()
    refresh_state()

func bind_skill(data: Dictionary) -> void:
    skill_id = str(data.get("skill_id", data.get("id", "")))
    text = str(data.get("name", data.get("name_fr", skill_id)))
    blocked_reason = str(data.get("blocked_reason", ""))
    charges = int(data.get("charges", -1))
    is_ultimate = bool(data.get("is_ultimate", false))
    disabled = bool(data.get("disabled", false))
    refresh_state()

func set_interaction_state(is_armed: bool, is_targeting: bool) -> void:
    armed = is_armed
    targeting = is_targeting
    selected = armed
    refresh_state()

func refresh_state() -> void:
    button_kind = "destructive" if is_ultimate else "primary"
    if disabled and blocked_reason != "":
        tooltip_text = "Impossible — %s" % blocked_reason
    elif charges >= 0:
        tooltip_text = "%s utilisation%s restante%s" % [charges, "" if charges == 1 else "s", "" if charges == 1 else "s"]
    else:
        tooltip_text = ""
    if targeting and not disabled:
        add_theme_color_override("font_color", UITokens.COLOR_GOLD)
    else:
        add_theme_color_override("font_color", UITokens.COLOR_IVORY)
    _apply_visuals()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        skill_info_requested.emit(skill_id)
        accept_event()
