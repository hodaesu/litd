extends CanvasLayer
class_name AshlandsHUD

@onready var zone_label: Label = $Margin/VBox/ZoneLabel
@onready var supplies_label: Label = $Margin/VBox/SuppliesLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel

func _ready() -> void:
    ExpeditionManager.inventory_changed.connect(_on_inventory_changed)
    AshlandsRuntime.zone_discovered.connect(_on_zone_discovered)
    _refresh()

func _refresh() -> void:
    zone_label.text = _pretty_zone(AshlandsRuntime.current_zone_id)
    _on_inventory_changed(ExpeditionManager.inventory)
    var miniboss := AshlandsMinibossDirector.get_assignment(AshlandsRuntime.current_zone_id)
    status_label.text = "Mini-boss possible : %s" % str(miniboss.get("name", "aucun")) if not miniboss.is_empty() else "Exploration"

func _on_inventory_changed(inv: Dictionary) -> void:
    supplies_label.text = "Nourriture %d  Eau %d  Bandages %d  Lumière %d  Camp %d" % [
        int(inv.get("food", 0)),
        int(inv.get("water", 0)),
        int(inv.get("bandages", 0)),
        int(inv.get("light", 0)),
        int(inv.get("camp_tools", 0))
    ]

func _on_zone_discovered(_zone_id: String) -> void:
    _refresh()

func _pretty_zone(id_value: String) -> String:
    if id_value == "":
        return "TERRE DES CENDRES"
    return id_value.replace("zone_", "ZONE ").replace("_", " ").capitalize()

func _on_return_pressed() -> void:
    AshlandsSceneRouter.return_to_hub("voluntary")
