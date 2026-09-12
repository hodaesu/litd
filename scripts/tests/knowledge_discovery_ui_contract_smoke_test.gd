extends Node

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var enemy := {
        "id": "hungry_ghoul",
        "name": "Goule affamée",
        "level": 3,
        "hp": 34,
        "max_hp": 40,
        "damage": [4, 7],
        "physical_resistance": 12,
        "skills": [{"id": "ash_bite", "name": "Morsure de cendre"}],
        "traits": ["charognarde"],
        "capture_conditions": ["fed_without_exploitation"],
        "public_vital_state": "wounded",
    }
    var original := enemy.duplicate(true)

    var unknown := KnowledgeDiscoveryUIContract.enemy_view(enemy)
    _check(int(unknown.get("knowledge_level", -1)) == KnowledgeDiscoveryUIContract.LEVEL_UNKNOWN, "unknown level")
    var unknown_visible: Dictionary = unknown.get("visible", {})
    _check(str(unknown_visible.get("name", "")) == "Silhouette inconnue", "unknown identity remains hidden")
    _check(not unknown_visible.has("hp"), "unknown exact HP remains hidden")

    var observed := KnowledgeDiscoveryUIContract.enemy_view(enemy, {"knowledge": 1})
    var observed_visible: Dictionary = observed.get("visible", {})
    _check(str(observed.get("knowledge_label", "")) == "Observé", "encounter becomes observed")
    _check(str(observed_visible.get("name", "")) == "Goule affamée", "observed identity is visible")
    _check(not observed_visible.has("damage"), "observed exact damage remains hidden")

    var studied := KnowledgeDiscoveryUIContract.enemy_view(
        enemy,
        {"knowledge": 2, "observed_skills": [{"id": "ash_bite", "name": "Morsure de cendre"}]},
        {},
        {},
        false,
        [{"evidence_id": "text:ghoul", "source": "text", "label": "Fragment d'archive"}]
    )
    var studied_visible: Dictionary = studied.get("visible", {})
    _check(str(studied.get("knowledge_label", "")) == "Étudié", "corroborated evidence becomes studied")
    _check(int(studied_visible.get("hp", 0)) == 34, "studied exact HP is visible")
    _check((studied_visible.get("skills", []) as Array).size() == 1, "only observed skill is exposed")
    _check(not studied_visible.has("traits"), "studied traits remain hidden")

    var documented := KnowledgeDiscoveryUIContract.enemy_view(
        enemy,
        {},
        {},
        {},
        true,
        [{"evidence_id": "capture:ghoul", "source": "capture"}, {"evidence_id": "capture:ghoul", "source": "capture"}]
    )
    var documented_visible: Dictionary = documented.get("visible", {})
    _check(str(documented.get("knowledge_label", "")) == "Documenté", "capture documents enemy")
    _check(bool(documented_visible.get("capture_known", false)), "documented capture information is visible")
    _check((documented.get("evidence", []) as Array).size() == 1, "evidence is deduplicated")

    var world := KnowledgeDiscoveryUIContract.world_view("s8_archive", "Archive de S8", [
        {"evidence_id": "trace:s8", "source": "world_trace"},
        {"evidence_id": "research:s8", "source": "research"},
    ])
    _check(str(world.get("knowledge_label", "")) == "Documenté", "world knowledge uses the same levels")
    _check(str(world.get("display_name", "")) == "Archive de S8", "known world subject reveals its name")

    _check(enemy == original, "presentation contract never mutates source data")
    _check(bool(documented.get("read_only", false)), "view explicitly remains read-only")
    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("KNOWLEDGE_DISCOVERY_UI_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("KNOWLEDGE_DISCOVERY_UI_CONTRACT_FAIL: %s" % failure)
    get_tree().quit(1)
