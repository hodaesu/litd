#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from tools.qa.sentinel import Finding, dedupe, render_markdown, summary_for


def load_static(path: Path) -> tuple[list[Finding], list[dict], dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    findings = []
    for row in payload.get("findings", []):
        findings.append(Finding(
            row["severity"], row["code"], row["category"], row["title"], row["detail"],
            row["suggested_fix"], row.get("path", ""), row.get("line"), row.get("evidence", "")
        ))
    return findings, list(payload.get("components", [])), dict(payload.get("metadata", {}))


def finalize(static_report: Path, godot_status: Path, godot_log: Path, outdir: Path) -> dict:
    findings, components, metadata = load_static(static_report)

    if not godot_status.exists():
        findings.append(Finding(
            "HIGH", "GODOT_SMOKE_MISSING", "godot", "Résultat Godot absent",
            "Le job Sentinel n'a pas produit de statut pour le smoke Godot.",
            "Vérifier le job qa-sentinel-godot et l'upload/download des artifacts.",
        ))
        components.append({"name": "godot_smoke", "command": [], "exit_code": 99, "output_tail": "status file missing"})
    else:
        raw = godot_status.read_text(encoding="utf-8", errors="replace").strip()
        try:
            code = int(raw)
        except Exception:
            code = 98
        log = godot_log.read_text(encoding="utf-8", errors="replace") if godot_log.exists() else ""
        tail = "\n".join(log.splitlines()[-120:])
        components.append({"name": "godot_smoke", "command": ["bash", "tools/build/run_godot_ci.sh"], "exit_code": code, "output_tail": tail})
        if code != 0:
            findings.append(Finding(
                "CRITICAL", "GODOT_SMOKE_FAILURE", "godot", "Compilation/parcours critique Godot en échec",
                f"Le smoke Godot a quitté avec le code {code}.",
                "Corriger la première erreur Godot réelle dans l'extrait, puis relancer avant de poursuivre la production.",
                evidence=tail[-5000:],
            ))

    findings = dedupe(findings)
    payload = {
        "schema_version": 1,
        "summary": summary_for(findings),
        "metadata": metadata,
        "components": components,
        "findings": [f.to_dict() for f in findings],
    }
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / "qa-sentinel-final.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (outdir / "qa-sentinel-final.md").write_text(render_markdown(payload), encoding="utf-8")
    return payload


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--static", type=Path, required=True)
    parser.add_argument("--godot-status", type=Path, required=True)
    parser.add_argument("--godot-log", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--no-fail", action="store_true")
    args = parser.parse_args(argv)
    payload = finalize(args.static, args.godot_status, args.godot_log, args.out)
    print(render_markdown(payload))
    if args.no_fail:
        return 0
    return 1 if payload["summary"]["blockers"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
