#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_FAMILIES = {
    "food_and_logistics",
    "migration_and_refuge",
    "death_identity_and_memorial",
    "evidence_testimony_and_uncertainty",
    "nonhuman_consent",
    "scarce_resources_and_dragon_site",
    "relationships_and_bereavement",
}
EXPECTED_HEROES = {
    "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
    "hero.marec", "hero.zeje", "hero.anouk",
}
ALLOWED_CHANNELS = {
    "rumors", "visual", "population", "audio", "memorial", "infirmary",
    "market", "gate", "company",
}
ALLOWED_EXTERNAL = {
    "new_nonhuman_consciousness_clear_refusal",
    "new_nonhuman_consciousness_uncertain_response",
    "contextual_named_death",
    "winter_resource_pressure",
    "contradictory_late_evidence",
}
ALLOWED_RUMOR_MODES = {"confirmed", "direct", "reported", "variable", "unreliable", "witnessed"}


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_systemic_cross_ramifications(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    cross_path = root / "universe/lore/contextual_quest_cross_ramifications.json"
    quests_path = root / "universe/lore/theatrical_contextual_quests.json"
    ramifications_path = root / "universe/lore/theatrical_contextual_quest_ramifications.json"
    doc_path = root / "docs/LITD1_CROISEMENTS_SYSTEMIQUES_DES_9_QUETES_V1.md"

    for path, label in [
        (cross_path, "registre croisé"),
        (quests_path, "quêtes source"),
        (ramifications_path, "ramifications source"),
        (doc_path, "document narratif"),
    ]:
        if not path.is_file():
            return {"ok": False, "errors": [f"{label} absent: {path.relative_to(root)}"], "warnings": []}

    data = load(cross_path)
    quests = load(quests_path)
    ramifications = load(ramifications_path)
    doc = doc_path.read_text(encoding="utf-8")

    source_pairs = {
        (str(q.get("id")), str(c.get("id")))
        for q in quests.get("quests", [])
        for c in q.get("choices", [])
    }
    ram_pairs = {
        (str(item.get("quest_id")), str(item.get("choice_id")))
        for item in ramifications.get("ramifications", [])
    }
    if source_pairs != ram_pairs:
        errors.append("La couche croisée exige que les ramifications individuelles couvrent exactement les choix source")
    if len(source_pairs) != 26:
        errors.append(f"Le cycle source doit exposer 26 choix, trouvé {len(source_pairs)}")

    core = data.get("core_rules", {})
    for key in [
        "crossings_use_existing_systems",
        "cross_event_requires_multiple_causes",
        "rumor_collision_preserves_sources",
        "contradiction_can_remain_unresolved",
        "hero_reactions_are_conditional",
        "deaths_remain_contextual",
        "relationship_effects_are_not_approval_scores",
    ]:
        if core.get(key) is not True:
            errors.append(f"Garde-fou {key} doit rester true")
    for key in [
        "new_universal_meter",
        "global_morality_score",
        "numeric_balance_values_locked_by_lore",
        "past_games_can_be_caused_by_litd1",
        "complete_seven_order_inferred",
    ]:
        if core.get(key) is not False:
            errors.append(f"Garde-fou {key} doit rester false")

    families = set(map(str, data.get("families", [])))
    if families != EXPECTED_FAMILIES:
        errors.append(f"Familles systémiques inattendues: {sorted(families)}")

    external_declared = set(map(str, data.get("external_triggers", [])))
    if external_declared != ALLOWED_EXTERNAL:
        errors.append(f"Déclencheurs externes inattendus: {sorted(external_declared)}")

    events = data.get("cross_events", [])
    ids = [str(item.get("id", "")) for item in events]
    if len(events) != 18:
        errors.append(f"La V1 doit contenir 18 événements croisés, trouvé {len(events)}")
    if not all(ids) or len(ids) != len(set(ids)):
        errors.append("Identifiants croisés absents ou dupliqués")

    used_pairs: set[tuple[str, str]] = set()
    hero_union: set[str] = set()
    family_seen: set[str] = set()
    rumor_modes_seen: set[str] = set()
    contextual_death_events = 0

    for item in events:
        event_id = str(item.get("id", "<sans-id>"))
        family = str(item.get("family", ""))
        family_seen.add(family)
        if family not in EXPECTED_FAMILIES:
            errors.append(f"Famille inconnue pour {event_id}: {family}")

        choices_raw = item.get("all_choices", [])
        choice_pairs: list[tuple[str, str]] = []
        for raw in choices_raw:
            if not isinstance(raw, list) or len(raw) != 2:
                errors.append(f"Référence de choix mal formée dans {event_id}: {raw!r}")
                continue
            pair = (str(raw[0]), str(raw[1]))
            choice_pairs.append(pair)
            used_pairs.add(pair)
            if pair not in source_pairs:
                errors.append(f"Choix inconnu dans {event_id}: {pair}")

        externals = set(map(str, item.get("external_triggers", [])))
        if not externals.issubset(ALLOWED_EXTERNAL):
            errors.append(f"Déclencheur externe inconnu dans {event_id}: {sorted(externals-ALLOWED_EXTERNAL)}")
        cause_count = len(choice_pairs) + len(externals) + (1 if item.get("requires_prior_contextual_choice") is True else 0)
        if cause_count < 2:
            errors.append(f"{event_id} doit dépendre d'au moins deux causes réelles")

        channels = set(map(str, item.get("channels", [])))
        if not channels or not channels.issubset(ALLOWED_CHANNELS):
            errors.append(f"Canaux invalides pour {event_id}: {sorted(channels-ALLOWED_CHANNELS)}")
        if not item.get("world_result") or not item.get("tension") or not item.get("remanence_future"):
            errors.append(f"Résultat/tension/Rémanence incomplet pour {event_id}")

        rumor_modes = set(map(str, item.get("rumor_modes", [])))
        rumor_modes_seen |= rumor_modes
        if not rumor_modes or not rumor_modes.issubset(ALLOWED_RUMOR_MODES):
            errors.append(f"Mode de rumeur invalide dans {event_id}: {sorted(rumor_modes)}")

        heroes = set(map(str, item.get("hero_followups", [])))
        hero_union |= heroes
        if not heroes or not heroes.issubset(EXPECTED_HEROES):
            errors.append(f"Héros de suivi invalides dans {event_id}: {sorted(heroes-EXPECTED_HEROES)}")

        if item.get("possible_death") is True:
            contextual_death_events += 1

        encoded = json.dumps(item, ensure_ascii=False).lower()
        for forbidden in ["reputation_score", "alignment_score", "morality_score", "score_delta", "relationship_delta"]:
            if forbidden in encoded:
                errors.append(f"Score/jauge interdit dans {event_id}: {forbidden}")

    if used_pairs != source_pairs:
        missing = sorted(source_pairs - used_pairs)
        errors.append(f"Tous les 26 choix doivent participer à au moins un croisement; manquants={missing}")
    if hero_union != EXPECTED_HEROES:
        errors.append(f"Les Sept doivent tous pouvoir apparaître dans les croisements; manquants={sorted(EXPECTED_HEROES-hero_union)}")
    if family_seen != EXPECTED_FAMILIES:
        errors.append(f"Toutes les familles doivent être effectivement utilisées; manquantes={sorted(EXPECTED_FAMILIES-family_seen)}")
    if contextual_death_events < 6:
        errors.append("La couche doit conserver plusieurs risques de mort contextuels sans en faire une punition automatique")
    if len(rumor_modes_seen) < 5:
        errors.append("Les croisements doivent conserver plusieurs niveaux de fiabilité des rumeurs")

    event_ids = set(ids)
    cascades = data.get("compound_cascades", [])
    if len(cascades) != 4:
        errors.append(f"La V1 doit contenir quatre cascades, trouvé {len(cascades)}")
    cascade_ids = [str(item.get("id", "")) for item in cascades]
    if not all(cascade_ids) or len(cascade_ids) != len(set(cascade_ids)):
        errors.append("Identifiants de cascades absents ou dupliqués")
    for cascade in cascades:
        cid = str(cascade.get("id", "<sans-id>"))
        refs = set(map(str, cascade.get("requires_any_cross_events", [])))
        if not refs or not refs.issubset(event_ids):
            errors.append(f"Cascade {cid} référence des croisements inconnus: {sorted(refs-event_ids)}")
        externals = set(map(str, cascade.get("requires_external", [])))
        if not externals.issubset(ALLOWED_EXTERNAL):
            errors.append(f"Cascade {cid} utilise un déclencheur externe inconnu")
        channels = set(map(str, cascade.get("channels", [])))
        if not channels or not channels.issubset(ALLOWED_CHANNELS):
            errors.append(f"Canaux invalides pour la cascade {cid}")
        if not cascade.get("result"):
            errors.append(f"Résultat absent pour la cascade {cid}")

    source_by_id = {str(q.get("id")): q for q in quests.get("quests", [])}
    saen = source_by_id.get("quest.litd1.saen_ask_before_pulling", {})
    if "invasive_anchor_increase_on_saen" not in saen.get("forbidden_after_clear_refusal", []):
        errors.append("Le croisement ne doit jamais rouvrir l'action invasive interdite sur Saen")
    lysandra = source_by_id.get("quest.litd1.lysandra_what_miracle_proves", {})
    if "miracle_does_not_prove_theology" not in set(lysandra.get("guardrails", [])):
        errors.append("Le croisement doit conserver le garde-fou théologique de Lysandra")
    zeje = source_by_id.get("quest.litd1.zeje_three_versions_same_dead", {})
    zguards = set(zeje.get("guardrails", []))
    if not {"unknown_is_valid", "probable_marker_must_be_visible"}.issubset(zguards):
        errors.append("Le croisement doit préserver PROBABLE et INCONNU chez Zejé")
    effrie = source_by_id.get("quest.litd1.effrie_not_ours", {})
    required_effrie = {
        "no_vharren_lock", "no_ancestral_pact_reveal", "no_dragon_ancestry_proof",
        "no_dragon_language_lock", "no_veil_link",
    }
    if not required_effrie.issubset(set(effrie.get("guardrails", []))):
        errors.append("Le croisement doit conserver les inconnues draconiques d'Èffrie")

    required_doc_phrases = [
        "pas d'une nouvelle jauge",
        "L'absence de refus compréhensible n'est pas une preuve de consentement",
        "PROBABLE",
        "INCONNU",
        "Aucun Vharren, Pacte ancestral, ascendance draconique, langue draconique ou lien au Voile n'est confirmé",
        "ne peut jamais causer rétroactivement",
    ]
    for phrase in required_doc_phrases:
        if phrase not in doc:
            errors.append(f"Garde-fou narratif absent: {phrase}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "source_choices": len(source_pairs),
            "cross_events": len(events),
            "families": len(family_seen),
            "cascades": len(cascades),
            "heroes_represented": sorted(hero_union),
            "contextual_death_events": contextual_death_events,
            "rumor_modes": sorted(rumor_modes_seen),
        },
    }


if __name__ == "__main__":
    report = audit_systemic_cross_ramifications(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
