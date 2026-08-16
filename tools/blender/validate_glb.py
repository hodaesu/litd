#!/usr/bin/env python3
"""Validate Blender GLB exports before they are accepted by the Godot project."""
from __future__ import annotations

import argparse
import json
import struct
from dataclasses import dataclass, field
from pathlib import Path

JSON_CHUNK = 0x4E4F534A
FORBIDDEN_NAMES = {"Cube", "Cube.001", "Material", "Material.001", "Scene Collection"}


@dataclass
class ValidationReport:
    path: str
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    stats: dict[str, int] = field(default_factory=dict)

    @property
    def valid(self) -> bool:
        return not self.errors

    def as_dict(self) -> dict:
        return {
            "path": self.path,
            "valid": self.valid,
            "errors": self.errors,
            "warnings": self.warnings,
            "stats": self.stats,
        }


def read_glb_json(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("file is too short to be a GLB")
    magic, version, declared_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("invalid GLB magic")
    if version != 2:
        raise ValueError(f"unsupported GLB version {version}; expected 2")
    if declared_length != len(data):
        raise ValueError("GLB declared length does not match file size")
    offset = 12
    while offset + 8 <= len(data):
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + chunk_length]
        offset += chunk_length
        if chunk_type == JSON_CHUNK:
            return json.loads(chunk.rstrip(b" \t\r\n\x00").decode("utf-8"))
    raise ValueError("GLB has no JSON chunk")


def validate_glb(path: Path, require_lods: int = 0, require_collision: bool = False) -> ValidationReport:
    report = ValidationReport(str(path))
    try:
        document = read_glb_json(path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        report.errors.append(str(exc))
        return report

    nodes = document.get("nodes", [])
    meshes = document.get("meshes", [])
    materials = document.get("materials", [])
    node_names = [str(node.get("name", "")) for node in nodes]
    mesh_names = [str(mesh.get("name", "")) for mesh in meshes]
    material_names = [str(material.get("name", "")) for material in materials]
    report.stats = {"nodes": len(nodes), "meshes": len(meshes), "materials": len(materials)}

    if not meshes:
        report.errors.append("export contains no mesh")
    _validate_names(node_names + mesh_names + material_names, report)
    for name in mesh_names:
        if not name.startswith(("SM_", "COL_")):
            report.errors.append(f"mesh name must start with SM_ or COL_: {name or '<empty>'}")
    for name in material_names:
        if not name.startswith("M_"):
            report.errors.append(f"material name must start with M_: {name or '<empty>'}")

    for mesh in meshes:
        material_indices = {primitive.get("material") for primitive in mesh.get("primitives", []) if "material" in primitive}
        if len(material_indices) > 3:
            report.errors.append(f"mesh {mesh.get('name', '<empty>')} uses more than 3 materials")

    if require_lods:
        for level in range(require_lods):
            suffix = f"LOD{level}"
            if not any(suffix in name for name in mesh_names):
                report.errors.append(f"missing required {suffix} mesh")
    if require_collision and not any(name.startswith("COL_") for name in node_names + mesh_names):
        report.errors.append("missing required COL_ collision object")
    if not any(name.startswith("SOCKET_") for name in node_names):
        report.warnings.append("no SOCKET_ anchor exported")
    return report


def _validate_names(names: list[str], report: ValidationReport) -> None:
    for name in names:
        if not name:
            report.errors.append("unnamed node, mesh or material")
        elif name in FORBIDDEN_NAMES or name.startswith(("Cube.", "Material.")):
            report.errors.append(f"generic Blender name is forbidden: {name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--require-lods", type=int, default=0, choices=range(0, 4))
    parser.add_argument("--require-collision", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args()
    reports = [validate_glb(path, args.require_lods, args.require_collision) for path in args.paths]
    if args.json_output:
        print(json.dumps([report.as_dict() for report in reports], ensure_ascii=False, indent=2))
    else:
        for report in reports:
            prefix = "PASS" if report.valid else "FAIL"
            print(f"{prefix} - {report.path}")
            for error in report.errors:
                print(f"  ERROR: {error}")
            for warning in report.warnings:
                print(f"  WARNING: {warning}")
    return 0 if all(report.valid for report in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
