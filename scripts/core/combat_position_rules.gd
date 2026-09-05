extends RefCounted

# Règle de lecture : position 0 = rang 1 (avant), position 3 = rang 4 (arrière).
# Les fonctions historiques décrivent les rangs d'utilisation des compétences.
# Les helpers de formation ci-dessous valident aussi occupation, cadavres bloquants
# et projections sans autoriser de superposition physique.

const FRONT: Array[int] = [0, 1]
const FRONT_MID: Array[int] = [0, 1, 2]
const MID_BACK: Array[int] = [1, 2, 3]
const ALL: Array[int] = [0, 1, 2, 3]
const FORMATION_RANKS := 4

const FRONT_CLASSES: Array[String] = ["breaker", "watcher", "inquisitor", "duelist"]
const BACK_CLASSES: Array[String] = ["vestal", "mystic", "ranger", "surgeon", "scout", "occultist"]

static func allowed_positions(hero: Dictionary, skill: Dictionary) -> Array[int]:
    var skill_id := str(skill.get("id", ""))
    match skill_id:
        "basic_strike": return FRONT_MID.duplicate()
        "heavy_blow": return FRONT.duplicate()
        "guard_stance": return ALL.duplicate()
        "field_aid": return MID_BACK.duplicate()

    var effect := str(skill.get("effect", "attack"))
    var source_stat := str(skill.get("source_stat", ""))
    var status := str(skill.get("status", ""))
    var class_id := str(hero.get("class_id", ""))

    if effect == "guard":
        return FRONT_MID.duplicate()
    if effect in ["heal", "support"]:
        return MID_BACK.duplicate()

    if effect == "attack":
        if status in ["stun", "break"] or source_stat in ["break_chance", "stun_chance", "execute_percent"]:
            return FRONT.duplicate()
        if status == "bleed" or source_stat == "bleed_chance":
            return FRONT_MID.duplicate()
        if source_stat in ["precision", "critical_chance"]:
            return MID_BACK.duplicate()
        if FRONT_CLASSES.has(class_id):
            return FRONT.duplicate()
        if BACK_CLASSES.has(class_id):
            return MID_BACK.duplicate()
        return FRONT_MID.duplicate()

    return ALL.duplicate()

static func is_usable(hero: Dictionary, skill: Dictionary) -> bool:
    if hero.is_empty() or skill.is_empty():
        return false
    return allowed_positions(hero, skill).has(clampi(int(hero.get("combat_position", 0)), 0, 3))

static func position_label(positions: Array[int]) -> String:
    if positions.is_empty():
        return "aucun"
    var labels: Array[String] = []
    for position in positions:
        labels.append("R%d" % (int(position) + 1))
    return " / ".join(labels)

static func short_position_label(positions: Array[int]) -> String:
    if positions == ALL:
        return "R1–R4"
    if positions == FRONT:
        return "R1–R2"
    if positions == FRONT_MID:
        return "R1–R3"
    if positions == MID_BACK:
        return "R2–R4"
    return position_label(positions)

# --- Formation physique canonique -----------------------------------------

static func rank_span(actor: Dictionary) -> int:
    if actor.has("rank_span"):
        return clampi(int(actor.get("rank_span", 1)), 1, FORMATION_RANKS)
    var size := str(actor.get("formation_size", actor.get("size", "medium"))).to_lower()
    if size in ["large", "grand", "two_ranks", "2_ranks"]:
        return 2
    return 1

static func occupied_ranks(actor: Dictionary, position_override: int = -1) -> Array[int]:
    var start := int(actor.get("combat_position", 0)) if position_override < 0 else position_override
    var result: Array[int] = []
    for offset in range(rank_span(actor)):
        result.append(start + offset)
    return result

static func formation_capacity_required(actors: Array) -> int:
    var required := 0
    for value: Variant in actors:
        if value is Dictionary:
            required += rank_span(value as Dictionary)
    return required

static func can_fit_formation(actors: Array) -> bool:
    return formation_capacity_required(actors) <= FORMATION_RANKS

static func validate_formation(actors: Array, blockers: Array = []) -> Dictionary:
    var occupancy: Dictionary = {}
    for blocker_value: Variant in blockers:
        if blocker_value is not Dictionary:
            continue
        var blocker: Dictionary = blocker_value
        if not bool(blocker.get("blocking", true)):
            continue
        var blocker_id := str(blocker.get("id", "blocker"))
        for rank in occupied_ranks(blocker):
            if rank < 0 or rank >= FORMATION_RANKS:
                return {"valid": false, "reason": "blocker_out_of_bounds", "rank": rank}
            if occupancy.has(rank):
                return {"valid": false, "reason": "blocker_overlap", "rank": rank}
            occupancy[rank] = blocker_id

    for actor_value: Variant in actors:
        if actor_value is not Dictionary:
            continue
        var actor: Dictionary = actor_value
        var actor_id := str(actor.get("id", actor.get("name", "actor")))
        for rank in occupied_ranks(actor):
            if rank < 0 or rank >= FORMATION_RANKS:
                return {"valid": false, "reason": "actor_out_of_bounds", "actor_id": actor_id, "rank": rank}
            if occupancy.has(rank):
                return {
                    "valid": false,
                    "reason": "rank_overlap",
                    "actor_id": actor_id,
                    "rank": rank,
                    "occupied_by": str(occupancy.get(rank, ""))
                }
            occupancy[rank] = actor_id
    return {"valid": true, "reason": "ok", "occupancy": occupancy}

static func compress_toward_front(actors: Array, blockers: Array = [], allow_pass_blockers: bool = false) -> Dictionary:
    var working: Array[Dictionary] = _duplicate_actor_array(actors)
    working.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("combat_position", 0)) < int(right.get("combat_position", 0))
    )
    var placed: Array[Dictionary] = []
    var moved_ids: Array[String] = []
    for actor: Dictionary in working:
        var original := int(actor.get("combat_position", 0))
        var selected := original
        for candidate in range(0, original + 1):
            if not allow_pass_blockers and _crosses_blocker(original, candidate, blockers):
                continue
            var trial := actor.duplicate(true)
            trial["combat_position"] = candidate
            var candidate_actors: Array = placed.duplicate(true)
            candidate_actors.append(trial)
            if bool(validate_formation(candidate_actors, blockers).get("valid", false)):
                selected = candidate
                break
        actor["combat_position"] = selected
        if selected != original:
            moved_ids.append(str(actor.get("id", actor.get("name", "actor"))))
        placed.append(actor)
    var validation := validate_formation(placed, blockers)
    return {
        "success": bool(validation.get("valid", false)),
        "formation": placed,
        "moved_ids": moved_ids,
        "validation": validation
    }

static func project_actor(actors: Array, actor_id: String, delta: int, blockers: Array = []) -> Dictionary:
    var working: Array[Dictionary] = _duplicate_actor_array(actors)
    if delta == 0:
        return {"success": true, "formation": working, "moved_ids": [], "reason": "no_move"}
    var direction := 1 if delta > 0 else -1
    var moved_ids: Array[String] = []
    for _step in range(absi(delta)):
        var index := _actor_index(working, actor_id)
        if index < 0:
            return {"success": false, "formation": _duplicate_actor_array(actors), "moved_ids": [], "reason": "actor_not_found"}
        var visited: Dictionary = {}
        if not _shift_chain_one_rank(working, index, direction, blockers, visited, moved_ids):
            return {"success": false, "formation": _duplicate_actor_array(actors), "moved_ids": [], "reason": "projection_blocked"}
    var validation := validate_formation(working, blockers)
    if not bool(validation.get("valid", false)):
        return {"success": false, "formation": _duplicate_actor_array(actors), "moved_ids": [], "reason": str(validation.get("reason", "invalid"))}
    return {"success": true, "formation": working, "moved_ids": moved_ids, "reason": "ok", "validation": validation}

static func _shift_chain_one_rank(actors: Array[Dictionary], index: int, direction: int, blockers: Array, visited: Dictionary, moved_ids: Array[String]) -> bool:
    var actor: Dictionary = actors[index]
    var actor_id := str(actor.get("id", actor.get("name", "actor")))
    if visited.has(actor_id):
        return false
    visited[actor_id] = true
    var target_position := int(actor.get("combat_position", 0)) + direction
    var target_ranks := occupied_ranks(actor, target_position)
    for rank in target_ranks:
        if rank < 0 or rank >= FORMATION_RANKS:
            return false
        if _rank_blocked(rank, blockers):
            return false

    var collisions: Array[int] = []
    for other_index in range(actors.size()):
        if other_index == index:
            continue
        var other: Dictionary = actors[other_index]
        for rank in target_ranks:
            if occupied_ranks(other).has(rank):
                collisions.append(other_index)
                break
    for collision_index in collisions:
        if not _shift_chain_one_rank(actors, collision_index, direction, blockers, visited, moved_ids):
            return false

    actor["combat_position"] = target_position
    actors[index] = actor
    if not moved_ids.has(actor_id):
        moved_ids.append(actor_id)
    return true

static func _rank_blocked(rank: int, blockers: Array) -> bool:
    for blocker_value: Variant in blockers:
        if blocker_value is not Dictionary:
            continue
        var blocker: Dictionary = blocker_value
        if bool(blocker.get("blocking", true)) and occupied_ranks(blocker).has(rank):
            return true
    return false

static func _crosses_blocker(from_position: int, to_position: int, blockers: Array) -> bool:
    if from_position == to_position:
        return false
    var low := mini(from_position, to_position)
    var high := maxi(from_position, to_position)
    for blocker_value: Variant in blockers:
        if blocker_value is not Dictionary:
            continue
        var blocker: Dictionary = blocker_value
        if not bool(blocker.get("blocking", true)):
            continue
        for rank in occupied_ranks(blocker):
            if rank >= low and rank <= high:
                return true
    return false

static func _actor_index(actors: Array[Dictionary], actor_id: String) -> int:
    for index in range(actors.size()):
        var actor: Dictionary = actors[index]
        if str(actor.get("id", actor.get("name", "actor"))) == actor_id:
            return index
    return -1

static func _duplicate_actor_array(actors: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value: Variant in actors:
        if value is Dictionary:
            result.append((value as Dictionary).duplicate(true))
    return result
