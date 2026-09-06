extends Node

const RESOLVER_SCRIPT := preload("res://scripts/core/veilleurs_intent_resolver.gd")

func _ready() -> void:
    var resolver := RESOLVER_SCRIPT.new() as VeilleursIntentResolver

    var tactical_flee := resolver.resolve_skill_intent("delie_affame", {
        "Arbre": "Fuite des cendres",
        "Compétence": "Repli bas",
        "Type": "Active",
        "Rôle du nœud": "Fondation",
        "Positions": "P1-P3",
        "Puissance 0-5": 1.0,
        "Précision %": 96,
        "Tags": "FUITE;POSITION",
        "Effet": "Change de rang sans quitter le combat."
    })
    assert(bool(tactical_flee.get("ok", false)))
    assert(str(tactical_flee.get("intent_family", "")) == "repositionnement")
    assert(bool(tactical_flee.get("queued", false)))

    var control_override := resolver.resolve_skill_intent("delie_affame", {
        "Arbre": "Faim basse",
        "Compétence": "Coincer la proie",
        "Type": "Active",
        "Rôle du nœud": "Contrôle",
        "Positions": "P1-P2",
        "Puissance 0-5": 2.0,
        "Précision %": 88,
        "Tags": "FAIM;CONTRÔLE",
        "Effet": "Limite le déplacement de la cible."
    })
    assert(str(control_override.get("intent_family", "")) == "controle")

    var environment_override := resolver.resolve_skill_intent("brise_os_de_suie", {
        "Arbre": "Ruée charbonneuse",
        "Compétence": "Corps contre mur",
        "Type": "Interaction",
        "Rôle du nœud": "Interaction monde",
        "Positions": "P1-P3",
        "Puissance 0-5": 4.8,
        "Précision %": 76,
        "Tags": "CHARGE;COLLISION;PROJECTION;MASSE",
        "Effet": "Exploite murs, portes, précipices et corps."
    })
    assert(str(environment_override.get("intent_family", "")) == "environnement")
    assert(str(environment_override.get("action_channel", "")) == "environment_interaction")

    var passive := resolver.resolve_skill_intent("delie_affame", {
        "Arbre": "Faim basse",
        "Compétence": "Odeur du faible",
        "Type": "Passif",
        "Rôle du nœud": "Passif I",
        "Positions": "P1-P3",
        "Tags": "FAIM;CHASSE"
    })
    assert(bool(passive.get("ok", false)))
    assert(not bool(passive.get("queued", true)), "passives must never be exposed as queued enemy intentions")

    var state_exit := resolver.resolve_state_intent("fuite_cession_recrutement", {"mode": "surrender"})
    assert(bool(state_exit.get("ok", false)))
    assert(bool(state_exit.get("state_machine_intent", false)))

    var full := resolver.telegraph(control_override, 5, "clear")
    assert(int(full.get("detail_level", -1)) == 5)
    assert(str(full.get("skill_name", "")) == "Coincer la proie")
    assert(str(full.get("effect", "")) != "")

    var low_light := resolver.telegraph(control_override, 5, "low_light")
    assert(int(low_light.get("detail_level", -1)) == 4)
    assert(int(low_light.get("stored_detail", -1)) == 5)
    assert(str(low_light.get("skill_name", "")) == "Coincer la proie")

    var darkness := resolver.telegraph(control_override, 3, "darkness")
    assert(int(darkness.get("detail_level", -1)) == 0)
    assert(not bool(darkness.get("visible", true)))
    assert(int(darkness.get("stored_detail", -1)) == 3, "perception must not erase stored knowledge")

    print("VEILLEURS_INTENT_RESOLVER_SMOKE_OK")
    get_tree().quit(0)
