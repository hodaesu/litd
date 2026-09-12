extends RefCounted
class_name KnowledgeDiscoveryUIContract

# Read-only presentation contract for progressive enemy/world knowledge.
# It reconciles existing evidence stores without becoming a new persistence
# owner and never upgrades knowledge as a side effect of opening an interface.

const LEVEL_UNKNOWN := 0
const LEVEL_OBSERVED := 1
const LEVEL_STUDIED := 2
const LEVEL_DOCUMENTED := 3

const LEVEL_LABELS := {
    LEVEL_UNKNOWN: "Inconnu",
    LEVEL_OBSERVED: "Observé",
    LEVEL_STUDIED: "Étudié",
    LEVEL_DOCUMENTED: "Documenté",
}

const ROGUELIKE_TIERS := {
    "unknown": LEVEL_UNKNOWN,
    "identity": LEVEL_OBSERVED,
    "stats": LEVEL_STUDIED,
    "abilities": LEVEL_STUDIED,
    "mastery": LEVEL_DOCUMENTED,
}

const EVIDENCE_LEVELS := {
    "encounter": LEVEL_OBSERVED,
    "combat_observation": LEVEL_OBSERVED,
    "world_trace": LEVEL_OBSERVED,
    "corpse": LEVEL_STUDIED,
    "repeated_pattern": LEVEL_STUDIED,
    "text": LEVEL_STUDIED,
    "sanctuary": LEVEL_STUDIED,
    "research": LEVEL_DOCUMENTED,
    "capture": LEVEL_DOCUMENTED,
}

static func enemy_view(
        enemy: Dictionary,
        campaign_entry: Dictionary = {},
        archive_entry: Dictionary = {},
        roguelike_entry: Dictionary = {},
        captured: bool = false,
        evidence: Array = []) -> Dictionary:
    var level := resolve_level(campaign_entry, archive_entry, roguelike_entry, captured, evidence)
    var normalized_evidence := normalize_evidence(evidence)
    var visible := {
        "id": str(enemy.get("id", "")),
        "name": "Silhouette inconnue",
        "side": "enemy",
        "public_vital_state": str(enemy.get("public_vital_state", enemy.get("vital_state", "unknown"))),
    }

    if level >= LEVEL_OBSERVED:
        visible["name"] = str(enemy.get("name", "Créature inconnue"))
        visible["level"] = int(enemy.get("level", 1))
        visible["vital_state"] = str(enemy.get("vital_state", visible["public_vital_state"]))
        _copy_if_present(visible, campaign_entry, "observed_skills")
        _copy_if_present(visible, campaign_entry, "observed_behaviors")

    if level >= LEVEL_STUDIED:
        for key in ["hp", "max_hp", "precision", "speed", "protection", "physical_resistance", "resistances", "damage"]:
            _copy_if_present(visible, enemy, key)
        var observed_skills: Array = _observed_skills(enemy, campaign_entry, archive_entry)
        visible["skills"] = observed_skills
        visible["abilities"] = observed_skills.duplicate(true)

    if level >= LEVEL_DOCUMENTED:
        for key in ["skills", "abilities", "traits", "positive_traits", "negative_traits", "body", "anatomy", "capture_conditions", "recruitment_conditions"]:
            _copy_if_present(visible, enemy, key)
        visible["capture_known"] = true
        visible["captured"] = captured

    return {
        "subject_id": str(enemy.get("id", "")),
        "subject_kind": "enemy",
        "knowledge_level": level,
        "knowledge_label": str(LEVEL_LABELS[level]),
        "reliability": _reliability(level),
        "visible": visible,
        "evidence": normalized_evidence,
        "hidden_sections": _hidden_sections(level),
        "read_only": true,
    }

static func world_view(subject_id: String, display_name: String, evidence: Array = []) -> Dictionary:
    var normalized := normalize_evidence(evidence)
    var level := LEVEL_UNKNOWN
    for row_value in normalized:
        var row: Dictionary = row_value
        level = maxi(level, int(row.get("reveal_level", LEVEL_UNKNOWN)))
    return {
        "subject_id": subject_id,
        "subject_kind": "world",
        "display_name": display_name if level > LEVEL_UNKNOWN else "Élément inconnu",
        "knowledge_level": level,
        "knowledge_label": str(LEVEL_LABELS[level]),
        "reliability": _reliability(level),
        "evidence": normalized,
        "read_only": true,
    }

static func resolve_level(
        campaign_entry: Dictionary = {},
        archive_entry: Dictionary = {},
        roguelike_entry: Dictionary = {},
        captured: bool = false,
        evidence: Array = []) -> int:
    var level := _campaign_level(int(campaign_entry.get("knowledge", 0)))
    level = maxi(level, clampi(int(archive_entry.get("knowledge_level", 0)), LEVEL_UNKNOWN, LEVEL_DOCUMENTED))
    level = maxi(level, int(ROGUELIKE_TIERS.get(str(roguelike_entry.get("tier", "unknown")), LEVEL_UNKNOWN)))
    if captured:
        level = LEVEL_DOCUMENTED
    for row_value in normalize_evidence(evidence):
        level = maxi(level, int((row_value as Dictionary).get("reveal_level", LEVEL_UNKNOWN)))
    return clampi(level, LEVEL_UNKNOWN, LEVEL_DOCUMENTED)

static func normalize_evidence(evidence: Array) -> Array[Dictionary]:
    var normalized: Array[Dictionary] = []
    var seen: Dictionary = {}
    for value in evidence:
        if not (value is Dictionary):
            continue
        var row: Dictionary = value
        var source := str(row.get("source", ""))
        if not EVIDENCE_LEVELS.has(source):
            continue
        var evidence_id := str(row.get("evidence_id", "%s:%s" % [source, normalized.size()]))
        if seen.has(evidence_id):
            continue
        seen[evidence_id] = true
        normalized.append({
            "evidence_id": evidence_id,
            "source": source,
            "label": str(row.get("label", source.replace("_", " ").capitalize())),
            "reveal_level": int(EVIDENCE_LEVELS[source]),
            "subject_id": str(row.get("subject_id", "")),
        })
    return normalized

static func _campaign_level(value: int) -> int:
    if value <= 0:
        return LEVEL_UNKNOWN
    if value == 1:
        return LEVEL_OBSERVED
    if value <= 3:
        return LEVEL_STUDIED
    return LEVEL_DOCUMENTED

static func _observed_skills(enemy: Dictionary, campaign_entry: Dictionary, archive_entry: Dictionary) -> Array:
    var result: Array = []
    for value in campaign_entry.get("observed_skills", []):
        if not result.has(value):
            result.append(value)
    var combat_value: Variant = archive_entry.get("combat", {})
    if combat_value is Dictionary:
        for observation_value in (combat_value as Dictionary).values():
            if not (observation_value is Dictionary):
                continue
            var observation: Dictionary = observation_value
            var skill_value: Variant = observation.get("skill", observation.get("skill_id", {}))
            if skill_value != null and not result.has(skill_value):
                result.append(skill_value)
    if result.is_empty() and int(campaign_entry.get("knowledge", 0)) >= 3:
        result = (enemy.get("skills", enemy.get("abilities", [])) as Array).duplicate(true)
    return result

static func _copy_if_present(target: Dictionary, source: Dictionary, key: String) -> void:
    if source.has(key):
        var value: Variant = source[key]
        target[key] = value.duplicate(true) if value is Dictionary or value is Array else value

static func _hidden_sections(level: int) -> Array[String]:
    match level:
        LEVEL_UNKNOWN:
            return ["identity", "statistics", "skills", "traits", "capture"]
        LEVEL_OBSERVED:
            return ["exact_statistics", "resistances", "skills_not_observed", "traits", "capture"]
        LEVEL_STUDIED:
            return ["skills_not_observed", "traits", "capture"]
        _:
            return []

static func _reliability(level: int) -> String:
    match level:
        LEVEL_UNKNOWN:
            return "observable_only"
        LEVEL_OBSERVED:
            return "approximate"
        LEVEL_STUDIED:
            return "corroborated"
        _:
            return "reliable"
