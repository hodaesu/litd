#!/usr/bin/env python3
"""Validate rigging and animation contracts in exported character GLBs."""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from pathlib import Path

from tools.blender.validate_glb import read_glb_json

DEFAULT_ANIMATIONS = ("idle", "walk", "run", "attack", "hit", "death")


@dataclass
class CharacterReport:
    path: str
    errors: list[str] = field(default_factory=list)
    stats: dict[str, int] = field(default_factory=dict)

    @property
    def valid(self) -> bool:
        return not self.errors

    def as_dict(self) -> dict:
        return {"path": self.path, "valid": self.valid, "errors": self.errors, "stats": self.stats}


def validate_character_glb(path: Path, required_animations=DEFAULT_ANIMATIONS) -> CharacterReport:
    report = CharacterReport(str(path))
    try:
        document = read_glb_json(path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        report.errors.append(str(exc))
        return report
    nodes = document.get("nodes", [])
    meshes = document.get("meshes", [])
    skins = document.get("skins", [])
    animations = document.get("animations", [])
    names = [str(animation.get("name", "")).lower() for animation in animations]
    report.stats = {"nodes": len(nodes), "meshes": len(meshes), "skins": len(skins), "animations": len(animations)}
    if not skins:
        report.errors.append("character export contains no skin")
    if not any(str(node.get("name", "")).startswith("RIG_") for node in nodes):
        report.errors.append("missing RIG_ armature node")
    if not any(str(mesh.get("name", "")).startswith("SK_") for mesh in meshes):
        report.errors.append("missing SK_ skinned mesh")
    for required in required_animations:
        if not any(name == required or name.endswith("|" + required) for name in names):
            report.errors.append(f"missing required animation: {required}")
    for index, animation in enumerate(animations):
        if not animation.get("channels") or not animation.get("samplers"):
            report.errors.append(f"animation {animation.get('name', index)} has no channels or samplers")
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--required", nargs="*", default=list(DEFAULT_ANIMATIONS))
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args()
    reports = [validate_character_glb(path, args.required) for path in args.paths]
    if args.json_output:
        print(json.dumps([report.as_dict() for report in reports], ensure_ascii=False, indent=2))
    else:
        for report in reports:
            print(f"{'PASS' if report.valid else 'FAIL'} - {report.path}")
            for error in report.errors:
                print(f"  ERROR: {error}")
    return 0 if all(report.valid for report in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
