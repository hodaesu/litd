#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(root: Path = ROOT) -> dict:
    dialogues = json.loads((root / "data/reactive_dialogues.json").read_text(encoding="utf-8"))
    profiles = json.loads((root / "data/voice_profiles.json").read_text(encoding="utf-8"))
    heroes = json.loads((root / "data/heroes.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/dialogue_director.gd").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    smoke = (root / "scripts/core/dialogue_director_smoke_test.gd").read_text(encoding="utf-8")
    godot_ci = (root / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    hero_ids = {str(item.get("id", "")) for item in heroes if isinstance(item, dict)}
    profile_ids = {str(item.get("hero_id", "")) for item in profiles.get("profiles", []) if isinstance(item, dict)}
    check("Profils vocaux : tous les héros initiaux couverts", hero_ids <= profile_ids, ", ".join(sorted(hero_ids - profile_ids)))
    check("Profils vocaux : identité quatrième mur par héros", all("fourth_wall_style" in item for item in profiles.get("profiles", [])))

    rules = dialogues.get("rules", {})
    check("Mortalité : héros morts interdits de parole", rules.get("dead_speakers_forbidden") is True)
    check("Mortalité : récit critique indépendant des héros", rules.get("critical_story_never_depends_on_mortal_hero") is True)
    check("Mortalité : la mort retire la voix unique", rules.get("hero_death_removes_unique_voice") is True)
    check("Fallback : héros puis narration puis silence", rules.get("fallback_order") == ["specific_hero", "compatible_hero", "narration", "silence"])

    policy = dialogues.get("fourth_wall", {})
    check("Quatrième mur : maximum deux par expédition", 1 <= int(policy.get("max_per_expedition", 0)) <= 2)
    check("Quatrième mur : espacement long", int(policy.get("minimum_gap_events", 0)) >= 6)
    check("Quatrième mur : probabilité basse", float(policy.get("default_probability", 1.0)) <= 0.08)
    check("Quatrième mur : jamais information critique", policy.get("never_for_critical_story_information") is True)
    check("Quatrième mur : respecte le silence de mort", policy.get("never_replace_death_silence") is True)

    meta = [line for line in dialogues.get("lines", []) if isinstance(line, dict) and line.get("fourth_wall")]
    check("Quatrième mur : au moins dix répliques", len(meta) >= 10, str(len(meta)))
    check("Quatrième mur : trois intensités", {"fissure", "direct", "abyssal"} <= {str(line.get("meta_level", "")) for line in meta})
    check("Quatrième mur : quatre héros initiaux", hero_ids <= {str(line.get("speaker_id", "")) for line in meta})
    check("Quatrième mur : aucune réplique critique", all(str(line.get("event", "")) != "critical_story" for line in meta))

    for token in [
        "func request_line", "func request_and_log", "func voice_profile", "func _alive_hero",
        "func _fourth_wall_allowed", "func fourth_wall_state", "force_fourth_wall",
        "critical_story", "_used_line_ids"
    ]:
        check("Runtime DialogueDirector : " + token, token in runtime)
    check("Runtime : aucun héros mort comme fallback", 'int(hero.get("hp", 0)) > 0' in runtime)
    check("Projet : DialogueDirector autoload", 'DialogueDirector="*res://scripts/core/dialogue_director.gd"' in project)
    check("Smoke : mortalité", "A dead hero must never keep speaking" in smoke)
    check("Smoke : plafond quatrième mur", "third meta line" in smoke)
    check("Godot CI : smoke DialogueDirector", "dialogue_director_smoke.tscn" in godot_ci)

    return {"summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])}, "checks": checks}


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "dialogue-director-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
