extends RefCounted
class_name VeilleursCombatContextRuntime

# Combat Sandbox 0.1: progressive disclosure for mobile combat.
# The combat HUD stays minimal; tapping an actor opens this read-only context.
# Enemy information is filtered by what the party has actually observed.

const HERO_ORDER := ["mathilde", "marec", "anouk", "aurelien"]
const HERO_NAMES := {
    "mathilde": "Mathilde",
    "marec": "Marec",
    "anouk": "Anouk",
    "aurelien": "Aurélien",
}

const BODY_ZONE_ORDER := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]

static func hero_roster() -> Array[Dictionary]:
    var roster: Array[Dictionary] = []
    # R1 -> R4 is right-to-left on screen. Roles/kits are intentionally not
    # invented here: canonical character data remains the source of truth.
    for index in HERO_ORDER.size():
        var hero_id: String = HERO_ORDER[index]
        roster.append({
            "id": hero_id,
            "name": HERO_NAMES[hero_id],
            "side": "hero",
            "formation_slot": index + 1,
            "ap": 2,
            "max_ap": 2,
            "vital_state": "stable",
            "pain_state": "controlled",
            "bleeding_state": "none",
            "psych_state": "stable",
            "buffs": [],
            "debuffs": [],
            "anatomy": {},
        })
    return roster

static func quick_summary(actor: Dictionary, party_knowledge: Dictionary = {}) -> Dictionary:
    if actor.is_empty():
        return {"ok": false, "reason": "invalid_actor"}
    var enemy := str(actor.get("side", "enemy")) == "enemy"
    var visible := _visible_actor(actor, party_knowledge) if enemy else actor.duplicate(true)
    var buffs: Array = visible.get("buffs", [])
    var debuffs: Array = visible.get("debuffs", [])
    return {
        "ok": true,
        "id": str(visible.get("id", "unknown")),
        "name": str(visible.get("name", "Inconnu")),
        "side": str(visible.get("side", "enemy")),
        "vital_state": str(visible.get("vital_state", "unknown")),
        "pain_state": str(visible.get("pain_state", "unknown")),
        "bleeding_state": str(visible.get("bleeding_state", "unknown")),
        "psych_state": str(visible.get("psych_state", "unknown")),
        "buff_count": buffs.size(),
        "debuff_count": debuffs.size(),
        "priority_effects": _priority_effects(buffs, debuffs, 3),
        "more_effects": maxi(0, buffs.size() + debuffs.size() - 3),
        "ap": int(visible.get("ap", -1)) if not enemy else -1,
        "formation_slot": int(visible.get("formation_slot", -1)),
    }

static func detailed_inspection(actor: Dictionary, party_knowledge: Dictionary = {}) -> Dictionary:
    var quick := quick_summary(actor, party_knowledge)
    if not bool(quick.get("ok", false)):
        return quick
    var enemy := str(actor.get("side", "enemy")) == "enemy"
    var visible := _visible_actor(actor, party_knowledge) if enemy else actor.duplicate(true)
    var anatomy: Dictionary = visible.get("anatomy", {})
    var zones: Array[Dictionary] = []
    for zone_id in BODY_ZONE_ORDER:
        var zone: Dictionary = anatomy.get(zone_id, {})
        zones.append({
            "id": zone_id,
            "known": not zone.is_empty(),
            "state": str(zone.get("state", "unknown")),
            "armor": str(zone.get("armor", "unknown")),
            "function": str(zone.get("function", "unknown")),
            "injuries": (zone.get("injuries", []) as Array).duplicate(true),
        })
    quick["anatomy"] = zones
    quick["buffs"] = (visible.get("buffs", []) as Array).duplicate(true)
    quick["debuffs"] = (visible.get("debuffs", []) as Array).duplicate(true)
    quick["observations"] = (visible.get("observations", []) as Array).duplicate(true)
    quick["inspection_cost_ap"] = 0
    quick["read_only"] = true
    return quick

static func record_enemy_observation(party_knowledge: Dictionary, enemy_id: String, field: String, value: Variant) -> void:
    if enemy_id.is_empty() or field.is_empty():
        return
    if not party_knowledge.has(enemy_id):
        party_knowledge[enemy_id] = {}
    var known: Dictionary = party_knowledge[enemy_id]
    known[field] = value

static func record_enemy_zone(party_knowledge: Dictionary, enemy_id: String, zone_id: String, data: Dictionary) -> void:
    if not party_knowledge.has(enemy_id):
        party_knowledge[enemy_id] = {}
    var known: Dictionary = party_knowledge[enemy_id]
    if not known.has("anatomy"):
        known["anatomy"] = {}
    var anatomy: Dictionary = known["anatomy"]
    anatomy[zone_id] = data.duplicate(true)

static func _visible_actor(actor: Dictionary, party_knowledge: Dictionary) -> Dictionary:
    var enemy_id := str(actor.get("id", ""))
    var known: Dictionary = party_knowledge.get(enemy_id, {})
    var visible := {
        "id": enemy_id,
        "name": str(actor.get("name", "Inconnu")),
        "side": "enemy",
        "formation_slot": int(actor.get("formation_slot", -1)),
        "vital_state": str(known.get("vital_state", actor.get("public_vital_state", "unknown"))),
        "pain_state": str(known.get("pain_state", "unknown")),
        "bleeding_state": str(known.get("bleeding_state", "unknown")),
        "psych_state": str(known.get("psych_state", "unknown")),
        "buffs": (known.get("buffs", []) as Array).duplicate(true),
        "debuffs": (known.get("debuffs", []) as Array).duplicate(true),
        "anatomy": (known.get("anatomy", {}) as Dictionary).duplicate(true),
        "observations": (known.get("observations", []) as Array).duplicate(true),
    }
    return visible

static func _priority_effects(buffs: Array, debuffs: Array, limit: int) -> Array:
    var combined: Array = []
    combined.append_array(debuffs)
    combined.append_array(buffs)
    combined.sort_custom(func(a: Variant, b: Variant) -> bool:
        var da: Dictionary = a if a is Dictionary else {}
        var db: Dictionary = b if b is Dictionary else {}
        return int(da.get("priority", 0)) > int(db.get("priority", 0))
    )
    return combined.slice(0, mini(limit, combined.size()))
