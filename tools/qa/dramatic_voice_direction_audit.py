#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from tools.voice.build_dramatic_voice_registry import build_registry
from tools.voice.build_voice_performance_plan import build_performance_plan

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def run() -> dict:
    contract = _load("data/voice_acting_contract.json")
    study = _load("data/voice_acting_study_protocol.json")
    overrides = _load("data/dramatic_voice_overrides.json").get("overrides", {})
    registry = build_registry(ROOT)
    performance = build_performance_plan(ROOT)
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    rules = contract.get("rules", {})
    check("Jeu : émotion conséquence", rules.get("emotion_is_consequence_not_primary_objective") is True)
    check("Jeu : écoute avant réponse", rules.get("active_listening_precedes_reply") is True)
    check("Jeu : émotion forte != volume fort", rules.get("high_emotion_does_not_imply_high_volume") is True)
    check("Jeu : variantes importantes", rules.get("important_lines_have_at_least_two_variants") is True)
    check("Éthique : aucune imitation acteur", rules.get("no_real_actor_imitation") is True)
    check("Copyright : pas de transcription de film", rules.get("no_copyrighted_dialogue_transcripts_in_calibration") is True)
    check("Étude : observations uniquement", study["copyright_and_ethics"].get("extract_transferable_observations_only") is True)
    check("Étude : aucun clip stocké", study["copyright_and_ethics"].get("store_full_clip") is False)
    check("Étude : aucun transcript stocké", study["copyright_and_ethics"].get("store_transcript") is False)

    entries = registry.get("entries", [])
    check("Registre : lignes présentes", len(entries) >= 45, str(len(entries)))
    required = ["objective", "obstacle", "action", "subtext", "listener", "preceding_thought", "listening_trigger", "silence", "breath", "beats", "contradiction", "post_line_state"]
    check("Registre : champs dramatiques complets", all(all(item.get(key) for key in required) for item in entries))
    important = [item for item in entries if item.get("important")]
    check("Registre : lignes importantes détectées", len(important) >= 12, str(len(important)))
    check("Registre : >=2 variantes importantes", all(len(item.get("variants", [])) >= 2 for item in important))
    meta_lines = [item for item in entries if item.get("fourth_wall") and item.get("meta_level") in {"direct", "abyssal"}]
    check("Quatrième mur : lignes directes/abyssales présentes", bool(meta_lines), str(len(meta_lines)))
    check("Quatrième mur : prise de conscience beatée", all(any(beat.get("awareness_shift") is True for beat in item["beats"]) for item in meta_lines))
    check("Overrides : Darius direct", "fw_dar_direct_02" in overrides)
    check("Overrides : Darius abyssal", "fw_dar_abyss_02" in overrides)
    check("Overrides : Goule démo", "demo_darius_ghoul_01" in overrides)
    by_id = {item["line_id"]: item for item in entries}
    check("Overrides : origine explicite conservée", all(by_id[line_id]["direction_origin"] == "explicit_override" for line_id in overrides if line_id in by_id))

    perf_entries = performance.get("entries", [])
    check("Plan production : direction dramatique active", performance.get("dramatic_direction", {}).get("enabled") is True)
    check("Plan production : chaque ligne rendue dirigée", all("acting_direction" in item for item in perf_entries))
    check("Plan production : variantes importantes disponibles", all(len(item.get("interpretation_variants", [])) >= 2 for item in perf_entries if item["acting_direction"]["important"]))
    check("Plan production : vérité backend", performance.get("dramatic_direction", {}).get("no_claim_of_neural_retraining") is True)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run()
    out = ROOT / "reports" / "dramatic-voice-direction-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
