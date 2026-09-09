#!/usr/bin/env python3
"""Analyse locale et déterministe d'une session developer-selftest Les Veilleurs.

Le script ne transforme jamais une télémétrie en validation joueur. Il produit des
candidats de priorité P0/P1/P2 à examiner, un résumé chronologique et des agrégats
utiles pour le triage de la verticale Chapitre I.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

PRIORITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "REVIEW": 3}


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _explicit_priority(text: str) -> str | None:
    match = re.search(r"(?:^|\b)(P[0-2])(?:\b|\s*[:\-])", text.upper())
    return match.group(1) if match else None


def _event_counter(events: list[dict[str, Any]], kind: str, key: str) -> Counter[str]:
    result: Counter[str] = Counter()
    for event in events:
        if str(event.get("type", "")) != kind:
            continue
        value = str(event.get(key, "") or "unknown")
        result[value] += 1
    return result


def _state_snapshots(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for event in events:
        if str(event.get("type", "")) not in {"state_snapshot", "state_changed"}:
            continue
        data = event.get("data", {})
        if isinstance(data, dict):
            rows.append(data)
    return rows


def _append_candidate(
    candidates: list[dict[str, Any]],
    priority: str,
    kind: str,
    reason: str,
    *,
    evidence: dict[str, Any] | None = None,
) -> None:
    candidates.append(
        {
            "priority_candidate": priority,
            "kind": kind,
            "reason": reason,
            "evidence": evidence or {},
            "requires_human_confirmation": True,
        }
    )


def analyze(session_dir: Path) -> dict[str, Any]:
    telemetry_path = session_dir / "developer_selftest_telemetry.json"
    session_path = session_dir / "session.json"

    session: dict[str, Any] = {}
    if session_path.is_file():
        try:
            session = _load_json(session_path)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            session = {}

    if not telemetry_path.is_file():
        return {
            "schema_version": 1,
            "mode": "developer_selftest_analysis",
            "source_session": session_dir.name,
            "telemetry_present": False,
            "human_gate_promotion_allowed": False,
            "priority_candidates": [
                {
                    "priority_candidate": "P0",
                    "kind": "telemetry_missing",
                    "reason": "La session n'a produit aucun fichier de télémétrie exploitable.",
                    "evidence": {},
                    "requires_human_confirmation": True,
                }
            ],
            "summary": {},
            "source_analysis_flags": [],
        }

    telemetry = _load_json(telemetry_path)
    events_raw = telemetry.get("events", [])
    events = [row for row in events_raw if isinstance(row, dict)]
    summary = telemetry.get("summary", {}) if isinstance(telemetry.get("summary"), dict) else {}
    performance = summary.get("performance", {}) if isinstance(summary.get("performance"), dict) else {}
    source_flags = telemetry.get("analysis_flags", [])
    if not isinstance(source_flags, list):
        source_flags = []

    candidates: list[dict[str, Any]] = []

    exit_code = session.get("game_exit_code")
    if exit_code is not None and int(exit_code) != 0:
        _append_candidate(
            candidates,
            "P0",
            "nonzero_game_exit",
            f"Le jeu s'est terminé avec le code {exit_code}.",
            evidence={"game_exit_code": exit_code},
        )

    completed = bool(telemetry.get("completed", False))
    elapsed_seconds = _number(telemetry.get("elapsed_seconds"))
    elapsed_minutes = elapsed_seconds / 60.0
    if not completed:
        _append_candidate(
            candidates,
            "P1",
            "selftest_incomplete",
            "La verticale développeur n'a pas été parcourue jusqu'à sa dernière étape ; vérifier s'il s'agit d'un abandon volontaire ou d'un blocage.",
            evidence={"elapsed_minutes": round(elapsed_minutes, 2), "current_step": telemetry.get("current_step")},
        )

    manual_issues = [e for e in events if str(e.get("type", "")) == "issue"]
    for issue in manual_issues:
        note = str(issue.get("note", "Problème noté manuellement."))
        priority = _explicit_priority(note) or "REVIEW"
        _append_candidate(
            candidates,
            priority,
            "manual_issue",
            note,
            evidence={
                "elapsed_seconds": issue.get("elapsed_seconds"),
                "step_id": issue.get("step_id"),
                "screen": issue.get("screen"),
            },
        )

    hesitation_events = [e for e in events if str(e.get("type", "")) == "hesitation_started"]
    hesitation_count = len(hesitation_events)
    hesitation_by_step = _event_counter(events, "hesitation_started", "step_id")
    hesitation_by_screen = _event_counter(events, "hesitation_started", "screen")
    if hesitation_count >= 6:
        _append_candidate(
            candidates,
            "P1",
            "repeated_hesitation",
            f"{hesitation_count} hésitations automatiques ont été détectées pendant la session.",
            evidence={
                "by_step": dict(hesitation_by_step.most_common()),
                "by_screen": dict(hesitation_by_screen.most_common()),
            },
        )
    elif hesitation_count >= 3:
        _append_candidate(
            candidates,
            "P2",
            "repeated_hesitation",
            f"{hesitation_count} hésitations automatiques ont été détectées ; vérifier la clarté des écrans concernés.",
            evidence={
                "by_step": dict(hesitation_by_step.most_common()),
                "by_screen": dict(hesitation_by_screen.most_common()),
            },
        )

    samples = int(_number(performance.get("samples")))
    fps_average = _number(performance.get("fps_average"))
    fps_min = _number(performance.get("fps_min"))
    severe_samples = int(_number(performance.get("severe_fps_samples_under_30")))
    low_samples = int(_number(performance.get("low_fps_samples_under_45")))
    if samples > 0:
        if fps_average < 30 or severe_samples >= 5:
            _append_candidate(
                candidates,
                "P1",
                "performance_severe",
                f"Performance insuffisante pour le playtest : moyenne {fps_average:.1f} FPS, minimum {fps_min:.1f} FPS.",
                evidence={"samples": samples, "under_30": severe_samples, "under_45": low_samples},
            )
        elif fps_average < 45 or severe_samples > 0 or low_samples >= max(3, samples // 10):
            _append_candidate(
                candidates,
                "P2",
                "performance_review",
                f"Des baisses de performance sont visibles : moyenne {fps_average:.1f} FPS, minimum {fps_min:.1f} FPS.",
                evidence={"samples": samples, "under_30": severe_samples, "under_45": low_samples},
            )

    target = telemetry.get("target_duration_minutes", [30, 45])
    if isinstance(target, list) and len(target) >= 2:
        target_min = _number(target[0], 30)
        target_max = _number(target[1], 45)
        if completed and elapsed_minutes > max(target_max * 1.33, target_max + 10):
            _append_candidate(
                candidates,
                "P1",
                "session_too_long",
                f"La session dure {elapsed_minutes:.1f} min pour une cible {target_min:.0f}–{target_max:.0f} min.",
                evidence={"elapsed_minutes": round(elapsed_minutes, 2)},
            )
        elif completed and (elapsed_minutes < target_min or elapsed_minutes > target_max):
            _append_candidate(
                candidates,
                "P2",
                "session_pacing",
                f"La durée {elapsed_minutes:.1f} min sort de la cible {target_min:.0f}–{target_max:.0f} min.",
                evidence={"elapsed_minutes": round(elapsed_minutes, 2)},
            )

    screen_seconds = summary.get("screen_seconds", {}) if isinstance(summary.get("screen_seconds"), dict) else {}
    step_seconds = summary.get("step_seconds", {}) if isinstance(summary.get("step_seconds"), dict) else {}
    slowest_screens = sorted(
        ((str(k), _number(v)) for k, v in screen_seconds.items()),
        key=lambda row: row[1],
        reverse=True,
    )[:5]
    slowest_steps = sorted(
        ((str(k), _number(v)) for k, v in step_seconds.items()),
        key=lambda row: row[1],
        reverse=True,
    )[:5]

    states = _state_snapshots(events)
    first_state = states[0] if states else {}
    last_state = states[-1] if states else {}
    max_battle_rounds = max((int(_number(row.get("battle_rounds"))) for row in states), default=0)
    min_alive_heroes = min((int(_number(row.get("alive_heroes"))) for row in states), default=0)

    candidates.sort(key=lambda row: PRIORITY_ORDER.get(str(row.get("priority_candidate")), 99))
    counts = Counter(str(row.get("priority_candidate", "REVIEW")) for row in candidates)

    result = {
        "schema_version": 1,
        "mode": "developer_selftest_analysis",
        "source_session": session_dir.name,
        "telemetry_present": True,
        "telemetry_schema_version": telemetry.get("schema_version"),
        "human_gate_promotion_allowed": False,
        "completed": completed,
        "elapsed_minutes": round(elapsed_minutes, 2),
        "priority_candidate_counts": dict(counts),
        "priority_candidates": candidates,
        "summary": {
            "hesitation_count": hesitation_count,
            "manual_issue_count": len(manual_issues),
            "hesitations_by_step": dict(hesitation_by_step.most_common()),
            "hesitations_by_screen": dict(hesitation_by_screen.most_common()),
            "slowest_screens_seconds": {k: round(v, 2) for k, v in slowest_screens},
            "slowest_steps_seconds": {k: round(v, 2) for k, v in slowest_steps},
            "performance": performance,
            "state_change_count": summary.get("state_change_count", 0),
            "input_events": summary.get("input_events", 0),
            "max_battle_rounds": max_battle_rounds,
            "minimum_alive_heroes_observed": min_alive_heroes,
            "initial_resources": {key: first_state.get(key) for key in ("gold", "essence", "light", "supplies")},
            "final_resources": {key: last_state.get(key) for key in ("gold", "essence", "light", "supplies")},
        },
        "source_analysis_flags": source_flags,
        "interpretation_rule": "Ces priorités sont des candidats de triage technique/UX. Elles ne valident ni n'échouent automatiquement un gate joueur.",
    }
    return result


def _markdown(analysis: dict[str, Any]) -> str:
    lines = [
        "# LITD : Les Veilleurs — analyse automatique developer-selftest",
        "",
        f"Session : `{analysis.get('source_session', 'unknown')}`  ",
        f"Complétée : **{'oui' if analysis.get('completed') else 'non'}**  ",
        f"Durée : **{analysis.get('elapsed_minutes', 0)} min**  ",
        "",
        "> Analyse de triage uniquement : aucun gate joueur n'est promu automatiquement.",
        "",
        "## Candidats de priorité",
        "",
    ]
    candidates = analysis.get("priority_candidates", [])
    if not candidates:
        lines.append("- Aucun candidat automatique détecté. Cela ne signifie pas que la session est validée.")
    else:
        for item in candidates:
            lines.append(
                f"- **{item.get('priority_candidate', 'REVIEW')} · {item.get('kind', 'review')}** — {item.get('reason', '')}"
            )

    summary = analysis.get("summary", {}) if isinstance(analysis.get("summary"), dict) else {}
    lines += [
        "",
        "## Résumé de session",
        "",
        f"- Hésitations détectées : {summary.get('hesitation_count', 0)}",
        f"- Problèmes notés manuellement : {summary.get('manual_issue_count', 0)}",
        f"- Entrées joueur : {summary.get('input_events', 0)}",
        f"- Changements d'état : {summary.get('state_change_count', 0)}",
        f"- Nombre maximal de rounds de combat observé : {summary.get('max_battle_rounds', 0)}",
        f"- Minimum de héros vivants observé : {summary.get('minimum_alive_heroes_observed', 0)}",
        "",
        "## Écrans les plus longs",
        "",
    ]
    for name, seconds in (summary.get("slowest_screens_seconds", {}) or {}).items():
        lines.append(f"- `{name}` : {float(seconds) / 60.0:.1f} min")
    if not summary.get("slowest_screens_seconds"):
        lines.append("- Pas de donnée.")

    lines += ["", "## Étapes les plus longues", ""]
    for name, seconds in (summary.get("slowest_steps_seconds", {}) or {}).items():
        lines.append(f"- `{name}` : {float(seconds) / 60.0:.1f} min")
    if not summary.get("slowest_steps_seconds"):
        lines.append("- Pas de donnée.")

    perf = summary.get("performance", {}) if isinstance(summary.get("performance"), dict) else {}
    lines += [
        "",
        "## Performance",
        "",
        f"- FPS moyen : {float(perf.get('fps_average', 0) or 0):.1f}",
        f"- FPS minimum : {float(perf.get('fps_min', 0) or 0):.1f}",
        f"- Échantillons <45 FPS : {int(perf.get('low_fps_samples_under_45', 0) or 0)}",
        f"- Échantillons <30 FPS : {int(perf.get('severe_fps_samples_under_30', 0) or 0)}",
        "",
    ]
    return "\n".join(lines) + "\n"


def _write_outputs(session_dir: Path, analysis: dict[str, Any]) -> tuple[Path, Path]:
    json_path = session_dir / "developer_selftest_analysis.json"
    md_path = session_dir / "developer_selftest_analysis.md"
    json_path.write_text(json.dumps(analysis, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text(_markdown(analysis), encoding="utf-8")
    return json_path, md_path


def _check() -> int:
    sample = {
        "schema_version": 1,
        "source_session": "check",
        "completed": True,
        "elapsed_minutes": 36.0,
        "priority_candidates": [],
        "summary": {"performance": {}},
    }
    rendered = _markdown(sample)
    if "analyse automatique" not in rendered or "aucun gate joueur" not in rendered:
        print("DEVELOPER_SELFTEST_ANALYZER_CHECK_FAILED")
        return 2
    print("DEVELOPER_SELFTEST_ANALYZER_CHECK_OK")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", nargs="?", help="Dossier local/playtests/<session> à analyser.")
    parser.add_argument("--check", action="store_true", help="Vérifie uniquement la cohérence du script.")
    args = parser.parse_args()

    if args.check:
        return _check()
    if not args.session:
        parser.error("session est requis hors --check")

    session_dir = Path(args.session).resolve()
    if not session_dir.is_dir():
        print(f"DEVELOPER_SELFTEST_ANALYSIS_SESSION_MISSING={session_dir}")
        return 2

    try:
        analysis = analyze(session_dir)
        json_path, md_path = _write_outputs(session_dir, analysis)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        print(f"DEVELOPER_SELFTEST_ANALYSIS_FAILED={exc}")
        return 2

    print(f"DEVELOPER_SELFTEST_ANALYSIS_JSON={json_path}")
    print(f"DEVELOPER_SELFTEST_ANALYSIS_MD={md_path}")
    counts = analysis.get("priority_candidate_counts", {})
    print(f"DEVELOPER_SELFTEST_PRIORITY_CANDIDATES={json.dumps(counts, ensure_ascii=False, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
