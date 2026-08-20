#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.voice.build_voice_direction_registry import build_registry as build_emotional_registry

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/voice_acting_contract.json"
OVERRIDES = ROOT / "data/dramatic_voice_overrides.json"


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _line_meta(root: Path) -> dict[str, dict[str, Any]]:
    reactive = _load(root / "data/reactive_dialogues.json")
    demo = _load(root / "data/demo_content_pack.json")
    result: dict[str, dict[str, Any]] = {}
    for raw in reactive.get("lines", []):
        if not isinstance(raw, dict):
            continue
        line_id = str(raw.get("id", ""))
        if line_id:
            result[line_id] = {
                "source": "data/reactive_dialogues.json",
                "priority": int(raw.get("priority", 0)),
                "fourth_wall": bool(raw.get("fourth_wall", False)),
                "meta_level": str(raw.get("meta_level", "")),
            }
    for raw in demo.get("dialogue_barks", []):
        if not isinstance(raw, dict):
            continue
        line_id = str(raw.get("id", ""))
        if line_id:
            result[line_id] = {
                "source": "data/demo_content_pack.json#dialogue_barks",
                "priority": 5,
                "fourth_wall": False,
                "meta_level": "",
            }
    return result


def _important(entry: dict[str, Any], meta: dict[str, Any], contract: dict[str, Any]) -> bool:
    cfg = contract["importance"]
    if cfg.get("demo_barks") and "demo_content_pack" in str(meta.get("source", "")):
        return True
    if int(entry.get("intensity", 0)) >= int(cfg.get("intensity_at_least", 4)):
        return True
    return str(meta.get("meta_level", "")) in set(cfg.get("fourth_wall_levels", []))


def _default_contradiction(emotion: str) -> str:
    mapping = {
        "fear_restrained": "peur réelle contre besoin de rester fonctionnel",
        "fear_panic": "urgence physique contre besoin de rester intelligible",
        "anger_cold": "colère contre refus de perdre le contrôle",
        "anger_explosive": "impulsion de rupture contre retour nécessaire à l'action",
        "grief": "perte intime contre nécessité de continuer",
        "despair_calm": "épuisement contre volonté de nommer encore le réel",
        "hope_fragile": "possibilité de croire contre peur d'être déçu",
        "dissociation": "distance protectrice contre présence humaine encore active",
        "madness_lucid": "perception altérée contre logique intérieure précise",
        "determination": "résolution affichée contre vulnérabilité tenue hors champ",
        "irony_dark": "détachement verbal contre implication réelle",
        "pain_controlled": "douleur contre volonté de rester utile",
        "shock": "sidération contre besoin de comprendre",
        "curiosity_wary": "désir de savoir contre peur du prix de la réponse",
    }
    return mapping.get(emotion, "texte explicite contre besoin intérieur plus complexe")


def _beats(*, important: bool, fourth_wall: bool, meta_level: str, action: str) -> list[dict[str, Any]]:
    if fourth_wall and meta_level in {"direct", "abyssal"}:
        return [
            {"start": 0.0, "end": 0.34, "intention": f"commencer dans l'action {action} sans signaler l'étrangeté"},
            {"start": 0.34, "end": 0.70, "intention": "laisser la prise de conscience modifier la pensée avant la voix", "awareness_shift": True},
            {"start": 0.70, "end": 1.0, "intention": "adresser la présence extérieure avec retenue et précision"},
        ]
    if important:
        return [
            {"start": 0.0, "end": 0.38, "intention": f"engager l'action {action}"},
            {"start": 0.38, "end": 0.74, "intention": "recevoir la contradiction ou le coût de ce qui est dit"},
            {"start": 0.74, "end": 1.0, "intention": "terminer avec une intention modifiée, pas une émotion ajoutée"},
        ]
    return [
        {"start": 0.0, "end": 0.55, "intention": f"poursuivre l'action {action}"},
        {"start": 0.55, "end": 1.0, "intention": "adapter l'action à ce qui vient d'être compris"},
    ]


def _variants(direction: dict[str, Any], important: bool, contract: dict[str, Any], meta_level: str) -> list[dict[str, Any]]:
    if not important:
        return []
    templates = contract["variant_templates"]
    result: list[dict[str, Any]] = []
    for variant_id in ("contained_truth", "exposed_fissure"):
        template = dict(templates[variant_id])
        result.append({
            "id": variant_id,
            "playable_action": direction["action"],
            "speed_multiplier": float(template["speed_multiplier"]),
            "restraint": template["restraint"],
            "volume_rule": template["volume_rule"],
            "beat_focus": template["beat_focus"],
            "note": "Changer l'intention ou le degré d'exposition, jamais imiter une autre personne.",
        })
    if meta_level == "abyssal" or int(direction.get("intensity", 0)) >= 5:
        template = dict(templates["silence_forward"])
        result.append({
            "id": "silence_forward",
            "playable_action": "observer",
            "speed_multiplier": float(template["speed_multiplier"]),
            "restraint": template["restraint"],
            "volume_rule": template["volume_rule"],
            "beat_focus": template["beat_focus"],
            "note": "La pensée avant et après la phrase doit porter davantage que l'effet vocal.",
        })
    return result


def _validate_beats(line_id: str, beats: list[dict[str, Any]]) -> None:
    if not beats:
        raise ValueError(f"{line_id}: missing beats")
    if float(beats[0].get("start", -1)) != 0.0 or float(beats[-1].get("end", -1)) != 1.0:
        raise ValueError(f"{line_id}: beats must cover 0..1")
    previous_end = 0.0
    for beat in beats:
        start = float(beat.get("start", -1))
        end = float(beat.get("end", -1))
        if abs(start - previous_end) > 0.0001 or end <= start:
            raise ValueError(f"{line_id}: beats must be contiguous and increasing")
        previous_end = end


def build_registry(root: Path = ROOT) -> dict[str, Any]:
    contract = _load(root / "data/voice_acting_contract.json")
    overrides = _load(root / "data/dramatic_voice_overrides.json").get("overrides", {})
    emotional = build_emotional_registry(root)
    meta_by_id = _line_meta(root)
    entries: list[dict[str, Any]] = []

    for emotional_entry in emotional.get("entries", []):
        line_id = str(emotional_entry["line_id"])
        meta = dict(meta_by_id.get(line_id, {}))
        context = str(emotional_entry.get("context", ""))
        default = dict(contract["event_defaults"].get(context, contract["event_defaults"]["default"]))
        explicit = overrides.get(line_id)
        if isinstance(explicit, dict):
            default.update(explicit)
        important = _important(emotional_entry, meta, contract)
        default["intensity"] = int(emotional_entry.get("intensity", 2))
        default["emotion"] = str(emotional_entry.get("emotion", "neutral_grounded"))
        default["contradiction"] = str(default.get("contradiction") or _default_contradiction(default["emotion"]))
        default["beats"] = list(default.get("beats") or _beats(
            important=important,
            fourth_wall=bool(meta.get("fourth_wall", False)),
            meta_level=str(meta.get("meta_level", "")),
            action=str(default["action"]),
        ))
        _validate_beats(line_id, default["beats"])
        if bool(meta.get("fourth_wall", False)) and str(meta.get("meta_level", "")) in {"direct", "abyssal"}:
            if not any(bool(beat.get("awareness_shift", False)) for beat in default["beats"]):
                raise ValueError(f"{line_id}: direct/abyssal fourth-wall line needs an awareness-shift beat")

        variants = _variants(default, important, contract, str(meta.get("meta_level", "")))
        if important and len(variants) < 2:
            raise ValueError(f"{line_id}: important line needs at least two interpretations")

        required = [
            "objective", "obstacle", "action", "subtext", "listener", "power_start", "power_end",
            "preceding_thought", "listening_trigger", "silence", "breath", "post_line_state"
        ]
        missing = [key for key in required if not str(default.get(key, "")).strip()]
        if missing:
            raise ValueError(f"{line_id}: missing dramatic fields: {', '.join(missing)}")
        if str(default["action"]) not in set(contract["action_lexicon"]):
            raise ValueError(f"{line_id}: action is not playable/registered: {default['action']}")

        entries.append({
            "line_id": line_id,
            "speaker_id": emotional_entry["speaker_id"],
            "context": context,
            "text": emotional_entry["text"],
            "source": emotional_entry["source"],
            "emotion": default["emotion"],
            "intensity": default["intensity"],
            "important": important,
            "fourth_wall": bool(meta.get("fourth_wall", False)),
            "meta_level": str(meta.get("meta_level", "")),
            "objective": default["objective"],
            "obstacle": default["obstacle"],
            "action": default["action"],
            "subtext": default["subtext"],
            "listener": default["listener"],
            "power": {"start": default["power_start"], "end": default["power_end"]},
            "preceding_thought": default["preceding_thought"],
            "listening_trigger": default["listening_trigger"],
            "silence": default["silence"],
            "breath": default["breath"],
            "beats": default["beats"],
            "contradiction": default["contradiction"],
            "post_line_state": default["post_line_state"],
            "variants": variants,
            "performance_rule": "Jouer l'objectif et l'action; laisser l'émotion apparaître comme conséquence de l'écoute, du sous-texte et des beats.",
            "human_review_required": important or bool(emotional_entry.get("manual_review", False)),
            "direction_origin": "explicit_override" if isinstance(explicit, dict) else "event_default",
        })

    return {
        "version": 1,
        "design_source": "dramatic_voice_direction_pass_31",
        "contract": "data/voice_acting_contract.json",
        "study_protocol": "data/voice_acting_study_protocol.json",
        "rules": contract["rules"],
        "entry_count": len(entries),
        "important_count": sum(1 for item in entries if item["important"]),
        "entries": sorted(entries, key=lambda item: str(item["line_id"])),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build LITD dramatic voice direction metadata")
    parser.add_argument("--output", default="reports/voice-dramatic-registry.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    payload = build_registry(ROOT)
    if args.check:
        print(f"DRAMATIC_VOICE_DIRECTION_OK: {payload['entry_count']} line(s), {payload['important_count']} important")
        return 0
    out = Path(args.output)
    if not out.is_absolute():
        out = ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"DRAMATIC_VOICE_DIRECTION_WRITTEN: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
