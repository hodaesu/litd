#!/usr/bin/env python3
"""Generate the storyboard, shot list and timed animatic manifest for Le Dernier Vol."""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "data/cinematics/opening_bird_intro.json"
DEFAULT_OUTPUT = ROOT / "local/cinematics/opening_bird_intro/storyboard"


def load_contract() -> dict:
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


def build_storyboard(contract: dict) -> dict:
    lore = {entry["id"]: entry for entry in contract["lore_route"]}
    elapsed = 0.0
    shots: list[dict] = []
    for index, waypoint in enumerate(contract["runtime_waypoints"], start=1):
        duration = float(waypoint["duration"])
        lore_entry = lore.get(waypoint["id"], {})
        shot = {
            "shot": index,
            "id": waypoint["id"],
            "start_seconds": round(elapsed, 3),
            "duration_seconds": duration,
            "end_seconds": round(elapsed + duration, 3),
            "camera_position": waypoint["position"],
            "look_at": waypoint["look_at"],
            "lore_meaning": lore_entry.get("meaning", ""),
            "world_action": lore_entry.get("world_action", ""),
            "status": "proxy",
            "human_approval": False,
        }
        shots.append(shot)
        elapsed += duration
    tail = [
        ("last_breath", 2.4, "Le souffle de l'oiseau se confond avec le vent."),
        ("heroes_approach", 3.85, "Les héros entrent dans le champ par leurs postures."),
        ("hero_hand_occlusion", 0.55, "La main masque entièrement le regard."),
        ("exploration_handoff", 1.2, "La caméra rejoint l'axe d'exploration sans coupe de scène."),
    ]
    for shot_id, duration, action in tail:
        shots.append({
            "shot": len(shots) + 1,
            "id": shot_id,
            "start_seconds": round(elapsed, 3),
            "duration_seconds": duration,
            "end_seconds": round(elapsed + duration, 3),
            "camera_position": None,
            "look_at": None,
            "lore_meaning": "",
            "world_action": action,
            "status": "proxy",
            "human_approval": False,
        })
        elapsed += duration
    return {
        "version": 1,
        "cinematic_id": contract["id"],
        "title": contract["title"],
        "duration_seconds": round(elapsed, 3),
        "point_of_view": contract["point_of_view"]["camera"],
        "shots": shots,
        "review_required": True,
    }


def render_html(plan: dict) -> str:
    rows = []
    for shot in plan["shots"]:
        rows.append(
            "<tr>"
            f"<td>{shot['shot']:02d}</td>"
            f"<td>{html.escape(shot['id'])}</td>"
            f"<td>{shot['start_seconds']:.2f}–{shot['end_seconds']:.2f}s</td>"
            f"<td>{html.escape(shot['world_action'] or 'Mouvement de caméra / transition')}</td>"
            f"<td>{html.escape(shot['lore_meaning'])}</td>"
            "<td>À valider</td>"
            "</tr>"
        )
    return """<!doctype html>
<html lang="fr"><meta charset="utf-8"><title>Le Dernier Vol — Storyboard</title>
<style>
body{background:#151419;color:#e7dfd0;font:16px system-ui;margin:32px}
h1{color:#d5b26c}table{border-collapse:collapse;width:100%}
th,td{border:1px solid #554b3d;padding:10px;vertical-align:top}
th{background:#26232a;color:#d5b26c}tr:nth-child(even){background:#1d1b21}
</style>
<h1>Le Dernier Vol</h1>
<p>Storyboard automatique — durée %(duration).2f secondes — caméra subjective continue.</p>
<table><thead><tr><th>Plan</th><th>Étape</th><th>Temps</th><th>Action visible</th><th>Lore transmis</th><th>Validation</th></tr></thead>
<tbody>%(rows)s</tbody></table></html>
""" % {"duration": plan["duration_seconds"], "rows": "\n".join(rows)}


def write_outputs(output: Path) -> dict:
    plan = build_storyboard(load_contract())
    output.mkdir(parents=True, exist_ok=True)
    (output / "storyboard.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (output / "storyboard.html").write_text(render_html(plan), encoding="utf-8")
    return plan


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    plan = build_storyboard(load_contract())
    if args.check:
        assert plan["point_of_view"] == "first_person_bird"
        assert plan["shots"][-1]["id"] == "exploration_handoff"
        assert all(shot["duration_seconds"] > 0 for shot in plan["shots"])
        print(f"OPENING_STORYBOARD_OK {len(plan['shots'])} shots {plan['duration_seconds']:.2f}s")
        return 0
    write_outputs(args.output)
    print(f"OPENING_STORYBOARD_WRITTEN {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
