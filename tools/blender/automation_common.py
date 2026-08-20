from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VISUAL_CONTRACT = ROOT / "data/visual_vertical_slice.json"
AUTOMATION_CONTRACT = ROOT / "data/blender/vertical_slice_automation.json"


def script_argv() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def bpy_module():
    try:
        import bpy  # type: ignore
    except ImportError as exc:
        raise SystemExit("This command must run inside Blender") from exc
    return bpy


def mesh_triangles(mesh_obj) -> int:
    mesh = mesh_obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def scene_meshes(bpy) -> list:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def scene_armatures(bpy) -> list:
    return [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]


def save_blend(bpy, output: str) -> None:
    path = ROOT / output
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
