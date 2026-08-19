extends Node

var failures: Array[String] = []

func run() -> void:
    _check(not SfxLibrary.data.is_empty(), "SfxLibrary must load sfx_library.json")
    var coverage: Dictionary = SfxLibrary.coverage()
    _check(int(coverage.get("cue_families", 0)) >= 80, "SFX library must expose at least 80 cue families")
    _check(int(coverage.get("domains", 0)) >= 12, "SFX library must cover at least 12 sound-design domains")
    _check(int(coverage.get("packs", 0)) >= 12, "SFX library must expose candidate packs")
    _check(int(coverage.get("green", 0)) >= 10, "SFX library must retain at least ten low-friction green packs")
    _check(int(coverage.get("amber", 0)) >= 2, "SFX library must isolate attribution/platform-license candidates")
    _check(int(coverage.get("layering_presets", 0)) >= 7, "SFX library must define layering presets")
    _check(int(coverage.get("implementation_rules", 0)) >= 16, "SFX library must define substantial implementation rules")
    _check(int(coverage.get("ingestion_steps", 0)) >= 16, "SFX ingestion checklist must be substantial")

    for cue_id: String in [
        "footstep_ash", "footstep_stone", "weapon_blade_hit", "weapon_blunt_hit", "parry",
        "combat_telegraph", "dismemberment", "ultimate_release", "creature_ghoul",
        "creature_conscious", "boss_phase_change", "fear_heartbeat", "fear_tinnitus",
        "panic_sting", "hope_manifestation", "wind_ashlands", "ash_storm", "door_wood",
        "bell_sanctuary", "forge_hammer", "memorial_roomtone", "trap_trigger", "ui_confirm",
        "ui_page", "ui_reward", "ui_capture"
    ]:
        _check(SfxLibrary.has_cue(cue_id), "Required SFX cue missing: " + cue_id)

    var dismemberment: Dictionary = SfxLibrary.cue_metadata("dismemberment")
    _check(str(dismemberment.get("spatial", "")) == "3d", "Dismemberment must remain spatial")
    _check(int(dismemberment.get("variants_min", 0)) >= 4, "Dismemberment needs multiple variants")
    _check("restrained" in str(dismemberment.get("brief", "")), "Dismemberment brief must preserve restrained tone")

    var telegraph: Dictionary = SfxLibrary.cue_metadata("combat_telegraph")
    _check(str(telegraph.get("spatial", "")) == "2d", "Combat telegraph reinforcement must be readable")

    var conscious: Dictionary = SfxLibrary.cue_metadata("creature_conscious")
    _check("intelligent" in str(conscious.get("brief", "")), "Conscious creatures must retain intelligent sound identity")

    var hope: Dictionary = SfxLibrary.cue_metadata("hope_manifestation")
    _check("happy jingle" in str(hope.get("brief", "")), "Hope must explicitly avoid generic positive jingles")

    var weapons: Dictionary = SfxLibrary.candidate_pack("oga_weapon_impacts")
    _check(str(weapons.get("tier", "")) == "green", "CC0 medieval weapon impacts must remain green")
    _check(str(weapons.get("local_path", "not-empty")) == "", "Catalog must not pretend audio binaries were ingested")

    var by_pool: Dictionary = SfxLibrary.candidate_pack("freesound_by_pool")
    _check(str(by_pool.get("tier", "")) == "amber", "Freesound CC BY candidates must remain amber")
    _check(SfxLibrary.attribution_lines().size() >= 2, "Amber candidates must generate attribution/review lines")

    for item: Dictionary in SfxLibrary.shipping_candidate_packs(false):
        _check(str(item.get("tier", "")) == "green", "Default shipping candidates must be green only")
        _check(str(item.get("local_path", "not-empty")) == "", "Shipping catalog still must not imply local binaries")

    var mix: Dictionary = SfxLibrary.mix_priorities()
    var priority_variant: Variant = mix.get("priority_order", [])
    var priority: Array = priority_variant if priority_variant is Array else []
    _check(not priority.is_empty() and str(priority[0]) == "critical_dialogue", "Critical dialogue must outrank SFX and music")
    _check(not priority.is_empty() and str(priority[-1]) == "music", "Music must yield to critical gameplay sound")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("SFX_LIBRARY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("SFX_LIBRARY_SMOKE: " + failure)
    print("SFX_LIBRARY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
