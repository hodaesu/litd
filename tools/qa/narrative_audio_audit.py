#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_SPACES = {"sanctuary", "community", "tavern", "chapel", "memorial"}
REQUIRED_SPACE_CUES = {
    "sanctuary_day", "tavern", "chapel", "memorial", "creature_empathy"
}
REQUIRED_ROOMTONES = {
    "sanctuary_crowd", "tavern_roomtone", "chapel_roomtone", "memorial_roomtone"
}
REQUIRED_BEATS = {"rumor", "revelation", "choice", "loss", "reunion", "quest_accept", "quest_complete"}


def run(root: Path = ROOT) -> dict:
    data_path = root / "data/narrative_audio.json"
    prototype_path = root / "data/prototype_audio_bank.json"
    runtime_path = root / "scripts/core/narrative_audio_director.gd"
    main_path = root / "scripts/ui/main_v23.gd"
    scene_main_path = root / "scenes/Main.tscn"
    smoke_path = root / "scripts/core/narrative_audio_smoke_test.gd"
    smoke_scene_path = root / "scenes/tests/narrative_audio_smoke.tscn"
    project_path = root / "project.godot"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"
    ci_path = root / ".github/workflows/ci.yml"
    docs_path = root / "docs/design/narrative_audio_pass_21.md"
    community_path = root / "data/community_network.json"

    data = json.loads(data_path.read_text(encoding="utf-8"))
    prototype = json.loads(prototype_path.read_text(encoding="utf-8"))
    community = json.loads(community_path.read_text(encoding="utf-8"))
    runtime = runtime_path.read_text(encoding="utf-8")
    main = main_path.read_text(encoding="utf-8")
    scene_main = scene_main_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    smoke_scene = smoke_scene_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")
    ci = ci_path.read_text(encoding="utf-8")
    docs = docs_path.read_text(encoding="utf-8")

    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Narrative audio : schéma v1", int(data.get("version", 0)) >= 1)
    check("Narrative audio : design source", data.get("design_source") == "narrative_audio_pass_21")

    ducking = data.get("dialogue_ducking_db", {})
    check("Dialogue : musique fortement duckée", float(ducking.get("Music", 0.0)) <= -8.0)
    check("Dialogue : Dialogue reste neutre", float(ducking.get("Dialogue", -99.0)) == 0.0)
    check("Dialogue : Combat n'est pas muté", float(ducking.get("Combat", -99.0)) > -6.0)

    contexts = data.get("screen_contexts", {})
    check("Sanctuaire : espaces requis", REQUIRED_SPACES <= set(contexts.keys()), str(sorted(REQUIRED_SPACES - set(contexts.keys()))))
    context_music = {str(v.get("music", "")) for v in contexts.values() if isinstance(v, dict)}
    check("Sanctuaire : cues musique", REQUIRED_SPACE_CUES <= context_music, str(sorted(REQUIRED_SPACE_CUES - context_music)))
    context_loops = {
        str(cue)
        for value in contexts.values()
        if isinstance(value, dict)
        for cue in value.get("loops", [])
    }
    check("Sanctuaire : roomtones", REQUIRED_ROOMTONES <= context_loops, str(sorted(REQUIRED_ROOMTONES - context_loops)))

    beats = data.get("beats", {})
    check("Narration : beats complets", REQUIRED_BEATS <= set(beats.keys()), str(sorted(REQUIRED_BEATS - set(beats.keys()))))
    choice = beats.get("choice", {})
    check("Choix : pas de moralisation audio", choice.get("rule") == "neutral_weight_no_moral_answer")
    check("Révélation : silence avant musique", float(beats.get("revelation", {}).get("silence_seconds", 0.0)) > 0.0)
    check("Perte : silence avant musique", float(beats.get("loss", {}).get("silence_seconds", 0.0)) > 0.0)

    quest_ids = {str(q.get("id", "")) for q in community.get("quests", []) if isinstance(q, dict)}
    motifs = data.get("quest_motifs", {})
    required_quest_ids = {"q_iven_korem_archive", "q_yoren_safe_line"}
    check("Quêtes : motifs pour les deux histoires existantes", required_quest_ids <= set(motifs.keys()))
    check("Quêtes : motifs pointent vers des quêtes réelles", set(motifs.keys()) <= quest_ids, str(sorted(set(motifs.keys()) - quest_ids)))

    assets = prototype.get("assets", [])
    sfx_cues: set[str] = set()
    music_cues: set[str] = set()
    looping_sfx: set[str] = set()
    for item in assets:
        if not isinstance(item, dict):
            continue
        cues = {str(c) for c in item.get("cues", [])}
        if item.get("kind") == "music":
            music_cues |= cues
        else:
            sfx_cues |= cues
            if item.get("loop") is True:
                looping_sfx |= cues
    check("Prototype : roomtones audibles", REQUIRED_ROOMTONES <= sfx_cues)
    check("Prototype : roomtones en boucle", REQUIRED_ROOMTONES <= looping_sfx)
    check("Prototype : musiques du Sanctuaire", {"sanctuary_day", "tavern", "chapel", "memorial"} <= music_cues)
    check("Prototype : motifs narratifs", {"ancient_archive", "discovery_revelation"} <= music_cues)
    check("Prototype : aucun matériau tiers", prototype.get("legal_policy", {}).get("third_party_material") is False)

    runtime_tokens = [
        'const DATA_PATH := "res://data/narrative_audio.json"',
        "func enter_screen_context(",
        "func begin_dialogue(",
        "func end_dialogue(",
        "func play_spoken_moment(",
        "func scripted_silence(",
        "func trigger_beat(",
        "func quest_motif(",
        "CommunityRuntime.quest_changed",
        "GameState.screen_requested",
        "AudioDirector.mix_changed",
        "SfxRuntime.set_loop_cues(",
        "AudioDirector.request_music(",
    ]
    for token in runtime_tokens:
        check(f"Runtime : {token}", token in runtime)

    lower_runtime = runtime.lower()
    check("Runtime : pas de jauge morale", "morality" not in lower_runtime and "moral_score" not in lower_runtime)
    check("Main v23 : rumeur audio", 'trigger_beat("rumor"' in main)
    check("Main scene : v23 actif", 'res://scripts/ui/main_v23.gd' in scene_main)
    check("Projet : autoload narratif", 'NarrativeAudioDirector="*res://scripts/core/narrative_audio_director.gd"' in project)

    smoke_tokens = ["sanctuary_day", "begin_dialogue", "scripted_silence", "q_iven_korem_archive", "discovery_revelation", "NARRATIVE_AUDIO_SMOKE_OK"]
    for token in smoke_tokens:
        check(f"Smoke : {token}", token in smoke)
    check("Smoke : scène", "narrative_audio_smoke_bootstrap.gd" in smoke_scene)
    check("Godot CI : smoke narratif", "narrative_audio_smoke.tscn" in godot_ci)
    check("CI : audit narratif audio", "python -m tools.qa.narrative_audio_audit" in ci)

    lower_docs = docs.lower()
    for keyword in ["dialogue", "silence", "sanctuaire", "taverne", "chapelle", "mémorial", "motif", "révélation"]:
        check(f"Docs : {keyword}", keyword in lower_docs)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "narrative-audio-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
