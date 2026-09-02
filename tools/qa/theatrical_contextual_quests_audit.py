#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def audit_theatrical_contextual_quests(root: Path = ROOT) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []

    registry_path = root / "universe/lore/theatrical_contextual_quests.json"
    hooks_path = root / "universe/lore/contextual_beliefs_rites_quests.json"
    doc_path = root / "docs/LITD1_NEUF_QUETES_CONTEXTUELLES_EDITION_THEATRALE_V1.md"

    if not registry_path.is_file():
        return {"ok": False, "errors": ["Registre des neuf quêtes théâtrales absent"], "warnings": []}
    if not hooks_path.is_file():
        return {"ok": False, "errors": ["Registre source des hooks contextuels absent"], "warnings": []}
    if not doc_path.is_file():
        return {"ok": False, "errors": ["Document théâtral des neuf quêtes absent"], "warnings": []}

    data = load(registry_path)
    hooks = load(hooks_path)
    quests = data.get("quests", [])
    hook_items = hooks.get("quest_hooks", [])

    if data.get("new_quest_count") != 9 or len(quests) != 9:
        errors.append(f"Le cycle complémentaire doit contenir exactement 9 quêtes, trouvé {len(quests)}")

    if data.get("existing_theatrical_quests_preserved") != 23:
        errors.append("Les 23 quêtes théâtrales existantes doivent rester explicitement préservées")

    core = data.get("core_rules", {})
    expected_false = [
        "replaces_existing_23_quests",
        "player_protagonist_emotion_imposed",
        "single_hidden_moral_answer",
        "universal_good_evil_score",
        "new_universal_quest_meter",
        "complete_seven_order_inferred",
    ]
    for key in expected_false:
        if core.get(key) is not False:
            errors.append(f"Garde-fou global incorrect: {key} doit rester false")
    for key in ("unknown_can_be_valid_resolution", "hero_reactions_are_conditional", "depth_uses_existing_systems"):
        if core.get(key) is not True:
            errors.append(f"Garde-fou global incorrect: {key} doit rester true")

    ids = [str(item.get("id", "")) for item in quests]
    if not all(ids) or len(ids) != len(set(ids)):
        errors.append("Identifiants de quêtes absents ou dupliqués")

    source_hooks = [str(item.get("source_hook_id", "")) for item in quests]
    expected_hooks = {str(item.get("id")) for item in hook_items}
    if set(source_hooks) != expected_hooks:
        missing = sorted(expected_hooks - set(source_hooks))
        extra = sorted(set(source_hooks) - expected_hooks)
        errors.append(f"Correspondance hooks/quêtes incorrecte; manquants={missing}, supplémentaires={extra}")
    if len(source_hooks) != len(set(source_hooks)):
        errors.append("Un hook contextuel ne doit alimenter qu'une seule des neuf quêtes")

    expected_chapters = {
        "lhaor_seeds_that_remain": 1,
        "orun_sai_road_without_grave": 1,
        "dhor_khal_bridge_two_valleys": 1,
        "saen_ask_before_pulling": 6,
        "azravel_burned_margins": 8,
        "azravel_table_still_open": 8,
        "lysandra_what_miracle_proves": 9,
        "zeje_three_versions_same_dead": 9,
        "effrie_not_ours": 9,
    }

    for quest in quests:
        qid = str(quest.get("id", "<sans-id>"))
        hook = str(quest.get("source_hook_id", ""))
        if quest.get("chapter") != expected_chapters.get(hook):
            errors.append(f"Placement de chapitre incorrect pour {qid}: {quest.get('chapter')}")
        if not quest.get("human_question"):
            errors.append(f"Question humaine absente pour {qid}")
        choices = quest.get("choices", [])
        if len(choices) < 2:
            errors.append(f"La quête {qid} doit proposer au moins deux responsabilités jouables")
        choice_ids = [str(choice.get("id", "")) for choice in choices]
        if not all(choice_ids) or len(choice_ids) != len(set(choice_ids)):
            errors.append(f"Choix absents ou dupliqués pour {qid}")
        rem = quest.get("remanence", {})
        if not rem.get("source") or not rem.get("transmission") or not rem.get("transformation"):
            errors.append(f"Chaîne de Rémanence incomplète pour {qid}")
        reactions = quest.get("conditional_hero_reactions", [])
        if reactions and not core.get("hero_reactions_are_conditional"):
            errors.append(f"Réactions de héros non conditionnelles pour {qid}")

    chapters = {str(k): v for k, v in data.get("chapter_distribution", {}).items()}
    if chapters != {"1": 3, "6": 1, "8": 2, "9": 3}:
        errors.append(f"Distribution des chapitres incorrecte: {chapters}")

    by_hook = {str(q.get("source_hook_id")): q for q in quests}

    saen = by_hook.get("saen_ask_before_pulling", {})
    if "invasive_anchor_increase_on_saen" not in saen.get("forbidden_after_clear_refusal", []):
        errors.append("Le refus clair de Saen doit interdire l'augmentation invasive concernée")
    saen_stage = saen.get("saen_staging", {})
    if saen_stage.get("human_body_language") is not False:
        errors.append("Saen ne doit pas recevoir de langage corporel humain inventé")
    if saen_stage.get("represents_all_absents") is not False:
        errors.append("Saen ne doit pas représenter tous les Absents")

    lysandra = by_hook.get("lysandra_what_miracle_proves", {})
    lguards = set(lysandra.get("guardrails", []))
    required_lguards = {
        "miracle_does_not_prove_theology",
        "raised_dead_does_not_prove_soul_return",
        "healing_does_not_erase_all_bodily_consequences",
    }
    if not required_lguards.issubset(lguards):
        errors.append("Les garde-fous épistémiques/corporels de Lysandra sont incomplets")
    if len(lysandra.get("body_system", [])) < 3:
        errors.append("La guérison de Lysandra doit conserver des conséquences corporelles lisibles")

    zeje = by_hook.get("zeje_three_versions_same_dead", {})
    zguards = set(zeje.get("guardrails", []))
    if "unknown_is_valid" not in zguards or "probable_marker_must_be_visible" not in zguards:
        errors.append("Zejé doit conserver INCONNU et PROBABLE comme statuts explicites")
    if zeje.get("requires_character") != "hero.zeje":
        errors.append("La quête de Zejé doit dépendre de sa présence sans fixer son rang de formation")

    effrie = by_hook.get("effrie_not_ours", {})
    eguards = set(effrie.get("guardrails", []))
    required_eguards = {
        "no_vharren_lock",
        "no_ancestral_pact_reveal",
        "no_dragon_ancestry_proof",
        "no_dragon_language_lock",
        "no_veil_link",
        "activity_does_not_equal_property",
        "no_visible_dragon_needed",
    }
    if not required_eguards.issubset(eguards):
        errors.append("Les garde-fous draconiques d'Èffrie sont incomplets")
    if effrie.get("visible_dragon_required") is not False:
        errors.append("Aucun dragon visible ne doit être requis pour la quête d'Èffrie")
    if effrie.get("requires_character") != "hero.effrie":
        errors.append("La quête d'Èffrie doit dépendre de sa présence sans fixer son rang de formation")

    for source in data.get("sources", []):
        if not (root / str(source)).is_file():
            errors.append(f"Source déclarée absente: {source}")

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "quests": len(quests),
            "choices": sum(len(q.get("choices", [])) for q in quests),
            "source_hooks": len(expected_hooks),
            "chapters": sorted({q.get("chapter") for q in quests}),
        },
    }


if __name__ == "__main__":
    report = audit_theatrical_contextual_quests(ROOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if report["ok"] else 1)
