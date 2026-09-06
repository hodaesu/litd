extends RefCounted
class_name VeilleursTacticalGrid

const WIDTH := 6
const HEIGHT := 5
var occupants: Dictionary = {}

func inside(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

func place(entity_id: String, cell: Vector2i) -> bool:
    if entity_id == "" or not inside(cell) or occupied(cell) or has_entity(entity_id):
        return false
    occupants[_key(cell)] = entity_id
    return true

func move(entity_id: String, destination: Vector2i) -> bool:
    if not inside(destination) or occupied(destination):
        return false
    var origin := position_of(entity_id)
    if origin.x < 0:
        return false
    occupants.erase(_key(origin))
    occupants[_key(destination)] = entity_id
    return true

func remove(entity_id: String) -> void:
    var origin := position_of(entity_id)
    if origin.x >= 0:
        occupants.erase(_key(origin))

func occupied(cell: Vector2i) -> bool:
    return occupants.has(_key(cell))

func occupant(cell: Vector2i) -> String:
    return str(occupants.get(_key(cell), ""))

func has_entity(entity_id: String) -> bool:
    return position_of(entity_id).x >= 0

func position_of(entity_id: String) -> Vector2i:
    for key_value: Variant in occupants.keys():
        var key := str(key_value)
        if str(occupants[key]) == entity_id:
            var parts := key.split(":")
            if parts.size() == 2:
                return Vector2i(int(parts[0]), int(parts[1]))
    return Vector2i(-1, -1)

func distance(a: String, b: String) -> int:
    var pa := position_of(a)
    var pb := position_of(b)
    if pa.x < 0 or pb.x < 0:
        return 999
    return absi(pa.x - pb.x) + absi(pa.y - pb.y)

func neighbors(cell: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
        var next := cell + delta
        if inside(next):
            result.append(next)
    return result

func snapshot() -> Dictionary:
    return occupants.duplicate(true)

func restore(payload: Dictionary) -> bool:
    var restored: Dictionary = {}
    for key_value: Variant in payload.keys():
        var key := str(key_value)
        var parts := key.split(":")
        if parts.size() != 2:
            return false
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        if not inside(cell):
            return false
        var entity_id := str(payload.get(key_value, ""))
        if entity_id == "" or restored.values().has(entity_id):
            return false
        restored[key] = entity_id
    occupants = restored
    return true

func _key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]
