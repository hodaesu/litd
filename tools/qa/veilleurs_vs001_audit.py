from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DUNGEONS = ROOT / "data" / "dungeons"
VEILLEURS = ROOT / "data" / "veilleurs"

FILES = {
    "config": DUNGEONS / "voices_under_sanctuary_hybrid_config.json",
    "map": DUNGEONS / "voices_under_sanctuary_map.json",
    "modules": DUNGEONS / "voices_under_sanctuary_module_library.json",
    "remanence": DUNGEONS / "voices_under_sanctuary_remanence_anchors.json",
    "encounters": DUNGEONS / "voices_under_sanctuary_encounters.json",
    "balance": VEILLEURS / "vs001_balance.json",
    "events": VEILLEURS / "vs001_events.json",
    "dialogues": VEILLEURS / "vs001_dialogues.json",
    "ui": VEILLEURS / "vs001_ui_input_contract.json",
    "guardrails": VEILLEURS / "vs001_playtest_guardrails.json",
    "telemetry": VEILLEURS / "vs001_telemetry_contract.json",
}
MODULE_SCHEMA = DUNGEONS / "hybrid_module_contract.schema.json"
CAPTURABLES = ROOT / "data" / "capturable_creatures.json"
CAPTURE_WOUNDS = ROOT / "data" / "capture_wound_rules.json"
PROJECT = ROOT / "project.godot"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def audit() -> list[str]:
    errors: list[str] = []
    data = {}
    for key, path in FILES.items():
        if not path.exists():
            errors.append(f"missing:{path.relative_to(ROOT)}")
            continue
        try:
            data[key] = load(path)
        except Exception as exc:
            errors.append(f"invalid_json:{path.relative_to(ROOT)}:{exc}")
    if errors:
        return errors

    for key, value in data.items():
        if value.get("version") != 1:
            errors.append(f"version:{key}")

    config = data["config"]
    amap = data["map"]
    modules = data["modules"]
    rem = data["remanence"]
    encounters = data["encounters"]
    balance = data["balance"]
    events = data["events"]
    dialogues = data["dialogues"]
    ui = data["ui"]
    guardrails = data["guardrails"]
    telemetry = data["telemetry"]

    if config["profile"] != "short":
        errors.append("config_profile_not_short")
    room_ids = [r["id"] for r in amap["rooms"]]
    if len(room_ids) != 8 or len(set(room_ids)) != 8:
        errors.append("map_must_have_8_unique_rooms")
    if amap["entry"] != "s1_vestibule" or amap["objective"] != "s7_voice_chamber":
        errors.append("entry_or_objective_changed")
    if not amap["invariants"].get("s8_never_required"):
        errors.append("s8_must_be_optional")
    if not amap["invariants"].get("physical_retreat_to_entry"):
        errors.append("physical_retreat_required")

    schema = load(MODULE_SCHEMA)
    required = set(schema["required"])
    module_ids = set()
    anchors = set()
    for module in modules["modules"]:
        if not required <= set(module):
            errors.append(f"module_missing_fields:{module.get('module_id','?')}")
        mid = module["module_id"]
        if mid in module_ids:
            errors.append(f"duplicate_module:{mid}")
        module_ids.add(mid)
        conn_ids = [c["id"] for c in module["connectors"]]
        if len(conn_ids) != len(set(conn_ids)):
            errors.append(f"duplicate_connector:{mid}")
        for group in ("scar_anchors", "encounter_anchors", "resource_anchors", "lore_anchors"):
            for anchor in module[group]:
                aid = anchor["anchor_id"]
                if aid in anchors:
                    errors.append(f"duplicate_anchor:{aid}")
                anchors.add(aid)
        if any(v < 0 or v > 5 for v in module["mobile_cost"].values()):
            errors.append(f"mobile_budget:{mid}")

    map_module_ids = {r["module_id"] for r in amap["rooms"]}
    if not map_module_ids <= module_ids:
        errors.append("map_references_unknown_module")

    rem_ids = {a["anchor_id"] for a in rem["anchors"]}
    scar_refs = {a["anchor_id"] for m in modules["modules"] for a in m["scar_anchors"]}
    if not scar_refs <= rem_ids:
        errors.append("scar_anchor_missing_from_remanence")
    if config["world_rules"].get("mobile_pc_topology_identical") is not True:
        errors.append("mobile_pc_topology_must_match")
    if amap["invariants"].get("scene_snapshot_persistence") is not False:
        errors.append("scene_snapshots_forbidden")

    if set(balance["watchers"]) != {"nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"}:
        errors.append("watcher_quartet_changed")
    if balance["light"]["initial"] < 0 or balance["light"]["initial"] > 100:
        errors.append("light_initial_out_of_range")
    if balance["noise"]["range"] != [0, 100]:
        errors.append("noise_range_changed")
    if balance["injury_model"]["body_parts"]["arm_left"]["trauma_threshold"] != 100:
        errors.append("arm_trauma_contract_changed")
    if balance["injury_model"]["body_parts"]["leg_left"]["trauma_threshold"] != 105:
        errors.append("leg_trauma_contract_changed")
    if balance["injury_model"]["body_parts"]["head"]["trauma_threshold"] != 125:
        errors.append("head_trauma_contract_changed")

    gh = balance["ghoul_profiles"]
    if any(p["creature_id"] != "hungry_ghoul" for p in gh.values()):
        errors.append("ghoul_profiles_must_share_creature_id")
    if gh["hungry_scout"]["profile_id"] != "scout":
        errors.append("scout_profile_missing")
    if gh["voracious_evolved"]["evolution_level"] != 5:
        errors.append("voracious_must_be_level5_evolution")

    capturables = load(CAPTURABLES)
    hungry = next((c for c in capturables if c["id"] == "hungry_ghoul"), None)
    if not hungry:
        errors.append("hungry_ghoul_missing_global")
    else:
        evo = {e["level"]: e["name"] for e in hungry["evolutions"]}
        if evo.get(5) != "Goule vorace":
            errors.append("global_ghoul_evolution_conflict")
        if hungry["capture"]["resistance"] != balance["recruitment_s6"]["capture_check"]["creature_resistance"]:
            errors.append("capture_resistance_conflict")

    wounds = load(CAPTURE_WOUNDS)
    if not balance["recruitment_s6"]["capture_check"].get("wound_bonus_from_existing_contract"):
        errors.append("capture_wound_contract_not_reused")
    if wounds["disable_combat_until_care_complete"] is not True:
        errors.append("global_convalescence_contract_changed")
    hard = balance["recruitment_s6"]["hard_blocks"]
    if hard.get("manifestation_destructrice") != "recruitment_disabled":
        errors.append("manifestation_destructrice_must_block_recruitment")

    fixed_s3 = encounters["room_tables"]["voices_combat"]["s3_intro"]["members"]
    if sum(x["count"] for x in fixed_s3) != 3:
        errors.append("s3_requires_three_ghouls")
    fixed_s7 = encounters["room_tables"]["voices_objective"]["s7_finale"]["members"]
    if sum(x["count"] for x in fixed_s7) != 3:
        errors.append("s7_requires_three_ghouls")

    event_ids = [e["id"] for e in events["events"]]
    if event_ids != [f"EVT_{i:02d}" for i in range(1, 11)]:
        errors.append("event_set_incomplete")

    dialogue_ids = {e["id"] for e in dialogues["events"]}
    required_dialogues = {
        "dlg_s1_entry", "dlg_s2_trap_triggered", "dlg_s3_after", "dlg_s5_scout",
        "dlg_s6_first", "dlg_s6_recruit", "dlg_s7_device", "dlg_s8_archive",
    }
    if not required_dialogues <= dialogue_ids:
        errors.append("required_dialogue_missing")
    for event in dialogues["events"]:
        variants = event.get("variants", {})
        if set(variants) != {"nayra_orun", "tarek_senn", "aisha_maren", "idris_vael"}:
            errors.append(f"dialogue_missing_watcher_variant:{event['id']}")

    principles = ui.get("principles", {})
    for key in (
        "same_gameplay_all_platforms",
        "same_macro_topology_all_platforms",
        "irreversible_action_requires_explicit_validation",
        "information_request_never_executes_irreversible_action",
        "safe_area_required_on_mobile",
    ):
        if principles.get(key) is not True:
            errors.append(f"ui_principle_required:{key}")
    if principles.get("long_press_required") is not False:
        errors.append("long_press_must_not_be_required")
    if principles.get("hover_required") is not False:
        errors.append("hover_must_not_be_required")
    if int(principles.get("touch_target_min_points", 0)) < 48:
        errors.append("touch_target_too_small")
    if set(ui.get("profiles", {})) != {"phone", "tablet", "desktop", "controller"}:
        errors.append("ui_profiles_incomplete")
    if ui["profiles"]["controller"].get("pointer_dependency") is not False:
        errors.append("controller_must_not_require_pointer")
    if ui["profiles"]["phone"].get("long_press") != "optional_shortcut_only":
        errors.append("phone_long_press_contract_changed")
    required_commands = {
        "MoveCommand", "InteractCommand", "InspectCommand", "UseItemCommand", "CombatCommand",
        "MapCommand", "RecruitCommand", "ExtractCommand", "CancelCommand", "ConfirmCommand",
    }
    if set(ui.get("abstract_commands", [])) != required_commands:
        errors.append("abstract_command_contract_changed")
    project_text = PROJECT.read_text(encoding="utf-8")
    for action in ui.get("existing_runtime_alignment", {}).get("existing_project_actions_reused", []):
        if f"{action}=" not in project_text:
            errors.append(f"missing_existing_project_action:{action}")

    if guardrails.get("status") != "provisional_baseline":
        errors.append("guardrails_must_remain_provisional_before_human_playtest")
    if guardrails.get("real_playtest_required_for_final_balance") is not True:
        errors.append("human_playtest_must_remain_required")
    if int(guardrails.get("tuning_protocol", {}).get("minimum_human_runs_before_first_balance_pass", 0)) < 12:
        errors.append("minimum_human_runs_too_low")
    if int(guardrails.get("tuning_protocol", {}).get("minimum_human_runs_before_large_change", 0)) < 30:
        errors.append("large_change_sample_too_low")
    if guardrails.get("loot", {}).get("s6_kill_premium_allowed") is not False:
        errors.append("s6_kill_premium_must_be_forbidden")
    if guardrails.get("secret_s8", {}).get("synthetic_balance_gate") is not False:
        errors.append("s8_discovery_must_not_be_synthetic_gate")

    privacy = telemetry.get("privacy", {})
    for key in ("personal_identifiers_forbidden", "free_text_forbidden", "device_model_exact_forbidden"):
        if privacy.get(key) is not True:
            errors.append(f"telemetry_privacy_required:{key}")
    expected_telemetry_events = {
        "vs001_expedition_started",
        "vs001_pulse_resolved",
        "vs001_room_entered",
        "vs001_combat_completed",
        "vs001_recruitment_action",
        "vs001_recruitment_resolved",
        "vs001_device_choice",
        "vs001_loot_acquired",
        "vs001_extraction",
    }
    if set(telemetry.get("events", {})) != expected_telemetry_events:
        errors.append("telemetry_event_contract_changed")
    if "session_id" not in telemetry.get("common_fields", []):
        errors.append("telemetry_session_id_missing")
    derived = telemetry.get("derived_metrics", {})
    for metric in (
        "duration_minutes", "light_on_s7_entry", "peak_party_noise", "major_events_per_run",
        "careful_recruitment_success", "force_recruitment_success", "s8_first_run_discovery_rate",
        "kill_vs_recruit_value_gap",
    ):
        if metric not in derived:
            errors.append(f"telemetry_metric_missing:{metric}")

    return errors


def main() -> int:
    errors = audit()
    report = {"system": "les_veilleurs_vs001", "ok": not errors, "errors": errors}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
