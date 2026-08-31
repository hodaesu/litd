#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIBRARY = ROOT / "data/art_reference_library.json"


def audit(root: Path = ROOT) -> list[str]:
    path = root / "data/art_reference_library.json"
    if not path.is_file():
        return ["Bibliothèque picturale absente"]
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    references = data.get("references", [])
    ids = [str(item.get("id", "")) for item in references]
    if len(references) < 20:
        errors.append("La bibliothèque doit contenir au moins 20 références")
    if not all(ids) or len(ids) != len(set(ids)):
        errors.append("Les identifiants de références sont absents ou dupliqués")
    allowed_rights = {"public_domain", "cc0"}
    required = {"title", "creator", "culture", "date", "medium", "category", "source_url", "rights", "inspiration", "litd_uses"}
    for item in references:
        missing = sorted(required - set(item))
        if missing:
            errors.append(f"{item.get('id', '<sans id>')} : champs absents {missing}")
        if item.get("rights") not in allowed_rights:
            errors.append(f"{item.get('id')} : droits incompatibles")
        if not str(item.get("source_url", "")).startswith("https://"):
            errors.append(f"{item.get('id')} : source institutionnelle HTTPS absente")
        if len(item.get("inspiration", [])) < 3 or len(item.get("litd_uses", [])) < 2:
            errors.append(f"{item.get('id')} : analyse créative insuffisante")
    known = set(ids)
    categories = [str(item.get("category", "")) for item in references]
    if categories.count("dessin") < 3:
        errors.append("La bibliothèque doit contenir au moins trois dessins")
    if categories.count("mosaique") < 3:
        errors.append("La bibliothèque doit contenir au moins trois mosaïques")
    for preset, selected in data.get("creative_presets", {}).items():
        if len(selected) < 3:
            errors.append(f"Preset {preset} : moins de trois sources")
        unknown = sorted(set(selected) - known)
        if unknown:
            errors.append(f"Preset {preset} : références inconnues {unknown}")
    policy = data.get("usage_policy", {})
    if int(policy.get("minimum_sources_per_creation", 0)) < 3:
        errors.append("La règle de recomposition doit imposer au moins trois sources")
    return errors


def main() -> int:
    errors = audit()
    report = {"ok": not errors, "errors": errors}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
