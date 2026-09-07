extends Node

const CorpseStateRuntime := preload("res://scripts/core/corpse_state_runtime.gd")

var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    _test_t15_death_revisit_keeps_same_corpse_state()
    _test_t16_burned_corpse_persists_and_blocks_incompatible_uses()
    _test_t17_mother_absorbs_only_admissible_telegraphed_corpse()
    _finish()

func _test_t15_death_revisit_keeps_same_corpse_state() -> void:
    RemanenceRuntime.reset_new_game()
    var scar_id := _create_corpse("Veilleur T15", {"dismembered_parts": ["arm_left"], "anatomy_part_states": {"arm_left": "lost"}})
    _check(scar_id != "", "Tests_48/T15 : une mort doit produire un CorpseState identifiable")
    var first := CorpseStateRuntime.ensure_state(scar_id)
    _check(str(first.get("corpse_id", "")) == scar_id, "Tests_48/T15 : le CorpseState doit porter le même ID que la cicatrice persistante")
    var pose_id := str(first.get("pose_snapshot_id", ""))
    _check(pose_id != "", "Tests_48/T15 : la pose physique doit recevoir un identifiant stable")

    var save_payload := RemanenceRuntime.serialize()
    RemanenceRuntime.reset_new_game()
    _check(not RemanenceRuntime.world_scars.has(scar_id), "Tests_48/T15 : le test doit réellement vider l'état avant recharge")
    RemanenceRuntime.deserialize(save_payload)

    var revisit := CorpseStateRuntime.reconstruct(scar_id)
    _check(bool(revisit.get("ok", false)), "Tests_48/T15 : le même cadavre doit être reconstructible après recharge")
    _check(str(revisit.get("corpse_id", "")) == scar_id, "Tests_48/T15 : une revisite doit conserver le même CorpseState/ID")
    _check(str(revisit.get("pose_snapshot_id", "")) == pose_id, "Tests_48/T15 : la revisite doit réutiliser la pose enregistrée")
    _check(bool(revisit.get("reuse_pose_snapshot", false)), "Tests_48/T15 : la pose persistante doit être réutilisée")
    _check(not bool(revisit.get("resimulate_ragdoll", true)), "Tests_48/T15 : le ragdoll ne doit jamais être resimulé à la revisite")

func _test_t16_burned_corpse_persists_and_blocks_incompatible_uses() -> void:
    RemanenceRuntime.reset_new_game()
    var scar_id := _create_corpse("Corps T16", {})
    _check(CorpseStateRuntime.can_absorb(scar_id), "Tests_48/T16 : un cadavre intact admissible doit pouvoir être absorbé avant transformation")
    _check(CorpseStateRuntime.can_reanimate(scar_id), "Tests_48/T16 : un cadavre intact admissible peut être réanimable avant transformation")

    var burned := CorpseStateRuntime.burn(scar_id)
    _check(bool(burned.get("ok", false)), "Tests_48/T16 : brûler un cadavre doit produire une transition d'état valide")
    var save_payload := RemanenceRuntime.serialize()
    RemanenceRuntime.reset_new_game()
    RemanenceRuntime.deserialize(save_payload)

    var restored := CorpseStateRuntime.state(scar_id)
    _check(str(restored.get("condition", "")) == CorpseStateRuntime.CONDITION_BURNED, "Tests_48/T16 : l'état brûlé doit survivre à la sauvegarde/recharge")
    _check(bool(restored.get("burned", false)), "Tests_48/T16 : la transformation brûlée doit rester explicite")
    _check(not CorpseStateRuntime.can_absorb(scar_id), "Tests_48/T16 : un cadavre brûlé ne doit plus être absorbable")
    _check(not CorpseStateRuntime.can_reanimate(scar_id), "Tests_48/T16 : un cadavre brûlé ne doit plus être réanimable")

func _test_t17_mother_absorbs_only_admissible_telegraphed_corpse() -> void:
    RemanenceRuntime.reset_new_game()
    var valid_id := _create_corpse("Corps admissible T17", {})
    var burned_id := _create_corpse("Corps brûlé T17", {})
    CorpseStateRuntime.burn(burned_id)

    var intent := CorpseStateRuntime.absorption_intent([burned_id, valid_id], "mere_des_veines")
    _check(bool(intent.get("ok", false)), "Tests_48/T17 : la Mère doit pouvoir préparer une assimilation si un cadavre admissible existe")
    _check(bool(intent.get("telegraphed", false)), "Tests_48/T17 : l'assimilation doit être télégraphiée avant résolution")
    _check(str(intent.get("target_corpse_id", "")) == valid_id, "Tests_48/T17 : la Mère doit cibler uniquement un cadavre admissible")
    _check(not (intent.get("eligible_corpse_ids", []) as Array).has(burned_id), "Tests_48/T17 : un cadavre brûlé ne doit jamais apparaître parmi les cibles admissibles")
    _check(not bool(CorpseStateRuntime.state(valid_id).get("consumed", false)), "Tests_48/T17 : le télégraphe ne doit pas consommer le corps avant la fenêtre de réponse")

    var rejected := CorpseStateRuntime.resolve_absorption({"ok": true, "telegraphed": false, "target_corpse_id": valid_id})
    _check(not bool(rejected.get("ok", false)), "Tests_48/T17 : aucune assimilation cachée/non télégraphiée ne doit être résolue")

    var resolved := CorpseStateRuntime.resolve_absorption(intent)
    _check(bool(resolved.get("ok", false)), "Tests_48/T17 : l'assimilation télégraphiée d'un corps admissible doit pouvoir se résoudre")
    var consumed := CorpseStateRuntime.state(valid_id)
    _check(bool(consumed.get("consumed", false)), "Tests_48/T17 : le cadavre ciblé doit être marqué consommé")
    _check(str(consumed.get("consumed_by", "")) == "mere_des_veines", "Tests_48/T17 : l'origine de l'assimilation doit être conservée")
    _check(str(CorpseStateRuntime.state(burned_id).get("condition", "")) == CorpseStateRuntime.CONDITION_BURNED, "Tests_48/T17 : les cadavres inadmissibles ne doivent pas être modifiés par l'assimilation")

func _create_corpse(owner_name: String, body_snapshot: Dictionary) -> String:
    return RemanenceRuntime.create_world_scar(
        "tests_48_corpse_anchor",
        "persistent_corpse",
        "regional",
        {
            "owner_kind": "watcher",
            "owner_id": "hero:%s" % owner_name.to_snake_case(),
            "owner_name": owner_name,
            "body_snapshot": body_snapshot.duplicate(true),
            "protected": true,
            "summary": "%s demeure ici." % owner_name
        }
    )

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _finish() -> void:
    if failures.is_empty():
        print("VEILLEURS_CORPSE_CONTRACT_SMOKE_OK")
        get_tree().quit(0)
        return
    for failure: String in failures:
        push_error("VEILLEURS_CORPSE_CONTRACT_SMOKE: " + failure)
    print("VEILLEURS_CORPSE_CONTRACT_SMOKE_FAILED: %d" % failures.size())
    get_tree().quit(1)
