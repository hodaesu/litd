#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_HEROES = {
    "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
    "hero.marec", "hero.zeje", "hero.anouk",
}
ALLOWED_RELIABILITY = {"confirmed", "direct", "reported", "variable", "unreliable", "witnessed"}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_contextual_quest_ramifications(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    ram_path = root / "universe/lore/theatrical_contextual_quest_ramifications.json"
    source_path = root / "universe/lore/theatrical_contextual_quests.json"
    doc_path = root / "docs/LITD1_NEUF_QUETES_RAMIFICATIONS_V1.md"

    for path, label in [(ram_path, "registre des ramifications"), (source_path, "registre source"), (doc_path, "document narratif")]:
        if not path.is_file():
            return {"ok": False, "errors": [f"{label} absent: {path.relative_to(root)}"], "warnings": []}

    data = load(ram_path)
    source = load(source_path)
    doc = doc_path.read_text(encoding="utf-8")
    ramifications = data.get("ramifications", [])
    quests = source.get("quests", [])

    source_pairs: set[tuple[str, str]] = set()
    source_quest_ids: set[str] = set()
    for quest in quests:
        qid = str(quest.get("id", ""))
        source_quest_ids.add(qid)
        for choice in quest.get("choices", []):
            source_pairs.add((qid, str(choice.get("id", ""))))

    ram_pairs = [(str(item.get("quest_id", "")), str(item.get("choice_id", ""))) for item in ramifications]
    ram_pair_set = set(ram_pairs)

    if len(quests) != 9 or data.get("quest_count") != 9:
        errors.append(f"La couche doit couvrir 9 quêtes source, source={len(quests)}, déclaré={data.get('quest_count')}")
    if len(source_pairs) != 26:
        errors.append(f"Le registre source doit actuellement exposer 26 branches, trouvé {len(source_pairs)}")
    if data.get("choice_branch_count") != 26 or len(ramifications) != 26:
        errors.append(f"La couche doit contenir exactement 26 ramifications, trouvé {len(ramifications)}")
    if len(ram_pairs) != len(ram_pair_set):
        errors.append("Une paire quête/choix est dupliquée dans les ramifications")
    if ram_pair_set != source_pairs:
        missing = sorted(source_pairs - ram_pair_set)
        extra = sorted(ram_pair_set - source_pairs)
        errors.append(f"Couverture source/ramifications incorrecte; manquants={missing}, supplémentaires={extra}")

    core = data.get("core_rules", {})
    expected_true = {
        "ramifications_use_existing_systems",
        "each_choice_has_delayed_consequence",
        "rumor_is_not_automatic_truth",
        "hero_followups_are_conditional",
        "pre_litd1_connections_are_antecedents",
        "post_litd1_can_seed_future_games",
    }
    expected_false = {
        "new_universal_meter",
        "global_morality_score",
        "deaths_are_automatic_punishment",
        "economic_effects_are_numeric_balance_values",
        "migration_is_population_score",
        "remanence_can_cause_past_games",
        "complete_seven_order_inferred",
    }
    for key in expected_true:
        if core.get(key) is not True:
            errors.append(f"Garde-fou global {key} doit rester true")
    for key in expected_false:
        if core.get(key) is not False:
            errors.append(f"Garde-fou global {key} doit rester false")

    targets = set(map(str, data.get("existing_system_targets", [])))
    required_targets = {
        "CommunityRuntime", "SanctuaryState", "DecisionMemoryRuntime",
        "FieldMemoryRuntime", "RelationshipRuntime", "CampaignState", "Memorial",
    }
    if not required_targets.issubset(targets):
        errors.append(f"Les ramifications doivent réutiliser les systèmes existants; absents={sorted(required_targets-targets)}")

    hero_union: set[str] = set()
    death_branches = 0
    migration_economy_branches = 0
    reliability_seen: set[str] = set()
    for item in ramifications:
        pair = (str(item.get("quest_id", "")), str(item.get("choice_id", "")))
        label = f"{pair[0]} / {pair[1]}"
        if int(item.get("delayed_event_count_min", 0)) < 1:
            errors.append(f"Aucun événement différé garanti pour {label}")
        if int(item.get("rumor_count_min", 0)) < 1:
            errors.append(f"Aucune rumeur différée garantie pour {label}")
        rel = set(map(str, item.get("rumor_reliability", [])))
        reliability_seen |= rel
        if not rel or not rel.issubset(ALLOWED_RELIABILITY):
            errors.append(f"Fiabilité de rumeur invalide pour {label}: {sorted(rel)}")
        if item.get("physical_world_change") is not True:
            errors.append(f"Le monde physique doit changer pour {label}")
        if item.get("migration_or_economic_consequence") is True:
            migration_economy_branches += 1
        elif item.get("migration_or_economic_consequence") is not False:
            errors.append(f"Le marqueur migration/économie doit être booléen pour {label}")
        if item.get("hero_dialogue_conditional") is not True:
            errors.append(f"Les dialogues de héros doivent rester conditionnels pour {label}")
        heroes = set(map(str, item.get("hero_followups", [])))
        hero_union |= heroes
        if not heroes:
            errors.append(f"Aucun suivi de héros défini pour {label}")
        if not heroes.issubset(EXPECTED_HEROES):
            errors.append(f"Héros inconnu dans {label}: {sorted(heroes-EXPECTED_HEROES)}")
        if item.get("possible_death") is True:
            death_branches += 1
            if item.get("death_is_automatic") is not False:
                errors.append(f"Une mort possible ne doit jamais être automatique: {label}")
        elif item.get("death_is_automatic") is not False:
            errors.append(f"death_is_automatic doit rester false pour {label}")
        rem = item.get("remanence", {})
        if rem.get("pre_litd1_role") != "antecedent_only":
            errors.append(f"La connexion au passé doit rester un antécédent pour {label}")
        if rem.get("future_target") != "post_litd1":
            errors.append(f"La Rémanence d'un choix LITD1 doit viser l'après-LITD1 pour {label}")
        if rem.get("backward_causation") is not False:
            errors.append(f"Causalité rétroactive interdite pour {label}")
        detail = root / str(item.get("detail_document", ""))
        if not detail.is_file():
            errors.append(f"Document de détail absent pour {label}: {item.get('detail_document')}")

    if hero_union != EXPECTED_HEROES:
        errors.append(f"Les sept héros doivent être représentés conditionnellement; manquants={sorted(EXPECTED_HEROES-hero_union)}")
    if death_branches < 1:
        errors.append("Aucune branche ne matérialise encore les morts contextuelles")
    if migration_economy_branches < 15:
        errors.append("Les effets de migration/économie doivent couvrir largement le cycle sans être forcés partout")
    if len(reliability_seen) < 4:
        errors.append("Les rumeurs doivent montrer plusieurs degrés de fiabilité")

    source_by_id = {str(q.get("id")): q for q in quests}
    saen_choices = {str(c.get("id")) for c in source_by_id.get("quest.litd1.saen_ask_before_pulling", {}).get("choices", [])}
    if saen_choices != {"cut_anchor_and_detour", "low_pulses_public_stop_threshold"}:
        errors.append("La passe ne doit pas réintroduire l'action invasive interdite sur Saen")

    lysandra_pairs = {choice for quest, choice in ram_pair_set if quest == "quest.litd1.lysandra_what_miracle_proves"}
    if lysandra_pairs != {"publish_observations_only", "archive_observation_and_testimony_separately", "delay_public_statement"}:
        errors.append("Les trois branches de Lysandra doivent être couvertes exactement")
    zeje_pairs = {choice for quest, choice in ram_pair_set if quest == "quest.litd1.zeje_three_versions_same_dead"}
    if not {"assign_most_probable_identity", "preserve_unknown_distribute_objects"}.issubset(zeje_pairs):
        errors.append("Les ramifications doivent préserver PROBABLE et INCONNU chez Zejé")
    effrie_pairs = {choice for quest, choice in ram_pair_set if quest == "quest.litd1.effrie_not_ours"}
    if effrie_pairs != {"leave_object_document_site", "minimal_sample_after_mapping", "remove_object_for_human_need"}:
        errors.append("Les trois branches d'Èffrie doivent rester celles du canon source")

    required_doc_phrases = [
        "aucune jauge supplémentaire",
        "ne peuvent donc jamais expliquer rétroactivement",
        "PROBABLE",
        "INCONNU",
        "Saen",
        "cicatrice reste irrégulière",
        "Vharren",
        "Pacte ancestral",
    ]
    for phrase in required_doc_phrases:
        if phrase not in doc:
            errors.append(f"Le document de ramifications doit conserver le garde-fou: {phrase}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "quests": len(source_quest_ids),
            "source_choices": len(source_pairs),
            "ramifications": len(ramifications),
            "possible_death_branches": death_branches,
            "migration_economy_branches": migration_economy_branches,
            "heroes_represented": sorted(hero_union),
            "rumor_reliability_values": sorted(reliability_seen),
        },
    }


if __name__ == "__main__":
    report = audit_contextual_quest_ramifications(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
