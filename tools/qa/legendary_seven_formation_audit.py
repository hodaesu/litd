#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ORDER = [
    "hero.zeje", "hero.anouk", "hero.marec", "hero.mathilde",
    "hero.effrie", "hero.aurelien", "hero.lya",
]
BODY_FIELDS = {"event", "mechanical_change", "subjective_experience", "social_reaction", "persistent_consequence"}
REMANENCE_FIELDS = {"source", "transmission", "transformation"}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_legendary_seven_formation(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    formation_path = root / "universe/lore/legendary_seven_formation.json"
    relations_path = root / "universe/lore/legendary_seven_relationships.json"
    decisions_path = root / "docs/LITD1_DECISIONS_SEPT_TRAME_DRAGONS.md"
    doc_path = root / "docs/LITD1_FORMATION_DES_SEPT_EDITION_THEATRALE_V1.md"
    for path in [formation_path, relations_path, decisions_path, doc_path]:
        if not path.is_file():
            errors.append(f"Fichier requis absent: {path.relative_to(root)}")
    if errors:
        return {"ok": False, "errors": errors, "warnings": warnings, "summary": {}}

    data = load(formation_path)
    relations = load(relations_path)
    decisions = decisions_path.read_text(encoding="utf-8")
    doc = doc_path.read_text(encoding="utf-8")

    if data.get("formation_order") != EXPECTED_ORDER:
        errors.append(f"Ordre des Sept invalide: {data.get('formation_order')}")
    rules = data.get("rules", {})
    true_rules = [
        "formation_is_not_prophecy", "legendary_status_is_acquired_later",
        "recruitment_order_is_historical_not_mystical", "choices_change_costs_not_canonical_membership",
        "created_protagonist_posture_never_imposed", "no_hidden_good_choice",
        "no_new_relationship_meter", "body_consequences_are_persistent_when_documented",
        "observed_magic_effect_does_not_prove_cosmology", "dragon_activity_does_not_prove_pact_or_ancestry",
        "not_every_present_hero_comments", "remanence_points_forward_only",
    ]
    for key in true_rules:
        if rules.get(key) is not True:
            errors.append(f"Garde-fou manquant ou faux: {key}")
    if rules.get("backward_causation") is not False:
        errors.append("La formation ne doit produire aucune causalite retroactive")
    if int(rules.get("max_spoken_lines_first_camp", 99)) > 2:
        errors.append("Les premiers camps depassent le plafond de deux prises de parole")

    source = data.get("source_harmonization", {})
    if source.get("locked_before_this_pass", {}).get("rank_2") != "hero.anouk":
        errors.append("Anouk doit rester deuxieme")
    if source.get("preserved_library_fact", {}).get("rank_3") != "hero.marec":
        errors.append("Marec doit rester troisieme")
    if source.get("locked_before_this_pass", {}).get("rank_5") != "hero.effrie":
        errors.append("Effrie doit rester cinquieme")

    recruitments = data.get("recruitments", [])
    if len(recruitments) != 6:
        errors.append(f"Il faut exactement six recrutements apres Zeje, trouve {len(recruitments)}")
    by_rank = {int(r.get("rank", -1)): r for r in recruitments if isinstance(r, dict)}
    if set(by_rank) != set(range(2, 8)):
        errors.append(f"Les recrutements doivent couvrir exactement les rangs 2 a 7: {sorted(by_rank)}")

    canonical_pair_ids = {str(p.get("id")) for p in relations.get("pairs", []) if isinstance(p, dict)}
    seed_ids: list[str] = []
    seed_pair_members: set[frozenset[str]] = set()

    for rank in range(2, 8):
        rec = by_rank.get(rank, {})
        expected_joiner = EXPECTED_ORDER[rank - 1]
        expected_existing = EXPECTED_ORDER[:rank - 1]
        if rec.get("joining_hero") != expected_joiner:
            errors.append(f"Rang {rank}: nouvel arrivant invalide")
        if rec.get("existing_group") != expected_existing:
            errors.append(f"Rang {rank}: groupe precedent invalide")
        if not str(rec.get("human_question", "")).strip():
            errors.append(f"Rang {rank}: question humaine absente")

        opening = rec.get("theatrical_opening", {})
        if not str(opening.get("task", "")).strip():
            errors.append(f"Rang {rank}: la scene doit commencer par une tache reelle")
        if len(opening.get("lines", [])) > 2:
            errors.append(f"Rang {rank}: ouverture trop bavarde")

        choices = rec.get("choices", [])
        if len(choices) < 2:
            errors.append(f"Rang {rank}: au moins deux choix requis")
        for choice in choices:
            if not choice.get("costs"):
                errors.append(f"Rang {rank}: choix sans cout reel: {choice.get('id')}")

        body = rec.get("body_system", {})
        missing_body = BODY_FIELDS - set(body)
        if missing_body or any(not str(body.get(field, "")).strip() for field in BODY_FIELDS):
            errors.append(f"Rang {rank}: chaine corporelle incomplete: {sorted(missing_body)}")
        if not str(rec.get("future_break_seed", "")).strip():
            errors.append(f"Rang {rank}: graine de rupture absente")

        camp = rec.get("first_camp", {})
        if not str(camp.get("task", "")).strip():
            errors.append(f"Rang {rank}: premier camp sans tache")
        if len(camp.get("lines", [])) > 2:
            errors.append(f"Rang {rank}: premier camp trop bavard")

        rem = rec.get("remanence", {})
        missing_rem = REMANENCE_FIELDS - set(rem)
        if missing_rem or any(not str(rem.get(field, "")).strip() for field in REMANENCE_FIELDS):
            errors.append(f"Rang {rank}: Remanence incomplete: {sorted(missing_rem)}")

        seeds = rec.get("relationship_seeds", [])
        if len(seeds) != len(expected_existing):
            errors.append(f"Rang {rank}: {len(expected_existing)} premiers liens attendus, trouve {len(seeds)}")
        newcomer_pairs: set[frozenset[str]] = set()
        for seed in seeds:
            pair_id = str(seed.get("pair_id", ""))
            seed_ids.append(pair_id)
            pair = next((p for p in relations.get("pairs", []) if p.get("id") == pair_id), None)
            if pair is None:
                errors.append(f"Couple relationnel inconnu: {pair_id}")
                continue
            members = frozenset(map(str, pair.get("heroes", [])))
            newcomer_pairs.add(members)
            seed_pair_members.add(members)
        expected_pairs = {frozenset([expected_joiner, prior]) for prior in expected_existing}
        if newcomer_pairs != expected_pairs:
            errors.append(f"Rang {rank}: les graines ne couvrent pas exactement tous les liens du nouvel arrivant")

    if len(seed_ids) != 21:
        errors.append(f"La formation doit planter exactement 21 premiers liens, trouve {len(seed_ids)}")
    if len(set(seed_ids)) != 21:
        errors.append("Les 21 graines relationnelles doivent etre uniques")
    if set(seed_ids) != canonical_pair_ids:
        errors.append(f"Les graines doivent correspondre exactement aux 21 couples canoniques: manquants={sorted(canonical_pair_ids-set(seed_ids))}, en trop={sorted(set(seed_ids)-canonical_pair_ids)}")

    anouk = by_rank.get(2, {})
    if "cosmolog" not in json.dumps(anouk, ensure_ascii=False).lower() and rules.get("observed_magic_effect_does_not_prove_cosmology") is not True:
        errors.append("Anouk: effet de Trame et cosmologie doivent rester separes")
    effrie_text = json.dumps(by_rank.get(5, {}), ensure_ascii=False).lower()
    for forbidden_claim in ["confirme un pacte", "prouve une ascendance", "confirme une langue des dragons", "confirme un lien au voile"]:
        if forbidden_claim in effrie_text:
            errors.append(f"Effrie: verrou cosmologique interdit: {forbidden_claim}")
    if "pacte" not in effrie_text or "ascendance" not in effrie_text or "voile" not in effrie_text:
        warnings.append("Effrie: garder explicites les garde-fous Pacte/ascendance/Voile dans la documentation")

    required_doc_phrases = ["Zejé", "Anouk", "Marec", "Mathilde", "Èffrie", "Aurélien", "Lya", "ne sont ni annoncés par une prophétie", "SOURCE", "TRANSMISSION", "TRANSFORMATION", "P9"]
    for phrase in required_doc_phrases:
        if phrase not in doc:
            errors.append(f"Documentation de formation incomplete: {phrase}")
    for phrase in ["deuxième", "troisième", "cinquième", "Zejé", "Anouk", "Marec", "Mathilde", "Èffrie", "Aurélien", "Lya"]:
        if phrase not in decisions:
            errors.append(f"Decision canonique d'ordre incomplete: {phrase}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "formation_order": data.get("formation_order", []),
            "recruitments": len(recruitments),
            "first_camps": sum(1 for r in recruitments if r.get("first_camp")),
            "relationship_seeds": len(seed_ids),
            "canonical_pairs": len(canonical_pair_ids),
        },
    }


if __name__ == "__main__":
    report = audit_legendary_seven_formation(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
