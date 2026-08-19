#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_QUEST_FIELDS = {
    "theme",
    "dramatic_question",
    "hook",
    "active",
    "reframe",
    "resolution",
    "aftermath_seed",
    "devices",
}


def run(root: Path = ROOT) -> dict:
    library = json.loads((root / "data/narrative_library.json").read_text(encoding="utf-8"))
    community = json.loads((root / "data/community_network.json").read_text(encoding="utf-8"))
    chapter3 = json.loads((root / "data/levels/chapter_03_world.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/narrative_library.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v22.gd").read_text(encoding="utf-8")
    main_scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    guide = (root / "docs/design/narrative_library.md").read_text(encoding="utf-8")
    standard = (root / "docs/design/sidequest_narrative_standard.md").read_text(encoding="utf-8")

    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Bibliothèque narrative : schéma v1", int(library.get("version", 0)) >= 1)
    originality = library.get("originality_protocol", {})
    check("Originalité : interdictions explicites", len(originality.get("forbidden", [])) >= 5)
    check("Originalité : protocole de synthèse", len(originality.get("required", [])) >= 5)
    check("Originalité : test de distance", any("test de distance" in str(x).lower() for x in originality.get("required", [])))

    axes = library.get("quality_axes", [])
    check("Qualité narrative : au moins dix axes", len(axes) >= 10)
    axis_ids = {str(item.get("id", "")) for item in axes if isinstance(item, dict)}
    check("Qualité narrative : enjeu humain", "human_stake" in axis_ids)
    check("Qualité narrative : recontextualisation", "reframing" in axis_ids)
    check("Qualité narrative : conséquence", "aftermath" in axis_ids)
    check("Qualité narrative : originalité", "originality" in axis_ids)

    devices = {str(item.get("id", "")): item for item in library.get("narrative_devices", []) if isinstance(item, dict)}
    check("Bibliothèque narrative : au moins vingt-cinq mécanismes", len(devices) >= 25)
    for device_id in [
        "reversal", "recognition", "moral_luck", "narrative_identity",
        "ambiguous_supernatural", "clue_reframe", "trickster_inversion",
        "jo_ha_kyu", "subtext_duel", "story_as_reward", "choice_echo",
    ]:
        check(f"Mécanisme narratif : {device_id}", device_id in devices)

    families = library.get("corpus_families", [])
    check("Corpus : au moins douze familles transmédiatiques", len(families) >= 12)
    family_ids = {str(item.get("id", "")) for item in families if isinstance(item, dict)}
    for family_id in [
        "ancient_epic_and_myth", "folklore_worldwide", "fantasy_literature",
        "heroic_dark_fantasy_cinema", "modern_theatre",
        "psychological_and_philosophical_novels", "gothic_horror_fantastique",
        "mystery_noir_crime", "interactive_quest_design",
    ]:
        check(f"Corpus : {family_id}", family_id in family_ids)

    evidence_ids = {str(item.get("id", "")) for item in chapter3.get("evidence", []) if isinstance(item, dict)}
    reference_titles: set[str] = set()
    for family in families:
        if not isinstance(family, dict):
            continue
        for title in family.get("reference_examples", []):
            title_text = str(title).strip().lower()
            if len(title_text) >= 8:
                reference_titles.add(title_text)

    quests = community.get("quests", [])
    check("Quêtes secondaires : au moins deux récits émergents", len(quests) >= 2)
    for quest in quests:
        if not isinstance(quest, dict):
            continue
        quest_id = str(quest.get("id", ""))
        narrative = quest.get("narrative", {}) if isinstance(quest.get("narrative", {}), dict) else {}
        missing = sorted(REQUIRED_QUEST_FIELDS - set(narrative.keys()))
        check(f"Quête {quest_id} : contrat narratif complet", not missing, ", ".join(missing))
        used = [str(value) for value in narrative.get("devices", [])]
        check(f"Quête {quest_id} : synthèse de trois mécanismes minimum", len(set(used)) >= 3)
        check(f"Quête {quest_id} : mécanismes connus", all(value in devices for value in used))
        used_families = {str(devices[value].get("family", "")) for value in used if value in devices}
        check(f"Quête {quest_id} : trois familles narratives distinctes", len(used_families) >= 3)
        objective = quest.get("objective", {}) if isinstance(quest.get("objective", {}), dict) else {}
        if str(objective.get("type", "")) == "chapter03_evidence":
            check(f"Quête {quest_id} : objectif réellement présent dans le chapitre III", str(objective.get("id", "")) in evidence_ids)
        joined = " ".join(str(narrative.get(key, "")) for key in REQUIRED_QUEST_FIELDS if key != "devices").lower()
        copied_reference = sorted(title for title in reference_titles if title in joined)
        check(f"Quête {quest_id} : aucune référence d'œuvre injectée dans le texte", not copied_reference, ", ".join(copied_reference[:3]))
        check(f"Quête {quest_id} : question dramatique substantielle", len(str(narrative.get("dramatic_question", ""))) >= 80)
        check(f"Quête {quest_id} : recontextualisation substantielle", len(str(narrative.get("reframe", ""))) >= 100)
        check(f"Quête {quest_id} : après-coup préparé", len(str(narrative.get("aftermath_seed", ""))) >= 100)

    for token in ["quest_state_text", "quest_reframe", "quest_dramatic_question", "quest_devices", "originality_rules"]:
        check(f"Runtime bibliothèque : {token}", f"func {token}" in runtime)
    check("Runtime bibliothèque : pas de score moral", "ProgressBar" not in runtime and "morality" not in runtime.lower())
    check("UI v22 : récit selon l'état", "NarrativeLibrary.quest_state_text" in ui)
    check("UI v22 : recontextualisation après accomplissement", "NarrativeLibrary.quest_reframe" in ui)
    check("UI v22 : accepter l'histoire", "ACCEPTER L'HISTOIRE" in ui)
    check("Main : v22 actif", 'res://scripts/ui/main_v22.gd' in main_scene and 'script = ExtResource("1")' in main_scene)
    check("Projet : NarrativeLibrary autoload", 'NarrativeLibrary="*res://scripts/core/narrative_library.gd"' in project)
    check("Documentation : bibliothèque anti-plagiat", "Si une quête peut être résumée" in guide and "elle échoue" in guide)
    check("Documentation : standard secondaire égal à la campagne", "même niveau" in standard.lower())
    check("Documentation : histoire valable sans loot", "retire l'or, l'XP et le loot" in standard)

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "narrative-library-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
