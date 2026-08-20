#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from tools.voice.build_voice_direction_registry import build_registry
from tools.voice.openvoice_v2_pipeline import build_plan
from tools.voice.voice_take_review import validate as validate_calibration

ROOT = Path(__file__).resolve().parents[2]
HEROES = {"aurelien", "malvor", "lysandra", "darius"}
REQUIRED_PROSODY = {"pace", "pitch_bias", "pitch_range", "volume", "breath", "articulation", "pause_profile", "ending_cadence", "tension", "anti_caricature"}
KEY_EMOTIONS = {"neutral_grounded", "fear_restrained", "fear_panic", "anger_cold", "anger_explosive", "despair_calm", "hope_fragile", "grief", "dissociation", "madness_lucid", "determination", "threat_calm", "pain_controlled", "curiosity_wary"}


def _load(path: str, root: Path = ROOT):
    return json.loads((root / path).read_text(encoding="utf-8"))


def run(root: Path = ROOT) -> dict:
    contract = _load("data/voice_direction_contract.json", root)
    profiles = _load("data/emotional_voice_profiles.json", root)
    overrides = _load("data/voice_direction_overrides.json", root)
    calibration = _load("data/voice_emotion_calibration.json", root)
    demo = _load("data/demo_content_pack.json", root)
    production = _load("data/voice_production.json", root)
    registry = build_registry(root)
    plan = build_plan(root)
    pipeline = (root / "tools/voice/openvoice_v2_pipeline.py").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    emotions = contract.get("emotions", {})
    check("Contrat : version 1", contract.get("version") == 1)
    check("Contrat : émotions clés couvertes", KEY_EMOTIONS <= set(emotions), str(sorted(KEY_EMOTIONS - set(emotions))))
    check("Contrat : prosodie complète", all(REQUIRED_PROSODY <= set(spec) for spec in emotions.values()))
    check("Contrat : intensités 1 à 5", set(contract.get("intensity_scale", {})) == {"1", "2", "3", "4", "5"})
    check("Contrat : intensité 5 revue manuelle", contract.get("rules", {}).get("intensity_5_requires_manual_review") is True)
    check("Contrat : identité avant émotion", contract.get("rules", {}).get("preserve_character_identity_over_emotion") is True)
    check("Contrat : aucun réentraînement prétendu", contract.get("rules", {}).get("direction_is_project_calibration_not_model_weight_training") is True)

    profile_ids = set(profiles.get("profiles", {}))
    check("Profils : quatre héros", HEROES <= profile_ids, str(sorted(HEROES - profile_ids)))
    check("Profils : narration prévue", "narration" in profile_ids)
    check("Profils : calibration marquée provisoire", all("calibration_status" in profiles["profiles"][hero] for hero in HEROES))

    entries = registry.get("entries", [])
    by_id = {entry["line_id"]: entry for entry in entries}
    reactive = _load("data/reactive_dialogues.json", root)
    expected_ids = {item["id"] for item in reactive.get("lines", [])} | {item["id"] for item in demo.get("dialogue_barks", [])}
    check("Registre : toutes les lignes écrites couvertes", set(by_id) == expected_ids, f"{len(by_id)}/{len(expected_ids)}")
    check("Registre : aucun ID dupliqué", len(by_id) == len(entries))
    check("Registre : émotions valides", all(entry.get("emotion") in emotions for entry in entries))
    check("Registre : intensités valides", all(int(entry.get("intensity", 0)) in range(1, 6) for entry in entries))
    check("Registre : intensité 5 manuelle", all(entry.get("manual_review") is True for entry in entries if int(entry.get("intensity", 0)) == 5))
    check("Registre : OpenVoice applique seulement speed", all(entry.get("backend_controls", {}).get("directly_applied") == ["speed"] for entry in entries))

    demo_ids = {item["id"] for item in demo.get("dialogue_barks", [])}
    explicit_ids = set(overrides.get("overrides", {}))
    check("Démo : toutes les répliques dirigées explicitement", demo_ids <= explicit_ids, str(sorted(demo_ids - explicit_ids)))
    check("Démo : directions explicites produites", all(by_id[line_id].get("direction_origin") == "explicit_override" for line_id in demo_ids))

    calibration_errors = validate_calibration(root)
    check("Calibration : corpus valide", not calibration_errors, "; ".join(calibration_errors))
    calibration_emotions = {item.get("emotion") for item in calibration.get("samples", [])}
    check("Calibration : émotions clés représentées", KEY_EMOTIONS <= calibration_emotions, str(sorted(KEY_EMOTIONS - calibration_emotions)))
    check("Calibration : au moins vingt prises étalons", len(calibration.get("samples", [])) >= 20, str(len(calibration.get("samples", []))))

    rules = production.get("rules", {})
    check("Droits : consentement toujours requis", rules.get("explicit_consent_record_required") is True)
    check("Droits : original ou autorisé", rules.get("reference_voice_must_be_original_or_authorized") is True)
    check("Droits : imitation célébrité interdite", rules.get("celebrity_or_actor_imitation_forbidden") is True)
    check("Runtime : aucune génération", rules.get("runtime_generation_in_game") is False and registry.get("rules", {}).get("runtime_generation") is False)
    check("Pipeline : direction émotionnelle embarquée", plan.get("emotional_direction", {}).get("enabled") is True and all("voice_direction" in item for item in plan.get("entries", [])))
    check("Pipeline : répliques démo mortelles ajoutées", all(any(item["line_id"] == line_id for item in plan["entries"]) for line_id in demo_ids if by_id[line_id]["speaker_id"] in HEROES))
    check("Pipeline : limites backend explicites", "all_other_prosody" in json.dumps(plan.get("emotional_direction", {})) and "directly_controlled" in json.dumps(contract.get("backend_capabilities", {})))
    for token in ["build_registry", "emotional_speed", "voice_direction", "emotional_direction_review_required"]:
        check("Pipeline : " + token, token in pipeline)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "voice-direction-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
