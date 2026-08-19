#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_BUSES = {
    "Music", "Ambience", "Foley", "Combat", "Creatures", "Psychology", "Dialogue", "UI"
}
REQUIRED_MUSIC = {
    "exploration_ashlands", "exploration_ruins", "exploration_threat",
    "combat_normal", "combat_elite", "combat_boss", "victory_costly", "defeat_retreat"
}
REQUIRED_SFX = {
    "wind_ashlands", "boss_presence", "boss_phase_change",
    "fear_breath", "fear_heartbeat", "fear_tinnitus", "panic_sting"
}


def run(root: Path = ROOT) -> dict:
    data_path = root / "data/audio_director.json"
    runtime_path = root / "scripts/core/audio_director.gd"
    smoke_path = root / "scripts/core/audio_director_smoke_test.gd"
    scene_path = root / "scenes/tests/audio_director_smoke.tscn"
    project_path = root / "project.godot"
    ci_path = root / ".github/workflows/ci.yml"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"
    docs_path = root / "docs/design/audio_director_v1.md"
    music_path = root / "data/music_library.json"
    sfx_path = root / "data/sfx_library.json"

    payload = json.loads(data_path.read_text(encoding="utf-8"))
    music = json.loads(music_path.read_text(encoding="utf-8"))
    sfx = json.loads(sfx_path.read_text(encoding="utf-8"))
    runtime = runtime_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    ci = ci_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")
    docs = docs_path.read_text(encoding="utf-8")

    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("AudioDirector : schéma v1", int(payload.get("version", 0)) >= 1)
    check("AudioDirector : source de design", payload.get("design_source") == "adaptive_audio_director_pass_19")

    buses = set(map(str, payload.get("bus_order", [])))
    check("AudioDirector : huit bus", buses == REQUIRED_BUSES, str(sorted(buses)))
    defaults = payload.get("bus_defaults_db", {})
    check("AudioDirector : niveaux par défaut complets", REQUIRED_BUSES <= set(defaults.keys()))

    presets = payload.get("mix_presets", {})
    for preset_id in ["exploration", "combat", "boss"]:
        preset = presets.get(preset_id, {})
        check(f"Mix : preset {preset_id}", REQUIRED_BUSES <= set(preset.keys()))
    check("Mix : combat foreground", float(presets.get("combat", {}).get("Combat", -80)) >= -1.0)
    check("Mix : boss foreground", float(presets.get("boss", {}).get("Creatures", -80)) >= 0.0)
    check("Mix : exploration respire", float(presets.get("exploration", {}).get("Ambience", -80)) > -4.0)

    fear_profiles = payload.get("fear_profiles", [])
    fear_ids = [str(item.get("id", "")) for item in fear_profiles if isinstance(item, dict)]
    check("Peur : cinq profils", fear_ids == ["calm", "uneasy", "afraid", "terrified", "panic"], str(fear_ids))
    if fear_profiles:
        check("Peur : calme silencieux", float(fear_profiles[0].get("psychology_db", 0)) <= -70.0)
        check("Peur : panique duck musique", float(fear_profiles[-1].get("music_offset_db", 0)) <= -5.0)
        check("Peur : panique sting", "panic_sting" in fear_profiles[-1].get("sfx", []))

    encounter_music = payload.get("encounter_music", {})
    check("Combat : normal", encounter_music.get("normal") == "combat_normal")
    check("Combat : miniboss", encounter_music.get("miniboss") == "combat_elite")
    check("Combat : boss", encounter_music.get("boss") == "combat_boss")
    check("Boss : présence", "boss_presence" in payload.get("boss_entry_sfx", []))
    check("Boss : phase", "boss_phase_change" in payload.get("boss_phase_sfx", []))

    music_cues = {str(item.get("id", "")) for item in music.get("cue_families", []) if isinstance(item, dict)}
    check("AudioDirector : cues musique existants", REQUIRED_MUSIC <= music_cues, str(sorted(REQUIRED_MUSIC - music_cues)))
    sfx_domains = sfx.get("cue_domains", {})
    sfx_cues = {str(cue) for values in sfx_domains.values() if isinstance(values, list) for cue in values}
    check("AudioDirector : cues SFX existants", REQUIRED_SFX <= sfx_cues, str(sorted(REQUIRED_SFX - sfx_cues)))

    policy = payload.get("selection_policy", {})
    check("Sélection : musique verte", policy.get("music_legal_tiers") == ["green"])
    check("Sélection : SFX ambre désactivé", policy.get("sfx_include_amber") is False)
    check("Sélection : lecture locale vérifiée", policy.get("play_only_verified_local_paths") is True)

    runtime_tokens = [
        'const DATA_PATH := "res://data/audio_director.json"',
        "func set_exploration_zone(",
        "func enter_combat_context(",
        "func finish_combat_context(",
        "func notify_boss_phase(",
        "func refresh_from_game_state()",
        "func request_music(",
        "func request_sfx(",
        "func snapshot()",
        "AudioServer.add_bus()",
        "MusicLibrary.tracks_for_cue(",
        "SfxLibrary.packs_for_cue(",
        "AshlandsCombatBridge.ashlands_combat_started",
        "PsychologyRuntime.hero_psychology_changed",
    ]
    for token in runtime_tokens:
        check(f"Runtime : {token}", token in runtime)

    check("Projet : AudioDirector autoload", 'AudioDirector="*res://scripts/core/audio_director.gd"' in project)
    check("Smoke : exploration", "set_exploration_zone" in smoke)
    check("Smoke : combat", "enter_combat_context" in smoke)
    check("Smoke : boss", "notify_boss_phase" in smoke)
    check("Smoke : Peur", '"fear_profile"' in smoke and '"panic"' in smoke)
    check("Smoke : scène", "audio_director_smoke_bootstrap.gd" in scene)
    check("Godot CI : AudioDirector smoke", "audio_director_smoke.tscn" in godot_ci)
    check("CI : audit AudioDirector", "python -m tools.qa.audio_director_audit" in ci)

    lower_docs = docs.lower()
    check("Docs : exploration", "exploration" in lower_docs)
    check("Docs : combat", "combat" in lower_docs)
    check("Docs : peur", "peur" in lower_docs)
    check("Docs : boss", "boss" in lower_docs)
    check("Docs : pas de faux assets", "local_path" in docs and "vérifié" in lower_docs)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "audio-director-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
