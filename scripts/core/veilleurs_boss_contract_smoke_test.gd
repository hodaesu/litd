extends Node

const BossRuntime := preload("res://scripts/core/veilleurs_boss_contract_runtime.gd")

var failures: Array[String] = []
var boss: RefCounted

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    boss = BossRuntime.new()
    _test_t36_ishar_phase_requires_hp_and_two_methods()
    _test_t37_ishar_memory_repetition_and_new_family()
    _test_t38_orateur_echo_copies_structure_not_impossible_asset()
    _test_t39_orateur_silence_keeps_individual_commands()
    _test_t40_mother_network_only_visible_active_connections()
    _test_t41_mother_dead_zones_persist_between_phases()
    _test_t42_porte_cendres_cannot_erase_irreversible_states()
    _test_t43_porte_cendres_procession_is_announced_and_defendable()
    _test_t44_copiste_copies_recent_families_not_stats()
    _test_t45_copiste_one_correction_per_window()
    _test_t46_copiste_palimpseste_two_coherent_versions()
    _test_t47_copiste_finale_can_be_broken_by_novel_sequence()
    _finish()

func _test_t36_ishar_phase_requires_hp_and_two_methods() -> void:
    var hp_only: Dictionary = boss.call("ishar_phase_1_transition", 0.69, ["alternate_move"])
    _check(not bool(hp_only.get("transition", true)), "Tests_48/T36 : la vitalité seule ne doit pas ouvrir la phase 2 d'Ishar")
    var methods_only: Dictionary = boss.call("ishar_phase_1_transition", 0.90, ["alternate_move", "environment_break"])
    _check(not bool(methods_only.get("transition", true)), "Tests_48/T36 : deux méthodes seules ne doivent pas ignorer le seuil de vitalité")
    var ready: Dictionary = boss.call("ishar_phase_1_transition", 0.69, ["alternate_move", "environment_break", "alternate_move"])
    _check(bool(ready.get("transition", false)), "Tests_48/T36 : Ishar doit transiter seulement après vitalité + deux méthodes de franchissement distinctes")
    _check((ready.get("distinct_methods", []) as Array).size() == 2, "Tests_48/T36 : répéter une méthode ne doit pas compter comme second franchissement distinct")

func _test_t37_ishar_memory_repetition_and_new_family() -> void:
    var memory := {"family_counts": {}}
    var first: Dictionary = boss.call("ishar_record_family", memory, "attack")
    var first_state: Dictionary = first.get("state", {})
    _check(bool(first.get("new_family_bypasses", false)) and is_equal_approx(float(first.get("adaptation", 1.0)), 0.0), "Tests_48/T37 : une famille nouvelle doit contourner l'adaptation existante")
    var repeated: Dictionary = boss.call("ishar_record_family", first_state, "attack")
    _check(float(repeated.get("adaptation", 0.0)) > float(first.get("adaptation", 0.0)), "Tests_48/T37 : répéter la même famille doit renforcer la contre-réponse d'Ishar")
    var repeated_state: Dictionary = repeated.get("state", {})
    var new_family: Dictionary = boss.call("ishar_record_family", repeated_state, "movement")
    _check(bool(new_family.get("new_family_bypasses", false)), "Tests_48/T37 : changer de famille doit rouvrir une fenêtre tactique")
    _check(is_equal_approx(float(new_family.get("adaptation", 1.0)), 0.0), "Tests_48/T37 : l'adaptation à attaque ne doit pas être transférée gratuitement à mouvement")

func _test_t38_orateur_echo_copies_structure_not_impossible_asset() -> void:
    var action := {
        "family": "guard_break",
        "target_mode": "front",
        "timing": "major",
        "tags": ["impact", "formation"],
        "weapon_id": "unique_halberd",
        "weapon_asset": "res://hero_only_halberd.glb",
        "animation_asset": "hero_only_animation",
        "damage": 999,
        "player_stats": {"strength": 999}
    }
    var echo: Dictionary = boss.call("orateur_echo", action, {"context_valid": true})
    var structure: Dictionary = echo.get("echo", {})
    _check(bool(echo.get("can_resolve", false)) and bool(structure.get("structural_copy", false)), "Tests_48/T38 : l'Écho doit copier une structure d'action exploitable")
    _check(not structure.has("weapon_id") and not structure.has("weapon_asset") and not structure.has("animation_asset"), "Tests_48/T38 : l'Orateur ne doit jamais matérialiser arme ou asset impossible")
    _check(not bool(echo.get("copied_stats", true)), "Tests_48/T38 : l'Écho ne copie pas les statistiques du joueur")
    var failed_context: Dictionary = boss.call("orateur_echo", action, {"context_valid": false})
    _check(not bool(failed_context.get("can_resolve", true)) and bool(failed_context.get("failed_by_context", false)), "Tests_48/T38 : changer le contexte doit pouvoir faire échouer la structure copiée")

func _test_t39_orateur_silence_keeps_individual_commands() -> void:
    var actions := [
        {"id":"solo_cut","coordination":"individual","requires_voice":false},
        {"id":"concord_call","coordination":"collective","requires_voice":true}
    ]
    var silenced: Array = boss.call("orateur_apply_silence", actions)
    _check(silenced.size() == 2, "Tests_48/T39 : le Silence ne doit pas supprimer toute la liste de commandes")
    var individual: Dictionary = silenced[0]
    var collective: Dictionary = silenced[1]
    _check(bool(individual.get("enabled", false)) and is_equal_approx(float(individual.get("reliability_multiplier", 0.0)), 1.0), "Tests_48/T39 : une action individuelle reste pleinement utilisable sous Silence")
    _check(bool(collective.get("enabled", false)), "Tests_48/T39 : même une action collective reste commandable, elle devient seulement moins fiable")
    _check(float(collective.get("reliability_multiplier", 1.0)) < 1.0, "Tests_48/T39 : le Silence doit pénaliser la coordination sans désactiver les commandes")

func _test_t40_mother_network_only_visible_active_connections() -> void:
    var connections := [
        {"id":"c_visible","target_id":"node_a","active":true,"visible":true},
        {"id":"c_hidden","target_id":"node_b","active":true,"visible":false},
        {"id":"c_dead","target_id":"node_c","active":false,"visible":true}
    ]
    var result: Dictionary = boss.call("mother_redistribute_damage", 100.0, connections)
    _check(int(result.get("active_visible_connections", 0)) == 1, "Tests_48/T40 : seul un lien actif ET visible doit participer au réseau")
    var transfers: Array = result.get("transfers", [])
    _check(transfers.size() == 1 and str((transfers[0] as Dictionary).get("connection_id", "")) == "c_visible", "Tests_48/T40 : aucun dégât ne doit être redistribué via un lien caché ou coupé")
    _check(float(result.get("direct_damage", 0.0)) > 0.0, "Tests_48/T40 : le réseau ne doit pas absorber arbitrairement tous les dégâts")

func _test_t41_mother_dead_zones_persist_between_phases() -> void:
    var state := {"phase":1,"dead_zones":[]}
    state = boss.call("mother_mark_dead_zone", state, "zone_2")
    state = boss.call("mother_mark_dead_zone", state, "zone_4")
    var next: Dictionary = boss.call("mother_advance_phase", state, 2)
    _check(int(next.get("phase", 0)) == 2, "Tests_48/T41 : la Mère doit pouvoir passer de phase")
    var zones: Array = next.get("dead_zones", [])
    _check(zones.has("zone_2") and zones.has("zone_4") and zones.size() == 2, "Tests_48/T41 : les coupures du réseau doivent rester mortes après la transition de phase")

func _test_t42_porte_cendres_cannot_erase_irreversible_states() -> void:
    var elements := [
        {"id":"mark","kind":"temporary_mark"},
        {"id":"wound","kind":"injury"},
        {"id":"dead","kind":"death"},
        {"id":"body","kind":"corpse"},
        {"id":"door","kind":"destroyed_door"},
        {"id":"memory","kind":"anchored_remanence","anchored":true}
    ]
    var result: Dictionary = boss.call("porte_cendres_efface", elements)
    var erased: Array = result.get("erased", [])
    var protected: Array = result.get("protected", [])
    _check(erased.size() == 1 and str((erased[0] as Dictionary).get("id", "")) == "mark", "Tests_48/T42 : l'Effacement ne peut retirer que les traces temporaires/superficielles compatibles")
    _check(protected.size() == 5, "Tests_48/T42 : blessure, mort, cadavre, porte détruite et Rémanence ancrée doivent être protégés")

func _test_t43_porte_cendres_procession_is_announced_and_defendable() -> void:
    var state: Dictionary = boss.call("procession_initial_state")
    state = boss.call("procession_announce", state)
    var first: Dictionary = boss.call("procession_resolve", state)
    _check(bool(first.get("was_announced", false)) and bool(first.get("reduced", false)), "Tests_48/T43 : une réduction de route doit être annoncée avant de se produire")
    _check(int(first.get("route_after", 0)) == int(first.get("route_before", 0)) - 1, "Tests_48/T43 : la Procession réduit la route par un pas borné, pas par fermeture arbitraire")
    var defended_state: Dictionary = first.get("state", {})
    defended_state = boss.call("procession_announce", defended_state)
    defended_state = boss.call("procession_defend", defended_state, "physical_obstacle")
    var defended: Dictionary = boss.call("procession_resolve", defended_state)
    _check(bool(defended.get("defended", false)) and not bool(defended.get("reduced", true)), "Tests_48/T43 : une Procession annoncée doit pouvoir être défendue par une réponse physique valide")

func _test_t44_copiste_copies_recent_families_not_stats() -> void:
    var actions := [
        {"family":"attack","damage":80,"player_stats":{"strength":99}},
        {"family":"guard","damage":0},
        {"family":"movement","speed":999},
        {"family":"support","healing":999}
    ]
    var copy: Dictionary = boss.call("copiste_copy_recent", actions)
    var families: Array = copy.get("families", [])
    _check(families.size() == 3 and families.has("support") and families.has("movement") and families.has("guard"), "Tests_48/T44 : le Copiste doit retenir les familles récentes, pas l'historique entier")
    _check(not bool(copy.get("copied_player_stats", true)) and not bool(copy.get("copied_damage_values", true)), "Tests_48/T44 : Copie ne doit jamais recopier les statistiques ou valeurs brutes du joueur")
    _check(str(copy.get("copy_kind", "")) == "structure_only", "Tests_48/T44 : la copie canonique porte sur la structure d'action")

func _test_t45_copiste_one_correction_per_window() -> void:
    var window: Dictionary = boss.call("copiste_start_correction_window")
    var heavy: Dictionary = boss.call("copiste_correct", window, {"kind":"injury"})
    _check(not bool(heavy.get("corrected", true)) and str(heavy.get("reason", "")) == "heavy_consequence_protected", "Tests_48/T45 : une Correction ne peut pas annuler une conséquence lourde comme une blessure")
    var first: Dictionary = boss.call("copiste_correct", window, {"kind":"temporary_mark"})
    _check(bool(first.get("corrected", false)), "Tests_48/T45 : une conséquence légère compatible peut être corrigée")
    var spent_window: Dictionary = first.get("window", {})
    var second: Dictionary = boss.call("copiste_correct", spent_window, {"kind":"light_position_shift"})
    _check(not bool(second.get("corrected", true)) and str(second.get("reason", "")) == "window_budget_spent", "Tests_48/T45 : une seule Correction est autorisée par fenêtre")

func _test_t46_copiste_palimpseste_two_coherent_versions() -> void:
    var result: Dictionary = boss.call("copiste_palimpseste", true, "B")
    var versions: Array = result.get("versions", [])
    _check(int(result.get("version_count", 0)) == 2 and versions.size() == 2, "Tests_48/T46 : Palimpseste doit superposer exactement deux versions cohérentes")
    _check(bool((versions[0] as Dictionary).get("coherent", false)) and bool((versions[1] as Dictionary).get("coherent", false)), "Tests_48/T46 : les deux versions doivent rester cohérentes et lisibles")
    _check(str(result.get("stable_version", "")) == "B" and bool(result.get("light_stabilized", false)), "Tests_48/T46 : une lumière stable doit ancrer consciemment la version choisie")
    _check(not bool(result.get("random_teleport", true)) and bool(result.get("shared_anchors", false)), "Tests_48/T46 : Palimpseste ne doit jamais téléporter aléatoirement les acteurs")

func _test_t47_copiste_finale_can_be_broken_by_novel_sequence() -> void:
    var observed := ["attack", "attack", "attack", "guard", "guard", "movement", "support"]
    var result: Dictionary = boss.call("copiste_finale", observed, ["environment"])
    var synthesis: Array = result.get("synthesis", [])
    _check(synthesis.size() == 3 and synthesis.has("attack") and synthesis.has("guard"), "Tests_48/T47 : la finale doit synthétiser les comportements réellement les plus observés")
    _check(not bool(result.get("copied_player_stats", true)), "Tests_48/T47 : la synthèse finale reste comportementale, jamais statistique")
    _check(bool(result.get("synthesis_broken", false)) and bool(result.get("new_sequence_can_beat", false)), "Tests_48/T47 : une séquence réellement nouvelle doit pouvoir briser la synthèse du Copiste")
    _check((result.get("novel_sequence", []) as Array).has("environment"), "Tests_48/T47 : la nouveauté tactique doit être explicitement reconnue")

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_BOSS_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_BOSS_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_BOSS_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
