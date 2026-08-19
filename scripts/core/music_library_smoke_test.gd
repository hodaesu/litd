extends Node

var failures: Array[String] = []

func run() -> void:
    _check(not MusicLibrary.data.is_empty(), "MusicLibrary must load music_library.json")
    var coverage: Dictionary = MusicLibrary.coverage()
    _check(int(coverage.get("tracks", 0)) >= 25, "Music library must expose a broad candidate pool")
    _check(int(coverage.get("cue_families", 0)) >= 24, "Music library must cover narrative and gameplay cue families")
    _check(int(coverage.get("green", 0)) >= 15, "Music library must retain a meaningful low-friction shipping candidate pool")
    _check(int(coverage.get("mapped_cues", 0)) >= 20, "Most scoring cues must already have candidate music")
    _check(MusicLibrary.adaptive_score_rules().size() >= 10, "Adaptive score design rules must be substantial")
    _check(MusicLibrary.ingestion_checklist().size() >= 10, "Asset ingestion must archive license and technical evidence")

    for cue_id: String in ["exploration_ashlands", "exploration_ruins", "exploration_threat", "combat_normal", "combat_elite", "combat_boss", "sadness_loss", "memorial", "hope_manifestation", "sanctuary_day", "tavern", "ancient_archive", "fear_panic", "ending_choice"]:
        _check(not MusicLibrary.cue(cue_id).is_empty(), "Required cue missing: " + cue_id)

    _check(not MusicLibrary.tracks_for_cue("exploration_ruins").is_empty(), "Exploration ruins must have green candidates")
    _check(not MusicLibrary.tracks_for_cue("combat_boss").is_empty(), "Boss combat must have green candidates")
    _check(not MusicLibrary.tracks_for_cue("memorial").is_empty(), "Memorial must have green candidates")
    _check(not MusicLibrary.tracks_for_cue("sanctuary_day").is_empty(), "Sanctuary must have green candidates")

    var caves: Dictionary = MusicLibrary.track("px_caves_of_dawn")
    _check(str(caves.get("source", "")) == "pixabay", "Caves of Dawn must retain its source")
    _check(str(caves.get("legal_tier", "")) == "green", "Caves of Dawn must be in the reviewed green candidate pool")
    _check(str(caves.get("local_path", "not-empty")) == "", "Catalog must not pretend an audio binary was ingested")

    var tavern: Dictionary = MusicLibrary.track("px_tavern_dance")
    _check(str(tavern.get("legal_tier", "")) == "amber", "Content-ID registered tracks must remain amber")
    _check(tavern.get("content_id", false) == true, "Tavern Dance must preserve its Content ID warning")

    _check(MusicLibrary.source_is_excluded("mixkit"), "Mixkit must be excluded while its music license prohibits video-game use")
    for item: Dictionary in MusicLibrary.shipping_candidates(true):
        _check(str(item.get("source", "")) != "mixkit", "Excluded sources must never leak into shipping candidates")
        _check(str(item.get("legal_tier", "")) != "red", "Red tracks must never leak into shipping candidates")

    var identity_risk: Dictionary = MusicLibrary.track("px_cinematic_dark_fantasy_identity_risk")
    _check(str(identity_risk.get("legal_tier", "")) == "red", "Recognizable-franchise identity risk must be rejected")
    _check(MusicLibrary.credits_lines().size() >= 4, "Attribution-required candidates must generate credit lines")

    var mix: Dictionary = MusicLibrary.mix_priorities()
    _check(str(mix.get("combat_telegraph_priority", "")) == "above_music", "Combat readability must outrank the score")
    _check(str(mix.get("critical_voice_line_ducking_db", "")) != "", "Critical dialogue must define a music-ducking baseline")

    _finish()

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("MUSIC_LIBRARY_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("MUSIC_LIBRARY_SMOKE: " + failure)
    print("MUSIC_LIBRARY_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
