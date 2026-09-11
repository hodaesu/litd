#!/usr/bin/env python3
"""Render human-readable Pull Request summaries from LITD design comparisons.

The rendered comment is informational. Merge blocking authority remains the
Measurement Provenance CI gate, never the comment itself.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

MARKER = "<!-- litd-design-telemetry-summary -->"


def _fmt_number(value: Any) -> str:
    if value is None:
        return "—"
    if isinstance(value, bool):
        return str(value).lower()
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)
    if abs(number) < 1:
        return f"{number:.3f}".rstrip("0").rstrip(".")
    return f"{number:.2f}".rstrip("0").rstrip(".")


def _target_label(rule: dict[str, Any]) -> str:
    kind = rule.get("type")
    if kind == "window":
        return f"{_fmt_number(rule.get('min'))}–{_fmt_number(rule.get('max'))}"
    if kind == "max":
        return f"≤ {_fmt_number(rule.get('max'))}"
    if kind == "min":
        return f"≥ {_fmt_number(rule.get('min'))}"
    return "—"


def _metric_rows(comparisons: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for comparison in comparisons:
        if comparison.get("status") != "BASELINE_COMPARISON_COMPLETE":
            continue
        for report in comparison.get("reports", []):
            evaluation = report.get("design_target_evaluation", {})
            for item in evaluation.get("evaluations", []):
                verdict = item.get("verdict")
                if verdict not in {"CLOSER_TO_TARGET", "FARTHER_FROM_TARGET", "IN_TARGET", "UNCHANGED_DISTANCE"}:
                    continue
                baseline = item.get("baseline")
                current = item.get("current")
                delta = None
                if isinstance(baseline, (int, float)) and not isinstance(baseline, bool) and isinstance(current, (int, float)) and not isinstance(current, bool):
                    delta = float(current) - float(baseline)
                rows.append({
                    "metric": item.get("metric", "<unknown>"),
                    "baseline": baseline,
                    "current": current,
                    "delta": delta,
                    "target": _target_label(item.get("target", {})),
                    "verdict": verdict,
                    "severity": item.get("severity", "medium"),
                    "provisional": bool(item.get("provisional", False)),
                })
    priority = {"FARTHER_FROM_TARGET": 0, "CLOSER_TO_TARGET": 1, "IN_TARGET": 2, "UNCHANGED_DISTANCE": 3}
    severity = {"high": 0, "medium": 1, "low": 2}
    rows.sort(key=lambda row: (priority.get(row["verdict"], 9), severity.get(str(row["severity"]), 9), str(row["metric"])))
    return rows


def build_pr_summary(comparisons: list[dict[str, Any]], *, upstream_run_id: str | int | None = None) -> str:
    completed = [row for row in comparisons if row.get("status") == "BASELINE_COMPARISON_COMPLETE"]
    no_baseline = [row for row in comparisons if row.get("status") == "NO_COMPATIBLE_BASELINE"]
    blocking = sum(int(row.get("summary", {}).get("blocking_regressions", 0)) for row in completed)
    farther = sum(int(row.get("summary", {}).get("farther_from_target", 0)) for row in completed)
    closer = sum(int(row.get("summary", {}).get("closer_to_target", 0)) for row in completed)
    in_target = sum(int(row.get("summary", {}).get("in_target", 0)) for row in completed)

    if blocking:
        headline = "⛔ Régression design critique détectée — le gate CI doit bloquer la PR."
    elif farther:
        headline = "⚠️ Régression(s) design non bloquante(s) détectée(s), sans recul critique."
    elif closer:
        headline = "✅ Les mesures évoluent vers les cibles de design, sans régression critique."
    elif in_target:
        headline = "✅ Les mesures comparables restent dans les cibles de design."
    elif no_baseline:
        headline = "ℹ️ Aucune baseline compatible : comparaison historique impossible pour ce run."
    else:
        headline = "ℹ️ Aucune métrique design comparable exploitable sur ce run."

    baseline_ids = sorted({str(row.get("baseline_run_id")) for row in completed if row.get("baseline_run_id")})
    current_ids = sorted({str(row.get("current_run_id")) for row in comparisons if row.get("current_run_id")})
    lines = [
        MARKER,
        "## Diagnostic design LITD",
        "",
        headline,
        "",
        f"**Gate bloquant :** {'OUI' if blocking else 'NON'}  ",
        f"**Baseline(s) :** {', '.join(baseline_ids) if baseline_ids else 'aucune compatible'}  ",
        f"**Run(s) mesuré(s) :** {', '.join(current_ids) if current_ids else (str(upstream_run_id) if upstream_run_id else '—')}  ",
        f"**Résumé :** {in_target} dans la cible · {closer} rapprochée(s) · {farther} éloignée(s) · {blocking} régression(s) critique(s)",
        "",
    ]

    rows = _metric_rows(comparisons)
    if rows:
        lines += [
            "| Métrique | Baseline | Actuel | Δ | Cible | Verdict |",
            "|---|---:|---:|---:|---:|---|",
        ]
        for row in rows[:12]:
            delta = row["delta"]
            delta_label = "—" if delta is None else f"{delta:+.3f}".rstrip("0").rstrip(".")
            verdict = str(row["verdict"])
            if verdict == "FARTHER_FROM_TARGET" and row["severity"] == "high" and not row["provisional"]:
                verdict_label = "⛔ FARTHER_FROM_TARGET"
            elif verdict == "FARTHER_FROM_TARGET":
                verdict_label = "⚠️ FARTHER_FROM_TARGET"
            elif verdict == "CLOSER_TO_TARGET":
                verdict_label = "↗ CLOSER_TO_TARGET"
            elif verdict == "IN_TARGET":
                verdict_label = "✓ IN_TARGET"
            else:
                verdict_label = "= UNCHANGED"
            lines.append(
                f"| `{row['metric']}` | {_fmt_number(row['baseline'])} | {_fmt_number(row['current'])} | {delta_label} | {row['target']} | {verdict_label} |"
            )
        if len(rows) > 12:
            lines += ["", f"_{len(rows) - 12} autre(s) métrique(s) omise(s) du résumé ; voir les artifacts CI._"]
    else:
        lines.append("Aucune métrique canonique comparable à afficher.")

    lines += [
        "",
        "Le commentaire est un résumé de revue. **La source d'autorité reste le gate CI et les artifacts de provenance.**",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Render LITD PR design telemetry summary")
    parser.add_argument("comparisons", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--upstream-run-id", default=None)
    args = parser.parse_args()
    payloads = [json.loads(path.read_text(encoding="utf-8")) for path in args.comparisons]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(build_pr_summary(payloads, upstream_run_id=args.upstream_run_id), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
