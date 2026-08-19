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
    folklore = json.loads((root / "data/global_folklore_atlas.json").read_text(encoding="utf-8"))
    community = json.loads((root / "data/community_network.json").read_text(encoding="utf-8"))
    chapter3 = json.loads((root / "data/levels/chapter_03_world.json").read_text(encoding="utf-8"))
    runtime = (root / "scripts/core/narrative_library.gd").read_text(encoding="utf-8")
    ui = (root / "scripts/ui/main_v22.gd").read_text(encoding="utf-8")
    main_scene = (root / "scenes/Main.tscn").read_text(encoding="utf-8")
    project = (root / "project.godot").read_text(encoding="utf-8")
    guide = (root / "docs/design/narrative_library.md").read_text(encoding="utf-8")
    folklore_guide = (root / "docs/design/global_folklore_atlas.md").read_text(encoding="utf-8")
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

    check("Atlas folklore : schéma v1", int(folklore.get("version", 0)) >= 1)
    research_basis = [str(x) for x in folklore.get("research_basis", [])]
    check("Atlas folklore : ATU documenté", any("Aarne-Thompson-Uther" in x for x in research_basis))
    check("Atlas folklore : Motif-Index documenté", any("Motif-Index" in x for x in research_basis))
    check("Atlas folklore : UNESCO documenté", any("UNESCO" in x for x in research_basis))
    check("Atlas folklore : World Oral Literature documenté", any("World Oral Literature" in x for x in research_basis))
    check("Atlas folklore : Library of Congress documentée", any("Library of Congress" in x for x in research_basis))

    regions = [item for item in folklore.get("regions", []) if isinstance(item, dict)]
    region_ids = {str(item.get("id", "")) for item in regions}
    check("Atlas folklore : couverture mondiale d'au moins vingt-huit ensembles", len(regions) >= 28, str(len(regions)))
    required_regions = {
        "west_africa", "central_africa", "east_africa_horn", "southern_africa", "north_africa_amazigh",
        "middle_east_persian_turkic", "caucasus", "central_asia_siberia", "south_asia", "himalaya_tibet",
        "china", "japan_ainu_ryukyu", "korea", "mainland_southeast_asia", "maritime_southeast_asia",
        "oceania", "indigenous_australia", "celtic_atlantic", "nordic_germanic_alpine", "slavic_baltic_finnic",
        "balkans_mediterranean", "western_southern_europe", "jewish_diaspora", "indigenous_north_america",
        "arctic_circumpolar", "african_american_appalachian", "mesoamerica_central_america", "caribbean",
        "andes_amazonia", "brazil", "southern_cone", "contemporary_global_legends",
    }
    check("Atlas folklore : grands ensembles présents", required_regions <= region_ids, ", ".join(sorted(required_regions - region_ids)))

    clusters: list[str] = []
    access_values: set[str] = set()
    for region in regions:
        access_values.add(str(region.get("access", "")))
        values = region.get("reference_clusters", [])
        if isinstance(values, list):
            clusters.extend(str(value) for value in values if str(value).strip())
    check("Atlas folklore : au moins deux cents clusters de référence", len(clusters) >= 200, str(len(clusters)))
    check("Atlas folklore : diversité des niveaux d'accès", {"public_reference", "living_sensitive", "community_review_required"} <= access_values)
    check("Atlas folklore : au moins vingt-cinq formes narratives", len(folklore.get("narrative_forms", [])) >= 25)
    check("Atlas folklore : au moins quarante familles de motifs", len(folklore.get("motif_families", [])) >= 40)

    cultural = folklore.get("cultural_protocol", {}) if isinstance(folklore.get("cultural_protocol", {}), dict) else {}
    access_levels = cultural.get("access_levels", {}) if isinstance(cultural.get("access_levels", {}), dict) else {}
    check("Atlas folklore : quatre niveaux d'accès définis", {"public_reference", "living_sensitive", "community_review_required", "restricted_do_not_adapt"} <= set(access_levels.keys()))
    forbidden = [str(x).lower() for x in cultural.get("forbidden", [])]
    required = [str(x).lower() for x in cultural.get("required", [])]
    check("Atlas folklore : interdit la fusion pan-autochtone", any("fusionner" in x and "autocht" in x for x in forbidden))
    check("Atlas folklore : interdit le contenu restreint", any("restreint" in x for x in forbidden))
    check("Atlas folklore : exige attribution culturelle", any("origine culturelle" in x for x in required))
    check("Atlas folklore : règles d'extraction fortes", len(folklore.get("design_extraction_rules", [])) >= 7)

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
    for token in ["folklore_regions", "folklore_region", "folklore_reference_clusters", "folklore_access_level", "folklore_cultural_protocol", "folklore_design_rules", "folklore_coverage"]:
        check(f"Runtime folklore : {token}", f"func {token}" in runtime)
    check("Runtime folklore : atlas chargé séparément", "FOLKLORE_PATH" in runtime and "folklore_data" in runtime)
    check("Runtime bibliothèque : pas de score moral", "ProgressBar" not in runtime and "morality" not in runtime.lower())
    check("UI v22 : récit selon l'état", "NarrativeLibrary.quest_state_text" in ui)
    check("UI v22 : recontextualisation après accomplissement", "NarrativeLibrary.quest_reframe" in ui)
    check("UI v22 : accepter l'histoire", "ACCEPTER L'HISTOIRE" in ui)
    check("Main : v22 actif", 'res://scripts/ui/main_v22.gd' in main_scene and 'script = ExtResource("1")' in main_scene)
    check("Projet : NarrativeLibrary autoload", 'NarrativeLibrary="*res://scripts/core/narrative_library.gd"' in project)
    check("Documentation : bibliothèque anti-plagiat", "Si une quête peut être résumée" in guide and "elle échoue" in guide)
    check("Documentation : atlas mondial et respect culturel", "Niveaux d'accès culturel" in folklore_guide and "revue culturelle" in folklore_guide)
    check("Documentation : atlas refuse la transposition de conte", "noms changés" in folklore_guide)
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
