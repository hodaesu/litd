extends Node

const DB_SCRIPT := preload("res://scripts/core/veilleurs_content_db_v081_canonical.gd")
const TACTICAL_SCRIPT := preload("res://scripts/core/veilleurs_tactical_combat_runtime_v07.gd")

const WATCHERS: Array[String] = [
    "ENT_WATCHER_SAHEN",
    "ENT_WATCHER_MIRA",
    "ENT_WATCHER_NAREM",
    "ENT_WATCHER_YSRA"
]
const LEGACY: Array[String] = [
    "ENT_WATCHER_NAYRA",
    "ENT_WATCHER_TAREK",
    "ENT_WATCHER_AISHA",
    "ENT_WATCHER_IDRIS"
]
const TREE_TO_ULTIMATE := {
    "TREE_SAHEN_BRISEUR_LIGNES":"ULT_WATCHER_SAHEN_BRISEUR_LIGNES",
    "TREE_SAHEN_GARDIEN_MARTIAL":"ULT_WATCHER_SAHEN_GARDIEN_MARTIAL",
    "TREE_SAHEN_MAITRISE_CORPS":"ULT_WATCHER_SAHEN_MAITRISE_CORPS",
    "TREE_MIRA_OEIL_VEILLEUR":"ULT_WATCHER_MIRA_OEIL_VEILLEUR",
    "TREE_MIRA_DANSE_INTERVALLES":"ULT_WATCHER_MIRA_DANSE_INTERVALLES",
    "TREE_MIRA_ANATOMIE_MOUVEMENT":"ULT_WATCHER_MIRA_ANATOMIE_MOUVEMENT",
    "TREE_NAREM_BASTION_VIVANT":"ULT_WATCHER_NAREM_BASTION_VIVANT",
    "TREE_NAREM_DISCIPLINE_EPREUVE":"ULT_WATCHER_NAREM_DISCIPLINE_EPREUVE",
    "TREE_NAREM_GARDIEN_AUTRES":"ULT_WATCHER_NAREM_GARDIEN_AUTRES",
    "TREE_YSRA_LECTURE_INTENTIONS":"ULT_WATCHER_YSRA_LECTURE_INTENTIONS",
    "TREE_YSRA_REMANENCE_CONSCIENTE":"ULT_WATCHER_YSRA_REMANENCE_CONSCIENTE",
    "TREE_YSRA_PAROLE_BRISE":"ULT_WATCHER_YSRA_PAROLE_BRISE"
}

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var db: VeilleursContentDBV081Canonical = DB_SCRIPT.new() as VeilleursContentDBV081Canonical
    db.reload()
    var summary: Dictionary = db.production_summary()
    _check(db.load_errors.is_empty(), "Base ContentDB has no load errors")
    _check(db.production_load_errors.is_empty(), "v0.8.1 production overlay has no load errors")
    _check(int(summary.get("watchers", 0)) == 4, "Exactly four canonical Watchers load")
    _check(int(summary.get("watcher_skills", 0)) == 180, "Canonical Watchers expose 180 normal skills")
    _check(int(summary.get("ultimates", 0)) == 99, "Combined production registry exposes 99 Ultimates")

    for watcher_id: String in WATCHERS:
        _check(not db.watcher(watcher_id).is_empty(), "Canonical Watcher loads: %s" % watcher_id)
        _check(db.skills_for(watcher_id).size() == 45, "Canonical Watcher has 45 normal skills: %s" % watcher_id)
        _check(db.ultimates_for(watcher_id).size() == 3, "Canonical Watcher has 3 Ultimates: %s" % watcher_id)
    for legacy_id: String in LEGACY:
        _check(db.watcher(legacy_id).is_empty(), "Legacy Watcher is absent from active ContentDB: %s" % legacy_id)
        _check(db.ultimates_for(legacy_id).is_empty(), "Legacy Watcher has no active v0.8.1 Ultimates: %s" % legacy_id)

    var ultimate_runtime := VeilleursUltimateRuntime.new()
    for tree_value: Variant in TREE_TO_ULTIMATE.keys():
        var tree_id := str(tree_value)
        var owner := _owner_for_tree(tree_id)
        var selected: Dictionary = ultimate_runtime.ultimate_for_tree(db, owner, tree_id)
        _check(str(selected.get("ultimate_id", "")) == str(TREE_TO_ULTIMATE[tree_id]), "Tree resolves its canonical Ultimate: %s" % tree_id)
        _check(bool(selected.get("prevent_generic_fallback", false)), "Canonical Ultimate blocks silent fallback: %s" % tree_id)
        _check(str(selected.get("resolver_id", "")) == "veilleurs_ultimate_runtime_v07", "Canonical Ultimate has explicit runtime resolver: %s" % tree_id)

    var runtime: VeilleursTacticalCombatRuntimeV07 = TACTICAL_SCRIPT.new() as VeilleursTacticalCombatRuntimeV07
    runtime.content_db = db
    var setup: Dictionary = runtime.setup_first_combat(["ENT_ENEMY_GOULE_AFFAMEE"])
    _check(bool(setup.get("ok", false)), "Canonical v0.8.1 ContentDB runs inside tactical v0.7 combat")
    if bool(setup.get("ok", false)):
        var progress := {
            "level":16,
            "chosen_tree":"TREE_SAHEN_BRISEUR_LIGNES",
            "ultimate_charges":1
        }
        var result: Dictionary = runtime.ultimate_runtime.prepare(runtime, "ENT_WATCHER_SAHEN", "ENT_ENEMY_GOULE_AFFAMEE", progress)
        _check(bool(result.get("ok", false)), "Sahen canonical Ultimate executes")
        _check(str(result.get("ultimate_id", "")) == "ULT_WATCHER_SAHEN_BRISEUR_LIGNES", "Sahen executes La Ligne Cède")
        _check(bool(result.get("charge_spent", false)), "Ultimate consumes one charge on success")
        var next_progress: Dictionary = result.get("progress_state", {})
        _check(int(next_progress.get("ultimate_charges", -1)) == 0, "Ultimate charge state decrements from 1 to 0")
        var target: Dictionary = runtime.combatants.get("ENT_ENEMY_GOULE_AFFAMEE", {})
        var statuses: Dictionary = target.get("statuses", {})
        _check(statuses.has("PINNED") and statuses.has("EXPOSED"), "La Ligne Cède applies its explicit control profile")

    if failures.is_empty():
        print("VEILLEURS_V081_CANONICAL_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_V081_CANONICAL: " + failure)
    print("VEILLEURS_V081_CANONICAL_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)

func _owner_for_tree(tree_id: String) -> String:
    if tree_id.begins_with("TREE_SAHEN_"):
        return "ENT_WATCHER_SAHEN"
    if tree_id.begins_with("TREE_MIRA_"):
        return "ENT_WATCHER_MIRA"
    if tree_id.begins_with("TREE_NAREM_"):
        return "ENT_WATCHER_NAREM"
    if tree_id.begins_with("TREE_YSRA_"):
        return "ENT_WATCHER_YSRA"
    return ""

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
