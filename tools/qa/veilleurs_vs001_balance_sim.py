from __future__ import annotations

import argparse
import json
import math
import random
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BALANCE_PATH = ROOT / "data" / "veilleurs" / "vs001_balance.json"
GUARDRAILS_PATH = ROOT / "data" / "veilleurs" / "vs001_playtest_guardrails.json"
CAPTURE_WOUNDS_PATH = ROOT / "data" / "capture_wound_rules.json"

CALM_ACTIONS = {
    "cautious_move",
    "normal_move",
    "search",
    "deep_search",
    "complex_treatment",
}

SYNTHETIC_PROFILES = {
    "balanced": [
        "deep_search",
        "normal_move",
        "search",
        "normal_move",
        {"combat_rounds": 5, "noise_action": "violent_combat"},
        "normal_move",
        "deep_search",
        "normal_move",
        "complex_treatment",
        "normal_move",
        "normal_move",
    ],
    "thorough": [
        "deep_search",
        "cautious_move",
        "search",
        "cautious_move",
        "search",
        "cautious_move",
        "cautious_move",
        {"combat_rounds": 5, "noise_action": "violent_combat"},
        "cautious_move",
        "deep_search",
        "cautious_move",
        "complex_treatment",
        "cautious_move",
        "cautious_move",
    ],
    "rush": [
        "fast_move",
        "fast_move",
        {"combat_rounds": 6, "noise_action": "violent_combat"},
        "fast_move",
        "fast_move",
    ],
    "noisy_mistake": [
        "normal_move",
        "sound_trap",
        "normal_move",
        {"combat_rounds": 5, "noise_action": "violent_combat"},
        "normal_move",
        "deep_search",
        "normal_move",
        "normal_move",
    ],
}


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _clamp(value: int, low: int = 0, high: int = 100) -> int:
    return max(low, min(high, value))


def _formula_multiplier(formula: str, fallback: float) -> float:
    marker = "*"
    if marker not in formula:
        return fallback
    tail = formula.split(marker, 1)[1]
    token = tail.split(")", 1)[0].strip()
    try:
        return float(token)
    except ValueError:
        return fallback


def _apply_recruitment_actions(balance: dict, action_ids: list[str]) -> dict:
    state = dict(balance["recruitment_s6"]["initial"])
    mutable = {"fear", "trust", "pain", "aggression", "stability", "restraint"}
    for action_id in action_ids:
        action = balance["recruitment_s6"]["actions"][action_id]
        for key in mutable:
            if key in action:
                state[key] = _clamp(int(state.get(key, 0)) + int(action[key]))
        if "health_ratio_delta" in action:
            state["health_ratio"] = min(1.0, float(state.get("health_ratio", 0.0)) + float(action["health_ratio_delta"]))
    return state


def _capture_score(balance: dict, wounds: dict, state: dict, actor: str) -> int:
    check = balance["recruitment_s6"]["capture_check"]
    wound_bonus = 0
    if bool(check.get("wound_bonus_from_existing_contract", false)):
        wound_bonus = min(
            int(wounds.get("capture_bonus_cap", 20)),
            int(state.get("lost_parts", 0)) * int(wounds.get("capture_bonus_per_lost_part", 0))
            + int(state.get("critical_injuries", 0)) * int(wounds.get("capture_bonus_per_critical_injury", 0)),
        )
    trust_mult = _formula_multiplier(str(check.get("trust_bonus_formula", "")), 0.20)
    fear_mult = _formula_multiplier(str(check.get("fear_penalty_formula", "")), 0.25)
    restraint_mult = _formula_multiplier(str(check.get("restraint_bonus_formula", "")), 0.15)
    stability_mult = _formula_multiplier(str(check.get("stability_bonus_formula", "")), 0.10)
    return (
        int(check.get("base", 0))
        - int(check.get("creature_resistance", 0))
        + wound_bonus
        + int(check.get("actor_bonus", {}).get(actor, 0))
        + math.floor(int(state.get("trust", 0)) * trust_mult)
        - math.floor(max(int(state.get("fear", 0)) - 60, 0) * fear_mult)
        + math.floor(int(state.get("restraint", 0)) * restraint_mult)
        + math.floor(int(state.get("stability", 0)) * stability_mult)
    )


def _exact_capture_probability(balance: dict, wounds: dict, action_ids: list[str], actor: str) -> dict:
    state = _apply_recruitment_actions(balance, action_ids)
    score = _capture_score(balance, wounds, state, actor)
    check = balance["recruitment_s6"]["capture_check"]
    low, high = [int(value) for value in check.get("deterministic_roll_range", [-8, 8])]
    threshold = int(check.get("success_threshold", 60))
    rolls = list(range(low, high + 1))
    success_rolls = [roll for roll in rolls if score + roll >= threshold]
    probability = 100.0 * len(success_rolls) / max(1, len(rolls))
    return {
        "actions": action_ids,
        "actor": actor,
        "state": state,
        "score_before_roll": score,
        "roll_range": [low, high],
        "success_threshold": threshold,
        "success_percent": round(probability, 3),
    }


def _light_state(light_rules: dict, value: int) -> str:
    for state in light_rules.get("states", []):
        if int(state.get("min", 0)) <= value <= int(state.get("max", 100)):
            return str(state.get("id", "stable"))
    return "stable"


def _event_chance(balance: dict, light: int, noise: int) -> int:
    events = balance["events"]
    light_state = _light_state(balance["light"], light)
    light_mod = int(events.get("light_event_mod", {}).get(light_state, 0))
    danger = int(events.get("danger_band_vs001", 0))
    base = int(events.get("base_check_percent", 10))
    noise_mod = math.floor(max(noise - 20, 0) * 0.25)
    return _clamp(base + noise_mod + danger * 3 + light_mod, 5, 45)


def _simulate_profile(balance: dict, profile_name: str, seed: int) -> dict:
    rng = random.Random(seed)
    light_rules = balance["light"]
    noise_rules = balance["noise"]
    light = int(light_rules.get("initial", 82))
    noise = 0
    peak_noise = 0
    major_events = 0
    cooldown = 0
    pulses = 0

    for step in SYNTHETIC_PROFILES[profile_name]:
        pulses += 1
        if isinstance(step, dict):
            rounds = int(step.get("combat_rounds", 0))
            combat_cost = light_rules.get("combat_cost", {})
            light -= min(rounds, int(combat_cost.get("per_combat_cap", 6))) * int(combat_cost.get("per_meaningful_round", 1))
            noise_action = str(step.get("noise_action", "violent_combat"))
            delta = int(noise_rules.get("action_deltas", {}).get(noise_action, 0))
            calm = False
        else:
            action_id = str(step)
            light -= int(light_rules.get("cost_by_action", {}).get(action_id, 0))
            delta = int(noise_rules.get("action_deltas", {}).get(action_id, 0))
            calm = action_id in CALM_ACTIONS

        light = _clamp(light)
        noise = _clamp(noise + delta)
        if calm:
            noise = _clamp(noise - int(noise_rules.get("party_noise_decay_per_calm_pulse", 5)))
        peak_noise = max(peak_noise, noise)

        if cooldown > 0:
            cooldown -= 1
        else:
            chance = _event_chance(balance, light, noise)
            if rng.randrange(100) < chance:
                major_events += 1
                cooldown = int(balance["events"].get("cooldown_major_pulses", 3))

    return {
        "light_on_s7_entry": light,
        "peak_noise": peak_noise,
        "major_events": major_events,
        "pulses": pulses,
    }


def _percentile(values: list[int], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = int(round((len(ordered) - 1) * fraction))
    return float(ordered[index])


def _profile_summary(balance: dict, profile_name: str, runs: int, seed: int) -> dict:
    rows = [_simulate_profile(balance, profile_name, seed + index * 7919) for index in range(runs)]
    result = {"runs": runs}
    for metric in ("light_on_s7_entry", "peak_noise", "major_events", "pulses"):
        values = [int(row[metric]) for row in rows]
        result[metric] = {
            "median": statistics.median(values),
            "mean": round(statistics.fmean(values), 3),
            "p10": _percentile(values, 0.10),
            "p90": _percentile(values, 0.90),
            "min": min(values),
            "max": max(values),
        }
    return result


def _ghoul_invariants(balance: dict) -> dict:
    profiles = balance["ghoul_profiles"]
    standard = profiles["hungry_standard"]
    scout = profiles["hungry_scout"]
    voracious = profiles["voracious_evolved"]
    s = standard["stats"]
    sc = scout["stats"]
    v = voracious["stats"]
    avg_standard = statistics.fmean(s["damage"])
    avg_voracious = statistics.fmean(v["damage"])
    return {
        "scout_hp_below_standard": sc["hp"] < s["hp"],
        "scout_dodge_above_standard": sc["dodge"] > s["dodge"],
        "scout_initiative_above_standard": sc["initiative"] > s["initiative"],
        "scout_perception_above_standard": sc["perception"] > s["perception"],
        "scout_stealth_above_standard": sc["stealth"] > s["stealth"],
        "voracious_hp_above_standard": v["hp"] > s["hp"],
        "voracious_average_damage_above_standard": avg_voracious > avg_standard,
        "voracious_body_threshold_above_standard": float(voracious["body_threshold_multiplier"]) > float(standard["body_threshold_multiplier"]),
        "voracious_flee_threshold_below_standard": float(voracious["flee_threshold"]) < float(standard["flee_threshold"]),
        "scout_flee_threshold_above_standard": float(scout["flee_threshold"]) > float(standard["flee_threshold"]),
    }


def _loot_summary(balance: dict) -> dict:
    loot = balance["loot_vs001"]
    total_or = 0
    useful_items = 0
    for room_id, room in loot.get("rooms", {}).items():
        if room_id == "s6":
            continue
        total_or += int(room.get("or", 0))
        useful_items += len(room.get("guaranteed", []))
        useful_items += len(room.get("seed_result", []))
    rarity_sum = sum(int(value) for value in loot.get("rarity_weights", {}).values())
    return {
        "base_seed_or": total_or,
        "useful_items_without_conditional_trap_salvage": useful_items,
        "rarity_weight_sum": rarity_sum,
        "s6_kill_has_exclusive_valuable_reward": bool(
            loot.get("rooms", {}).get("s6", {}).get("kill_path", {}).get("or", 0)
        ),
    }


def build_report(runs: int = 5000, seed: int = 1001) -> dict:
    balance = _load(BALANCE_PATH)
    guardrails = _load(GUARDRAILS_PATH)
    wounds = _load(CAPTURE_WOUNDS_PATH)

    recruitment_guard = guardrails["recruitment"]
    recruitment = {
        "careful_sequence": _exact_capture_probability(
            balance,
            wounds,
            recruitment_guard["careful_sequence"]["actions"],
            recruitment_guard["careful_sequence"]["capture_actor"],
        ),
        "immediate_force": _exact_capture_probability(
            balance,
            wounds,
            recruitment_guard["immediate_force"]["actions"],
            recruitment_guard["immediate_force"]["capture_actor"],
        ),
        "coercive_control": _exact_capture_probability(
            balance,
            wounds,
            recruitment_guard["coercive_control"]["actions"],
            recruitment_guard["coercive_control"]["capture_actor"],
        ),
    }

    profiles = {
        name: _profile_summary(balance, name, runs, seed + offset * 1000003)
        for offset, name in enumerate(SYNTHETIC_PROFILES)
    }
    ghoul_invariants = _ghoul_invariants(balance)
    loot = _loot_summary(balance)

    errors: list[str] = []
    light_target = [int(x) for x in guardrails["light"]["target"]]
    noise_target = [int(x) for x in guardrails["noise"]["target"]]
    event_target = [int(x) for x in guardrails["events"]["synthetic_major_events_per_run_target"]]
    for profile_name in guardrails["light"]["synthetic_profiles_required_in_target"]:
        median_light = float(profiles[profile_name]["light_on_s7_entry"]["median"])
        if not light_target[0] <= median_light <= light_target[1]:
            errors.append(f"light_target:{profile_name}:{median_light}")
    for profile_name in guardrails["noise"]["synthetic_profiles_required_in_target"]:
        median_noise = float(profiles[profile_name]["peak_noise"]["median"])
        if not noise_target[0] <= median_noise <= noise_target[1]:
            errors.append(f"noise_target:{profile_name}:{median_noise}")
        median_events = float(profiles[profile_name]["major_events"]["median"])
        if not event_target[0] <= median_events <= event_target[1]:
            errors.append(f"event_target:{profile_name}:{median_events}")

    for scenario in ("careful_sequence", "immediate_force"):
        target = [float(x) for x in recruitment_guard[scenario]["target_percent"]]
        probability = float(recruitment[scenario]["success_percent"])
        if not target[0] <= probability <= target[1]:
            errors.append(f"recruitment_target:{scenario}:{probability}")
    if recruitment["careful_sequence"]["success_percent"] <= recruitment["immediate_force"]["success_percent"]:
        errors.append("recruitment_careful_must_outperform_force")

    required_invariants = set(guardrails["ghoul_profiles"]["structural_invariants"])
    for invariant in required_invariants:
        if not bool(ghoul_invariants.get(invariant, False)):
            errors.append(f"ghoul_invariant:{invariant}")

    if loot["base_seed_or"] != int(guardrails["loot"]["base_seed_or"]):
        errors.append(f"loot_or:{loot['base_seed_or']}")
    useful_target = [int(x) for x in guardrails["loot"]["useful_items_without_conditional_trap_salvage"]]
    if not useful_target[0] <= loot["useful_items_without_conditional_trap_salvage"] <= useful_target[1]:
        errors.append(f"loot_items:{loot['useful_items_without_conditional_trap_salvage']}")
    if loot["rarity_weight_sum"] != 100:
        errors.append(f"rarity_weight_sum:{loot['rarity_weight_sum']}")
    if loot["s6_kill_has_exclusive_valuable_reward"]:
        errors.append("s6_kill_premium")

    return {
        "system": "les_veilleurs_vs001_synthetic_balance",
        "status": "synthetic_guardrail_not_human_playtest",
        "runs_per_profile": runs,
        "seed": seed,
        "ok": not errors,
        "errors": errors,
        "recruitment": recruitment,
        "profiles": profiles,
        "ghoul_invariants": ghoul_invariants,
        "loot": loot,
        "human_playtest_still_required": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=5000)
    parser.add_argument("--seed", type=int, default=1001)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    report = build_report(max(100, args.runs), args.seed)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    print(text)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text + "\n", encoding="utf-8")
    return 1 if args.strict and not report["ok"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
