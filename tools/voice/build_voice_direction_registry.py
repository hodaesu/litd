#!/usr/bin/env python3
"""Build the authored emotional voice-direction registry for LITD."""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/voice_direction_contract.json"
PROFILES = ROOT / "data/emotional_voice_profiles.json"
OVERRIDES = ROOT / "data/voice_direction_overrides.json"
REACTIVE = ROOT / "data/reactive_dialogues.json"
DEMO = ROOT / "data/demo_content_pack.json"
OUTPUT = ROOT / "data/voice_direction_registry.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def _all_lines(root: Path) -> list[dict[str, Any]]:
    reactive = _load(root / "data/reactive_dialogues.json")
    demo = _load(root / "data/demo_content_pack.json")
    lines: list[dict[str, Any]] = []
    for raw in reactive.get("lines", []):
        if not isinstance(raw, dict):
            continue
        lines.append({
            "line_id": str(raw.get("id", "")),
            "speaker_id": "narration" if str(raw.get("speaker_id", "")) == "narrator" else str(raw.get("speaker_id", "")),
            "context": str(raw.get("event", "")),
            "text": str(raw.get("text", "")).strip(),
            "source": "data/reactive_dialogues.json",
            "fourth_wall": bool(raw.get("fourth_wall", False)),
            "meta_level": str(raw.get("meta_level", "")),
        })
    for raw in demo.get("dialogue_barks", []):
        if not isinstance(raw, dict):
            continue
        lines.append({
            "line_id": str(raw.get("id", "")),
            "speaker_id": str(raw.get("speaker", "")),
            "context": str(raw.get("context", "")),
            "text": str(raw.get("text", "")).strip(),
            "source": "data/demo_content_pack.json#dialogue_barks",
            "fourth_wall": False,
            "meta_level": "",
        })
    return sorted(lines, key=lambda item: str(item["line_id"]))


def _default_state(context: str) -> tuple[str, str]:
    physical = {
        "low_hp": "wounded",
        "combat_start": "post_exertion",
        "panic": "stable",
        "companion_death": "stable",
    }.get(context, "stable")
    psychological = {
        "panic": "high_fear",
        "companion_death": "grieving",
        "many_deaths": "grieving",
        "last_original_survivor": "dissociated",
        "combat_start": "determined",
        "risk_repeat": "determined",
    }.get(context, "grounded")
    return physical, psychological


def _event_default(contract: dict[str, Any], context: str) -> dict[str, Any]:
    defaults = contract.get("emotion_defaults_by_event", {})
    default = defaults.get(context, {}) if isinstance(defaults, dict) else {}
    return {
        "emotion": str(default.get("emotion", contract["global_delivery"]["default_emotion"])),
        "secondary_emotion": None,
        "intensity": int(default.get("intensity", contract["global_delivery"]["default_intensity"])),
    }


def _apply_meta(direction: dict[str, Any], meta_level: str, contract: dict[str, Any]) -> None:
    if not meta_level:
        return
    modifier = dict(contract.get("meta_level_modifiers", {}).get(meta_level, {}))
    if not modifier:
        return
    direction["secondary_emotion"] = modifier.get("secondary_emotion") or direction.get("secondary_emotion")
    direction["intensity"] = max(1, min(5, int(direction["intensity"]) + int(modifier.get("intensity_delta", 0))))
    note = str(modifier.get("delivery_note", "")).strip()
    if note:
        direction["delivery_note"] = (str(direction.get("delivery_note", "")).strip() + " " + note).strip()


def _speed_multiplier(emotion: dict[str, Any], intensity: int, contract: dict[str, Any]) -> float:
    base = float(emotion.get("speed_multiplier", 1.0))
    strength = float(contract["intensity_scale"][str(intensity)]["speed_strength"])
    return round(1.0 + (base - 1.0) * strength, 3)


def build_registry(root: Path = ROOT) -> dict[str, Any]:
    contract = _load(root / "data/voice_direction_contract.json")
    profiles = _load(root / "data/emotional_voice_profiles.json").get("profiles", {})
    overrides = _load(root / "data/voice_direction_overrides.json").get("overrides", {})
    emotions = contract.get("emotions", {})
    entries: list[dict[str, Any]] = []
    seen: set[str] = set()

    for line in _all_lines(root):
        line_id = str(line["line_id"])
        text = str(line["text"])
        speaker_id = str(line["speaker_id"])
        context = str(line["context"])
        if not line_id or not text:
            raise ValueError("Every voice-directed line needs an id and authored text")
        if line_id in seen:
            raise ValueError(f"Duplicate directed line id: {line_id}")
        seen.add(line_id)
        if speaker_id not in profiles:
            raise ValueError(f"{line_id}: no emotional voice profile for {speaker_id}")

        direction = _event_default(contract, context)
        physical, psychological = _default_state(context)
        direction.update({
            "relationship": "unseen_presence" if line["fourth_wall"] else ("narration" if speaker_id == "narration" else "party_or_unknown"),
            "physical_state": physical,
            "psychological_state": psychological,
            "pause_profile": "thought_led",
            "stress_words": [],
            "transition": "none",
            "delivery_note": "Préserver la baseline du personnage; jouer l'émotion sans changer son identité.",
            "manual_review": False,
        })
        origin = "event_default"
        _apply_meta(direction, str(line["meta_level"]), contract)

        explicit = overrides.get(line_id)
        if isinstance(explicit, dict):
            direction.update(explicit)
            origin = "explicit_override"

        emotion_id = str(direction.get("emotion", ""))
        secondary_id = direction.get("secondary_emotion")
        intensity = int(direction.get("intensity", 0))
        if emotion_id not in emotions:
            raise ValueError(f"{line_id}: unknown emotion {emotion_id}")
        if secondary_id is not None and str(secondary_id) not in emotions:
            raise ValueError(f"{line_id}: unknown secondary emotion {secondary_id}")
        if intensity not in range(1, 6):
            raise ValueError(f"{line_id}: intensity must be 1..5")
        if intensity == 5:
            direction["manual_review"] = True
        if intensity == 5 and direction.get("manual_review") is not True:
            raise ValueError(f"{line_id}: intensity 5 requires manual review")

        normalized_text = _normalize(text)
        for stress in direction.get("stress_words", []):
            if _normalize(str(stress)) not in normalized_text:
                raise ValueError(f"{line_id}: stress phrase not found in text: {stress}")

        emotion = dict(emotions[emotion_id])
        prosody = {key: emotion[key] for key in [
            "pace", "pitch_bias", "pitch_range", "volume", "breath", "articulation", "pause_profile", "ending_cadence", "tension", "anti_caricature"
        ] if key in emotion}
        prosody["pause_profile"] = str(direction.get("pause_profile", prosody.get("pause_profile", "thought_led")))

        entries.append({
            "line_id": line_id,
            "speaker_id": speaker_id,
            "context": context,
            "text": text,
            "source": line["source"],
            "emotion": emotion_id,
            "secondary_emotion": secondary_id,
            "intensity": intensity,
            "relationship": direction["relationship"],
            "physical_state": direction["physical_state"],
            "psychological_state": direction["psychological_state"],
            "prosody": prosody,
            "stress_words": list(direction.get("stress_words", [])),
            "transition": str(direction.get("transition", "none")),
            "delivery_note": str(direction.get("delivery_note", "")),
            "manual_review": bool(direction.get("manual_review", False)),
            "direction_origin": origin,
            "backend_controls": {
                "melotts_speed_multiplier": _speed_multiplier(emotion, intensity, contract),
                "directly_applied": ["speed"],
                "human_or_listening_review_only": list(contract["backend_capabilities"]["openvoice_v2_melotts"]["not_directly_controlled"]),
            },
        })

    return {
        "version": 1,
        "design_source": "emotional_voice_direction_pass_30",
        "contract": "data/voice_direction_contract.json",
        "profiles": "data/emotional_voice_profiles.json",
        "rules": {
            "authored_text_only": True,
            "runtime_generation": False,
            "human_listening_review_required": True,
            "registry_is_direction_metadata_not_neural_training": True,
        },
        "entry_count": len(entries),
        "entries": entries,
    }


def render(registry: dict[str, Any]) -> str:
    return json.dumps(registry, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    expected = render(build_registry(ROOT))
    if args.check:
        if not output.is_file() or output.read_text(encoding="utf-8") != expected:
            raise SystemExit("voice direction registry is out of date")
        print(f"VOICE_DIRECTION_REGISTRY_OK: {build_registry(ROOT)['entry_count']} line(s)")
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(expected, encoding="utf-8")
    print(f"VOICE_DIRECTION_REGISTRY_WRITTEN: {build_registry(ROOT)['entry_count']} line(s) -> {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
