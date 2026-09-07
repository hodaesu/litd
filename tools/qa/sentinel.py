#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

try:
    import yaml
except Exception:  # pragma: no cover - reported explicitly at runtime
    yaml = None

ROOT = Path(__file__).resolve().parents[2]
SEVERITY_ORDER = {"CRITICAL": 5, "HIGH": 4, "MEDIUM": 3, "LOW": 2, "INFO": 1}
TEXT_SUFFIXES = {".gd", ".py", ".json", ".md", ".yml", ".yaml", ".tscn", ".godot", ".cfg", ".txt"}
IGNORED_PARTS = {".git", ".godot", "reports", "__pycache__", ".pytest_cache", "build", "dist"}


class DuplicateKeyError(ValueError):
    pass


@dataclass(frozen=True)
class Finding:
    severity: str
    code: str
    category: str
    title: str
    detail: str
    suggested_fix: str
    path: str = ""
    line: int | None = None
    evidence: str = ""

    @property
    def fingerprint(self) -> str:
        raw = "|".join((self.code, self.path, str(self.line or ""), self.title, self.evidence[:240]))
        return hashlib.sha1(raw.encode("utf-8", errors="replace")).hexdigest()[:12]

    def to_dict(self) -> dict:
        data = asdict(self)
        data["fingerprint"] = self.fingerprint
        return data


def _pairs_no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate key: {key}")
        result[key] = value
    return result


def _iter_files(root: Path, suffixes: set[str] | None = None) -> Iterable[Path]:
    suffixes = suffixes or TEXT_SUFFIXES
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in suffixes:
            continue
        rel = path.relative_to(root)
        if any(part in IGNORED_PARTS for part in rel.parts):
            continue
        yield path


def _line_for(text: str, needle: str) -> int | None:
    idx = text.find(needle)
    return None if idx < 0 else text.count("\n", 0, idx) + 1


def _finding(severity, code, category, title, detail, suggested_fix, path="", line=None, evidence=""):
    return Finding(severity, code, category, title, detail, suggested_fix, path, line, evidence)


def scan_static(root: Path) -> list[Finding]:
    findings: list[Finding] = []

    # JSON syntax + duplicate keys. Duplicate keys are dangerous because standard parsers silently keep the last one.
    for path in _iter_files(root, {".json"}):
        rel = str(path.relative_to(root))
        try:
            json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_pairs_no_duplicates)
        except DuplicateKeyError as exc:
            findings.append(_finding(
                "HIGH", "JSON_DUPLICATE_KEY", "data_integrity", "Clé JSON dupliquée",
                str(exc), "Supprimer/renommer la clé dupliquée et conserver une seule source de vérité.", rel,
                evidence=str(exc),
            ))
        except Exception as exc:
            findings.append(_finding(
                "CRITICAL", "JSON_INVALID", "data_integrity", "JSON invalide",
                str(exc), "Corriger la syntaxe JSON avant toute autre modification de ce fichier.", rel,
                getattr(exc, "lineno", None), str(exc),
            ))

    # Workflow YAML integrity.
    workflows = root / ".github" / "workflows"
    if workflows.exists():
        if yaml is None:
            findings.append(_finding(
                "HIGH", "YAML_PARSER_MISSING", "ci", "PyYAML indisponible",
                "Le Sentinel ne peut pas valider les workflows YAML.",
                "Installer requirements-dev.txt dans le job Sentinel.", ".github/workflows",
            ))
        else:
            for path in sorted(workflows.glob("*.y*ml")):
                rel = str(path.relative_to(root))
                try:
                    payload = yaml.safe_load(path.read_text(encoding="utf-8"))
                    if not isinstance(payload, dict):
                        raise ValueError("workflow root is not a mapping")
                except Exception as exc:
                    findings.append(_finding(
                        "CRITICAL", "WORKFLOW_YAML_INVALID", "ci", "Workflow GitHub Actions invalide",
                        str(exc), "Corriger le YAML afin que GitHub puisse charger le workflow.", rel,
                        getattr(exc, "problem_mark", None).line + 1 if getattr(exc, "problem_mark", None) else None,
                        str(exc),
                    ))

    conflict_markers = ("<<<<<<< ", "=======", ">>>>>>> ")
    absolute_patterns = [
        re.compile(r"[A-Za-z]:\\Users\\[^\\\s]+"),
        re.compile(r"/Users/[^/\s]+/"),
        re.compile(r"/home/[^/\s]+/"),
    ]
    debt_re = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b", re.IGNORECASE)
    resource_re = re.compile(r"res://[A-Za-z0-9_./@+-]+")

    for path in _iter_files(root):
        rel = str(path.relative_to(root))
        text = path.read_text(encoding="utf-8", errors="replace")

        for marker in conflict_markers:
            if marker in text:
                findings.append(_finding(
                    "CRITICAL", "GIT_CONFLICT_MARKER", "source_integrity", "Marqueur de conflit Git présent",
                    f"Le fichier contient `{marker.strip()}`.",
                    "Résoudre le conflit puis supprimer tous les marqueurs Git.", rel, _line_for(text, marker), marker.strip(),
                ))
                break

        for pattern in absolute_patterns:
            match = pattern.search(text)
            if match:
                findings.append(_finding(
                    "HIGH", "LOCAL_ABSOLUTE_PATH", "portability", "Chemin local absolu détecté",
                    f"Référence locale non portable: {match.group(0)}",
                    "Utiliser res://, user://, une variable d'environnement ou un chemin relatif au projet.",
                    rel, _line_for(text, match.group(0)), match.group(0),
                ))
                break

        # Technical debt is informative; it never blocks by itself.
        for match in list(debt_re.finditer(text))[:3]:
            token = match.group(1).upper()
            findings.append(_finding(
                "LOW", "TECH_DEBT_TAG", "maintainability", f"Dette technique marquée {token}",
                "Un marqueur de dette technique reste dans une source de production.",
                "Créer/relier une tâche de correction ou supprimer le marqueur si le problème est résolu.",
                rel, text.count("\n", 0, match.start()) + 1, token,
            ))

        if path.suffix.lower() in {".gd", ".tscn", ".godot", ".cfg"}:
            for ref in sorted(set(resource_re.findall(text))):
                target = root / ref.removeprefix("res://")
                # Imported/runtime pseudo-resources are intentionally ignored.
                if "::" in ref or ref.startswith("res://.godot/"):
                    continue
                if not target.exists():
                    findings.append(_finding(
                        "HIGH", "BROKEN_RES_REFERENCE", "godot", "Référence res:// introuvable",
                        f"{ref} ne correspond à aucun fichier du dépôt.",
                        "Corriger la référence, restaurer le fichier ou supprimer la dépendance devenue obsolète.",
                        rel, _line_for(text, ref), ref,
                    ))

    return dedupe(findings)


def run_command(root: Path, name: str, command: list[str], severity: str, code: str, category: str, suggested_fix: str) -> tuple[list[Finding], dict]:
    proc = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = proc.stdout or ""
    component = {"name": name, "command": command, "exit_code": proc.returncode, "output_tail": "\n".join(output.splitlines()[-80:])}
    if proc.returncode == 0:
        return [], component
    finding = _finding(
        severity, code, category, f"{name} en échec",
        f"La commande a terminé avec le code {proc.returncode}.", suggested_fix,
        evidence=component["output_tail"][-4000:],
    )
    return [finding], component


def dedupe(findings: Iterable[Finding]) -> list[Finding]:
    by_fp = {}
    for finding in findings:
        by_fp[finding.fingerprint] = finding
    return sorted(by_fp.values(), key=lambda f: (-SEVERITY_ORDER[f.severity], f.category, f.path, f.line or 0, f.code))


def summary_for(findings: list[Finding]) -> dict:
    counts = {key: 0 for key in SEVERITY_ORDER}
    for finding in findings:
        counts[finding.severity] += 1
    blockers = counts["CRITICAL"] + counts["HIGH"]
    return {"counts": counts, "total_findings": len(findings), "blockers": blockers, "healthy": blockers == 0}


def render_markdown(payload: dict) -> str:
    summary = payload["summary"]
    counts = summary["counts"]
    status = "✅ SAIN" if summary["healthy"] else "❌ À CORRIGER"
    lines = [
        "# LITD — Veilleurs QA Sentinel",
        "",
        f"**État : {status}** — bloqueurs: **{summary['blockers']}** | total: **{summary['total_findings']}**",
        "",
        f"CRITICAL **{counts['CRITICAL']}** · HIGH **{counts['HIGH']}** · MEDIUM **{counts['MEDIUM']}** · LOW **{counts['LOW']}** · INFO **{counts['INFO']}**",
        "",
    ]
    components = payload.get("components", [])
    if components:
        lines += ["## Contrôles exécutés", "", "| Contrôle | Sortie |", "|---|---:|"]
        for component in components:
            lines.append(f"| `{component['name']}` | `{component['exit_code']}` |")
        lines.append("")

    if not payload["findings"]:
        lines += ["## Résultat", "", "Aucune anomalie détectée par les contrôles du Sentinel.", ""]
    else:
        lines += ["## Corrections prioritaires", ""]
        for index, finding in enumerate(payload["findings"][:40], 1):
            location = finding.get("path") or "global"
            if finding.get("line"):
                location += f":{finding['line']}"
            lines += [
                f"### {index}. [{finding['severity']}] {finding['title']} — `{finding['fingerprint']}`",
                f"- **Catégorie :** `{finding['category']}`",
                f"- **Emplacement :** `{location}`",
                f"- **Problème :** {finding['detail']}",
                f"- **Correction suggérée :** {finding['suggested_fix']}",
            ]
            if finding.get("evidence"):
                evidence = finding["evidence"].replace("```", "''' ")[-1800:]
                lines += ["- **Preuve / extrait :**", "```text", evidence, "```"]
            lines.append("")
        if len(payload["findings"]) > 40:
            lines.append(f"_{len(payload['findings']) - 40} anomalie(s) supplémentaire(s) dans le rapport JSON._")
            lines.append("")
    lines += [
        "## Règle de blocage",
        "",
        "`CRITICAL` et `HIGH` font échouer le Sentinel. `MEDIUM`/`LOW` restent visibles sans bloquer la PR.",
        "",
    ]
    return "\n".join(lines)


def write_report(outdir: Path, findings: list[Finding], components: list[dict], metadata: dict | None = None) -> dict:
    outdir.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": 1,
        "summary": summary_for(findings),
        "metadata": metadata or {},
        "components": components,
        "findings": [finding.to_dict() for finding in findings],
    }
    (outdir / "qa-sentinel.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (outdir / "qa-sentinel.md").write_text(render_markdown(payload), encoding="utf-8")
    return payload


def emit_annotations(findings: Iterable[Finding]):
    for finding in findings:
        level = "error" if finding.severity in {"CRITICAL", "HIGH"} else "warning"
        attrs = []
        if finding.path:
            attrs.append(f"file={finding.path}")
        if finding.line:
            attrs.append(f"line={finding.line}")
        meta = ",".join(attrs)
        prefix = f"::{level} {meta}::" if meta else f"::{level}::"
        message = f"[{finding.severity}/{finding.code}] {finding.title} — {finding.detail} Correction: {finding.suggested_fix}"
        print(prefix + message.replace("\n", " %0A "))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="LITD centralized QA Sentinel")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path, default=ROOT / "reports" / "qa-sentinel-static")
    parser.add_argument("--with-tests", action="store_true")
    parser.add_argument("--with-audit", action="store_true")
    parser.add_argument("--no-fail", action="store_true", help="Always exit zero; final gate can fail later after aggregation.")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    findings = scan_static(root)
    components = [{"name": "static_scan", "command": [], "exit_code": 0, "output_tail": ""}]

    if args.with_tests:
        extra, component = run_command(
            root, "pytest", [sys.executable, "-m", "pytest", "-q"], "CRITICAL", "PYTEST_FAILURE", "tests",
            "Ouvrir l'échec pytest indiqué dans la preuve, corriger la première cause réelle puis relancer le Sentinel.",
        )
        findings.extend(extra); components.append(component)
    if args.with_audit:
        audit_out = args.out / "base-audit"
        extra, component = run_command(
            root, "base_qa_audit", [sys.executable, "-m", "tools.qa.audit", "--out", str(audit_out)], "HIGH", "BASE_AUDIT_FAILURE", "data_integrity",
            "Corriger le contrôle QA de base en échec (référence, contrat de données, asset ou workflow) puis relancer.",
        )
        findings.extend(extra); components.append(component)

    findings = dedupe(findings)
    payload = write_report(args.out, findings, components, {"root": str(root)})
    emit_annotations(findings)
    print(render_markdown(payload))
    if args.no_fail:
        return 0
    return 1 if payload["summary"]["blockers"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
