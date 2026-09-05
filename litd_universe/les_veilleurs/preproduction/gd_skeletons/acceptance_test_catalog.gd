class_name LITDAcceptanceTestCatalog
extends RefCounted

## Preproduction skeleton: NOT compile-validated.
## Reads source rows from tests_48.json. It does not execute gameplay by itself.

var source_rows: Array = []

func configure(rows: Array) -> PackedStringArray:
    var errors := PackedStringArray()
    source_rows = rows.duplicate(true)
    if source_rows.size() != 48:
        errors.append("Expected 48 acceptance tests, got %d" % source_rows.size())
    var seen := {}
    for row in source_rows:
        var id := int(row.get("ID", -1))
        if id < 1:
            errors.append("Invalid test ID: %s" % str(row.get("ID", null)))
        elif seen.has(id):
            errors.append("Duplicate test ID: %d" % id)
        else:
            seen[id] = true
    return errors

func get_test(id: int) -> Dictionary:
    for row in source_rows:
        if int(row.get("ID", -1)) == id:
            return row
    return {}

func by_system(system_name: String) -> Array:
    var result := []
    for row in source_rows:
        if String(row.get("Système", "")) == system_name:
            result.append(row)
    return result

func blocking_tests() -> Array:
    var result := []
    for row in source_rows:
        if String(row.get("Sévérité", "")).to_lower() == "bloquant":
            result.append(row)
    return result

func execution_contract(id: int) -> Dictionary:
    var row := get_test(id)
    if row.is_empty():
        return {"ok": false, "error": "Unknown acceptance test %d" % id}
    return {
        "ok": true,
        "id": id,
        "system": row.get("Système", ""),
        "scenario": row.get("Scénario", ""),
        "expected": row.get("Résultat attendu", ""),
        "severity": row.get("Sévérité", ""),
        "source_status": row.get("Statut", "")
    }
