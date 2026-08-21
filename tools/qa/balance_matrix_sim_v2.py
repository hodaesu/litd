#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any

from tools.qa import balance_matrix_sim as base

ROOT = Path(__file__).resolve().parents[2]
BRIDGE_PATH = Path("scripts/world/ashlands_combat_bridge.gd")
NORMAL_ENEMY_IDS = [1, 8, 10]

_SETUP_RE = re.compile(
    r'"(?P<id>[^"]+)"\s*:\s*_setup_enemy\(e,"(?P<name>[^"]+)",'
    r'(?P<hp>\d+),\[(?P<damage_min>\d+),(?P<damage_max>\d+)\],'
    r'(?P<fear>\d+),"(?P<signature>[^"]*)"\)'
)


def _chapter_number(encounter_id: str) -> int | None:
    match = re.match(r"c(?P<number>\d{2})_", encounter_id)
    if match is None:
        return None
    return int(match.group("number"))


def _extract_setup_profiles(block: str) -> list[dict[str, Any]]:
    profiles: list[dict[str, Any]] = []
    for match in _SETUP_RE.finditer(block):
        encounter_id = match.group("id")
        chapter = _chapter_number(encounter_id)
        if chapter is None:
            continue
        profiles.append(
            {
                "encounter_id": encounter_id,
                "chapter_number": chapter,
                "name": match.group("name"),
                "hp": int(match.group("hp")),
                "damage": [int(match.group("damage_min")), int(match.group("damage_max"))],
                "fear": int(match.group("fear")),
                "signature": match.group("signature"),
            }
        )
    return profiles


def extract_runtime_campaign_profiles(root: Path = ROOT) -> dict[str, Any]:
    text = (root / BRIDGE_PATH).read_text(encoding="utf-8")
    miniboss_marker = 'if encounter_type == "miniboss"'
    boss_marker = 'if encounter_type == "boss"'
    scaling_marker = "level_scaling_policy.apply_campaign_scaling"
    miniboss_start = text.index(miniboss_marker)
    boss_start = text.index(boss_marker, miniboss_start + len(miniboss_marker))
    scaling_start = text.index(scaling_marker, boss_start + len(boss_marker))
    minibosses = _extract_setup_profiles(text[miniboss_start:boss_start])
    bosses = _extract_setup_profiles(text[boss_start:scaling_start])
    return {
        "source": str(BRIDGE_PATH),
        "normal_enemy_ids": list(NORMAL_ENEMY_IDS),
        "minibosses": minibosses,
        "bosses": bosses,
    }


def _average_profile(profiles: list[dict[str, Any]]) -> dict[str, float]:
    count = max(1, len(profiles))
    return {
        "hp": sum(float(row["hp"]) for row in profiles) / count,
        "damage_min": sum(float(row["damage"][0]) for row in profiles) / count,
        "damage_max": sum(float(row["damage"][1]) for row in profiles) / count,
        "fear": sum(float(row["fear"]) for row in profiles) / count,
    }


def _profiles_by_chapter(profiles: dict[str, Any], kind: str) -> dict[int, list[dict[str, Any]]]:
    rows: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for profile in profiles.get(kind, []):
        rows[int(profile["chapter_number"])].append(profile)
    return dict(rows)


def _live_campaign_pack_factory(root: Path):
    runtime_profiles = extract_runtime_campaign_profiles(root)
    minibosses = _profiles_by_chapter(runtime_profiles, "minibosses")
    bosses = _profiles_by_chapter(runtime_profiles, "bosses")
    enemy_templates = {
        int(row["id"]): row
        for row in json.loads((root / "data/enemies.json").read_text(encoding="utf-8"))
    }

    def campaign_pack(
        level: int,
        chapter_number: int,
        encounter_type: str,
        cycle: int,
        rules: dict[str, Any],
        matrix_config: dict[str, Any],
        enemies: list[dict[str, Any]],
        ngplus: dict[str, Any],
    ) -> list[dict[str, float]]:
        del matrix_config, enemies
        raw_templates: list[dict[str, float]] = []
        if encounter_type == "normal":
            for enemy_id in NORMAL_ENEMY_IDS:
                row = enemy_templates[enemy_id]
                raw_templates.append(
                    {
                        "hp": float(row.get("hp", 48)),
                        "damage_min": float(row.get("damage", [6, 10])[0]),
                        "damage_max": float(row.get("damage", [6, 10])[1]),
                        "fear": float(row.get("fear", 4)),
                    }
                )
        else:
            chapter_profiles = minibosses.get(chapter_number, []) if encounter_type == "miniboss" else bosses.get(chapter_number, [])
            if chapter_profiles:
                raw_templates.append(_average_profile(chapter_profiles))
            else:
                fallback_id = 30 if encounter_type == "miniboss" else 38
                row = enemy_templates[fallback_id]
                raw_templates.append(
                    {
                        "hp": float(row.get("hp", 48)),
                        "damage_min": float(row.get("damage", [6, 10])[0]),
                        "damage_max": float(row.get("damage", [6, 10])[1]),
                        "fear": float(row.get("fear", 4)),
                    }
                )

        reference = base.campaign_reference_level(chapter_number, encounter_type)
        delta = level - reference
        hp_multiplier = base._clamp(1.0 + delta * 0.045, 0.50, 2.75)
        damage_multiplier = base._clamp(1.0 + delta * 0.03, 0.65, 2.00)
        fear_multiplier = base._clamp(1.0 + delta * 0.018, 0.70, 1.65)

        combat_balance = rules.get("combat_balance", {})
        encounter_hp = 1.0
        encounter_damage = 1.0
        if encounter_type == "miniboss":
            encounter_hp = float(combat_balance.get("campaign_miniboss_hp_multiplier", 1.20))
            encounter_damage = float(combat_balance.get("campaign_miniboss_damage_multiplier", 1.0))
        elif encounter_type == "boss":
            encounter_hp = float(combat_balance.get("campaign_boss_hp_multiplier", 1.50))
            encounter_damage = float(combat_balance.get("campaign_boss_damage_multiplier", 1.05))

        cycle_hp, cycle_damage, cycle_fear = base._ngplus_multipliers(cycle, ngplus)
        pack: list[dict[str, float]] = []
        for template in raw_templates:
            hp = float(template["hp"]) * hp_multiplier * encounter_hp * cycle_hp
            damage = ((float(template["damage_min"]) + float(template["damage_max"])) / 2.0) * damage_multiplier * encounter_damage * cycle_damage
            fear = float(template["fear"]) * fear_multiplier * cycle_fear
            pack.append({"hp": hp, "max_hp": hp, "damage": damage, "fear": fear})
        return pack

    return campaign_pack, runtime_profiles


def simulate_matrix(root: Path = ROOT, **kwargs: Any) -> base.MatrixResult:
    campaign_pack, runtime_profiles = _live_campaign_pack_factory(root)
    original = base._campaign_pack
    base._campaign_pack = campaign_pack
    try:
        result = base.simulate_matrix(root, **kwargs)
    finally:
        base._campaign_pack = original

    result.payload["model_version"] = 4
    result.payload["contracts"]["campaign_runtime_profiles_live"] = True
    result.payload["contracts"]["campaign_profile_source"] = str(BRIDGE_PATH)
    result.payload["campaign_runtime_profiles"] = runtime_profiles

    boss_chapters = sorted({int(row["chapter_number"]) for row in runtime_profiles["bosses"]})
    result.payload["coverage"]["campaign_runtime_boss_chapters"] = boss_chapters
    result.payload["coverage"]["campaign_runtime_boss_profile_count"] = len(runtime_profiles["bosses"])
    result.payload["coverage"]["campaign_runtime_miniboss_profile_count"] = len(runtime_profiles["minibosses"])
    if boss_chapters != list(range(1, 11)):
        alert = {
            "severity": "high",
            "code": "campaign_runtime_boss_profile_coverage",
            "detail": f"expected chapters 1..10, got {boss_chapters}",
        }
        result.alerts.append(alert)
        result.payload["alerts"] = result.alerts
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Runtime-aligned full LITD balance matrix")
    parser.add_argument("--mode", choices=["quick", "exhaustive"], default="quick")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--samples-per-cell", type=int, default=None)
    parser.add_argument("--report", type=Path, default=ROOT / "reports/balance-matrix.json")
    parser.add_argument("--csv", type=Path, default=ROOT / "reports/balance-matrix.csv")
    parser.add_argument("--raw-csv-gz", type=Path, default=ROOT / "reports/balance-matrix-cells.csv.gz")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    args.raw_csv_gz.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(args.raw_csv_gz, "wt", encoding="utf-8", newline="") as raw_handle:
        raw_writer = csv.DictWriter(raw_handle, fieldnames=base.RAW_FIELDS, extrasaction="ignore")
        raw_writer.writeheader()
        result = simulate_matrix(
            ROOT,
            mode=args.mode,
            seed=args.seed,
            samples_per_cell=args.samples_per_cell,
            raw_sink=raw_writer.writerow,
        )

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result.payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    base.write_summary_csv(result, args.csv)

    coverage = result.payload["coverage"]
    print(
        "BALANCE_MATRIX_V2",
        f"mode={args.mode}",
        f"levels={coverage['level_count']}",
        f"all_compositions={coverage['analytical_composition_count']}",
        f"chapters={coverage['campaign_chapter_count']}",
        f"boss_profiles={coverage['campaign_runtime_boss_profile_count']}",
        f"dungeons={coverage['dungeon_count']}",
        f"mc_battles={coverage['monte_carlo_battles']}",
    )
    print("BOSS_CHAPTERS", json.dumps(coverage["campaign_runtime_boss_chapters"]))
    print("CYCLES", json.dumps(coverage["analytical_cycles"]))
    print("DUNGEONS", json.dumps(coverage["dungeon_ids"], ensure_ascii=False))
    for alert in result.alerts:
        print(f"ALERT {alert['severity'].upper()} {alert['code']}: {alert['detail']}")
    print(f"REPORT {args.report}")
    if args.strict and any(alert["severity"] == "high" for alert in result.alerts):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
