extends Node

const HEROES := ["mathilde", "marec", "anouk", "aurelien"]
const FORBIDDEN_NAMES := ["Nayra Orun", "Tarek Senn", "Aïsha Maren", "Idris Vael", "Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"]

func _ready() -> void:
    for hero_id in HEROES:
        var path := "res://data/veilleurs/skills/%s.json" % hero_id
        assert(FileAccess.file_exists(path))
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        assert(parsed is Dictionary)
        var data: Dictionary = parsed
        assert(str(data.get("hero_id", "")) == hero_id)
        var tree_order: Array = data.get("tree_order", [])
        assert(tree_order.size() == 3)
        var trees: Dictionary = data.get("trees", {})
        var skill_count := 0
        for tree_id_value in tree_order:
            var tree_id := str(tree_id_value)
            assert(trees.has(tree_id))
            var tree: Dictionary = trees[tree_id]
            var skills: Array = tree.get("skills", [])
            assert(skills.size() == 15)
            skill_count += skills.size()
            assert(tree.has("ultimate"))
        assert(skill_count == 45)
        var raw := FileAccess.get_file_as_string(path)
        for forbidden in FORBIDDEN_NAMES:
            assert(not raw.contains(forbidden))

    var bridge_raw := FileAccess.get_file_as_string("res://data/veilleurs/combat_sandbox_quartet_bridge.json")
    for token in ["duelist_precise_strike", "breaker_guard_break", "mystic_read_pattern", "surgeon_targeted_cut"]:
        assert(not bridge_raw.contains(token))

    print("CURRENT_QUARTET_SKILL_DATA_SMOKE_OK")
    get_tree().quit(0)
