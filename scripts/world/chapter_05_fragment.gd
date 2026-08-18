extends Area3D
class_name Chapter05Fragment

var fragment_id := ""

func configure(id_value: String) -> void:
    fragment_id = id_value
    monitoring = true
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("player_party"):
        return
    if Chapter05Runtime.collect_fragment(fragment_id):
        var fragment := Chapter05Runtime.get_fragment(fragment_id)
        GameState.add_log("Archive Or-Silex / Saan : %s" % String(fragment.get("title", fragment_id)))
        queue_free()
