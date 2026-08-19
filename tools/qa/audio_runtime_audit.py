from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "prototype_audio_bank.json"
DIRECTOR_DATA = ROOT / "data" / "audio_director.json"
PROJECT = ROOT / "project.godot"
BANK_SCRIPT = ROOT / "scripts" / "core" / "prototype_audio_bank.gd"
SFX_SCRIPT = ROOT / "scripts" / "core" / "sfx_runtime.gd"
DIRECTOR_SCRIPT = ROOT / "scripts" / "core" / "audio_director.gd"
PLAYER_SCRIPT = ROOT / "scripts" / "world" / "exploration_party_controller.gd"
RUNNER = ROOT / "tools" / "build" / "run_godot_ci.sh"


def audit() -> list[str]:
    errors: list[str] = []
    for path in [DATA, DIRECTOR_DATA, PROJECT, BANK_SCRIPT, SFX_SCRIPT, DIRECTOR_SCRIPT, PLAYER_SCRIPT, RUNNER]:
        if not path.exists():
            errors.append(f"missing required audio runtime file: {path.relative_to(ROOT)}")
    if errors:
        return errors

    bank = json.loads(DATA.read_text(encoding="utf-8"))
    director = json.loads(DIRECTOR_DATA.read_text(encoding="utf-8"))
    assets = bank.get("assets", [])
    if len(assets) < 17:
        errors.append("prototype audio bank must expose at least 17 assets")
    ids = [str(item.get("id", "")) for item in assets]
    if len(ids) != len(set(ids)) or any(not value for value in ids):
        errors.append("prototype audio asset ids must be unique and non-empty")

    cues: set[str] = set()
    music = 0
    sfx = 0
    loops = 0
    for item in assets:
        kind = str(item.get("kind", ""))
        if kind == "music":
            music += 1
        elif kind == "sfx":
            sfx += 1
        else:
            errors.append(f"invalid audio kind for {item.get('id')}: {kind}")
        variants = int(item.get("variants", 0))
        if variants < 1:
            errors.append(f"asset {item.get('id')} must expose at least one variant")
        duration = float(item.get("duration", 0.0))
        if duration <= 0.0:
            errors.append(f"asset {item.get('id')} must have a positive duration")
        loops += int(bool(item.get("loop", False)))
        cues.update(str(value) for value in item.get("cues", []))
    if sfx < 11 or music < 6 or loops < 5:
        errors.append("prototype bank coverage is too small")

    required_cues = {
        "footstep_ash",
        "footstep_stone",
        "ui_confirm",
        "combat_telegraph",
        "fear_heartbeat",
        "fear_breath",
        "fear_tinnitus",
        "panic_sting",
        "boss_presence",
        "boss_phase_change",
        "wind_ashlands",
        "exploration_ashlands",
        "exploration_threat",
        "combat_normal",
        "combat_boss",
        "victory_costly",
        "defeat_retreat",
    }
    missing = sorted(required_cues - cues)
    if missing:
        errors.append(f"prototype bank missing cues: {', '.join(missing)}")

    policy = bank.get("legal_policy", {})
    if policy.get("third_party_material") is not False:
        errors.append("procedural prototype bank must state that no third-party material is embedded")
    if policy.get("status") != "prototype_only":
        errors.append("procedural bank must remain prototype_only")

    sources = bank.get("external_verified_sources", [])
    if not sources:
        errors.append("at least one exact external source must remain documented")
    else:
        footsteps = sources[0]
        if footsteps.get("license") != "CC0":
            errors.append("verified OpenGameArt footsteps source must remain CC0")
        if footsteps.get("status") != "license_verified_binary_not_vendored":
            errors.append("external source must not pretend its binary is already vendored")
        if len(footsteps.get("files", [])) < 6:
            errors.append("verified footsteps source should preserve all six exact filenames")

    if float(director.get("music_crossfade_seconds", 0.0)) <= 0.0:
        errors.append("audio director must configure a positive music crossfade")
    if director.get("prototype_audio_enabled") is not True:
        errors.append("prototype audio must be enabled for the playable technical build")

    project = PROJECT.read_text(encoding="utf-8")
    required_autoloads = [
        'PrototypeAudioBank="*res://scripts/core/prototype_audio_bank.gd"',
        'SfxRuntime="*res://scripts/core/sfx_runtime.gd"',
        'AudioDirector="*res://scripts/core/audio_director.gd"',
    ]
    for entry in required_autoloads:
        if entry not in project:
            errors.append(f"missing autoload: {entry}")
    if all(entry in project for entry in required_autoloads):
        if not (project.index(required_autoloads[0]) < project.index(required_autoloads[1]) < project.index(required_autoloads[2])):
            errors.append("audio autoload order must be PrototypeAudioBank -> SfxRuntime -> AudioDirector")

    bank_script = BANK_SCRIPT.read_text(encoding="utf-8")
    if "AudioStreamWAV.new()" not in bank_script or "FORMAT_8_BITS" not in bank_script:
        errors.append("prototype bank must create actual PCM AudioStreamWAV resources")
    if "HTTPRequest" in bank_script:
        errors.append("prototype bank must not depend on runtime network downloads")

    sfx_script = SFX_SCRIPT.read_text(encoding="utf-8")
    for token in ["AudioStreamPlayer3D.new()", "AudioStreamPlayer.new()", "position_3d", "set_loop_cues"]:
        if token not in sfx_script:
            errors.append(f"SfxRuntime missing implementation token: {token}")
    if "HTTPRequest" in sfx_script:
        errors.append("SfxRuntime must not fetch sound files from the network")

    director_script = DIRECTOR_SCRIPT.read_text(encoding="utf-8")
    for token in ["_crossfade_to_stream", "music_transition_started", "SfxRuntime.play_cue", "PrototypeAudioBank.stream_for_cue"]:
        if token not in director_script:
            errors.append(f"AudioDirector missing v2 implementation token: {token}")

    player_script = PLAYER_SCRIPT.read_text(encoding="utf-8")
    for token in ["_update_footsteps", "footstep_ash", "footstep_stone", "position_3d"]:
        if token not in player_script:
            errors.append(f"exploration footsteps missing token: {token}")

    runner = RUNNER.read_text(encoding="utf-8")
    if "audio_runtime_smoke.tscn" not in runner:
        errors.append("strict Godot runner must execute audio_runtime_smoke.tscn")

    return errors


def main() -> int:
    errors = audit()
    if errors:
        for error in errors:
            print(f"AUDIO_RUNTIME_AUDIT_ERROR: {error}")
        return 1
    print("AUDIO_RUNTIME_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
