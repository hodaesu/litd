#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import unicodedata
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
LIBRARY = ROOT / "data/art_reference_library.json"


def normalized(value: str) -> str:
    return "".join(char for char in unicodedata.normalize("NFKD", value.lower()) if not unicodedata.combining(char))


def load_library(path: Path = LIBRARY) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def search(data: dict[str, Any], *, culture: str = "", category: str = "", use: str = "", query: str = "", preset: str = "") -> list[dict[str, Any]]:
    references = data.get("references", [])
    if preset:
        selected = set(data.get("creative_presets", {}).get(preset, []))
        return [item for item in references if item.get("id") in selected]

    filters = [normalized(value) for value in (culture, category, use, query)]
    results: list[dict[str, Any]] = []
    for item in references:
        fields = [
            str(item.get("title", "")), str(item.get("creator", "")), str(item.get("culture", "")),
            str(item.get("category", "")), *item.get("inspiration", []), *item.get("litd_uses", [])
        ]
        haystack = normalized(" ".join(fields))
        if all(not needle or needle in haystack for needle in filters):
            results.append(item)
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Recherche dans la bibliothèque picturale LITD")
    parser.add_argument("--culture", default="")
    parser.add_argument("--category", default="")
    parser.add_argument("--use", default="")
    parser.add_argument("--query", default="")
    parser.add_argument("--preset", default="")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    data = load_library()
    if args.preset and args.preset not in data.get("creative_presets", {}):
        parser.error(f"preset inconnu : {args.preset}")
    results = search(data, culture=args.culture, category=args.category, use=args.use, query=args.query, preset=args.preset)
    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        for item in results:
            print(f"{item['id']} — {item['title']} ({item['culture']})")
            print(f"  Inspiration : {', '.join(item['inspiration'])}")
            print(f"  Usages LITD : {', '.join(item['litd_uses'])}")
            print(f"  Source : {item['source_url']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
