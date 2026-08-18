extends Area3D
class_name Chapter04Fragment

@export var fragment_id := ""
var collected := false

func configure(id_value: String) -> void:
    fragment_id = id_value
    collected = Chapter04Runtime.discovered_fragments.has(fragment_id)
    _refresh()

func _ready() -> void:
    _refresh()

func _refresh() -> void:
    visible = not collected
    monitoring = not collected
    set_meta("interaction_prompt", "Étudier")

func can_interact() -> bool:
    return not collected and fragment_id != ""

func interact() -> void:
    if not can_interact():
        return
    if Chapter04Runtime.collect_fragment(fragment_id):
        collected = true
        _refresh()
        var fragment := Chapter04Runtime.get_fragment(fragment_id)
        GameState.add_log("Fragment ashaï : %s" % String(fragment.get("title", fragment_id)))
