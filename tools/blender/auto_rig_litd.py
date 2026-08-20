#!/usr/bin/env python3
from __future__ import annotations

import argparse

from tools.blender.automation_common import VISUAL_CONTRACT, bpy_module, load_json, save_blend, scene_armatures, scene_meshes, script_argv


def _bone_layout(height: float) -> dict[str, tuple[tuple[float, float, float], tuple[float, float, float], str | None]]:
    h = height
    return {
        "root": ((0,0,0),(0,0,0.12*h),None),
        "hips": ((0,0,0.42*h),(0,0,0.52*h),"root"),
        "spine": ((0,0,0.52*h),(0,0,0.68*h),"hips"),
        "chest": ((0,0,0.68*h),(0,0,0.79*h),"spine"),
        "neck": ((0,0,0.79*h),(0,0,0.84*h),"chest"),
        "head": ((0,0,0.84*h),(0,0,0.98*h),"neck"),
        "upper_arm.L": ((0,0,0.76*h),(-0.18*h,0,0.72*h),"chest"),
        "forearm.L": ((-0.18*h,0,0.72*h),(-0.32*h,0,0.62*h),"upper_arm.L"),
        "hand.L": ((-0.32*h,0,0.62*h),(-0.38*h,0,0.58*h),"forearm.L"),
        "upper_arm.R": ((0,0,0.76*h),(0.18*h,0,0.72*h),"chest"),
        "forearm.R": ((0.18*h,0,0.72*h),(0.32*h,0,0.62*h),"upper_arm.R"),
        "hand.R": ((0.32*h,0,0.62*h),(0.38*h,0,0.58*h),"forearm.R"),
        "thigh.L": ((-0.08*h,0,0.48*h),(-0.09*h,0,0.27*h),"hips"),
        "shin.L": ((-0.09*h,0,0.27*h),(-0.09*h,0,0.07*h),"thigh.L"),
        "foot.L": ((-0.09*h,0,0.07*h),(-0.09*h,-0.09*h,0.035*h),"shin.L"),
        "thigh.R": ((0.08*h,0,0.48*h),(0.09*h,0,0.27*h),"hips"),
        "shin.R": ((0.09*h,0,0.27*h),(0.09*h,0,0.07*h),"thigh.R"),
        "foot.R": ((0.09*h,0,0.07*h),(0.09*h,-0.09*h,0.035*h),"shin.R")
    }


def rig(asset_id: str, output: str) -> None:
    bpy = bpy_module()
    contract = load_json(VISUAL_CONTRACT)
    height = float(contract["characters"].get(asset_id, {}).get("height_m", 1.8))
    armatures = scene_armatures(bpy)
    if armatures:
        arm = armatures[0]
    else:
        data = bpy.data.armatures.new("RIG_" + asset_id)
        arm = bpy.data.objects.new("RIG_" + asset_id, data)
        bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in list(arm.data.edit_bones):
        arm.data.edit_bones.remove(bone)
    layout = _bone_layout(height)
    created = {}
    for name, (head, tail, parent) in layout.items():
        bone = arm.data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        created[name] = bone
        if parent:
            bone.parent = created[parent]
            bone.use_connect = name not in {"upper_arm.L","upper_arm.R","thigh.L","thigh.R"}
    bpy.ops.object.mode_set(mode="OBJECT")

    for mesh in scene_meshes(bpy):
        bpy.context.view_layer.objects.active = mesh
        mesh.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        mesh.select_set(False)
    meshes = scene_meshes(bpy)
    if meshes:
        bpy.ops.object.select_all(action="DESELECT")
        arm.select_set(True)
        for mesh in meshes:
            mesh.select_set(True)
        bpy.context.view_layer.objects.active = arm
        try:
            bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        except RuntimeError:
            for mesh in meshes:
                mesh.parent = arm

    socket_to_bone = {
        "SOCKET_weapon_r": "hand.R", "SOCKET_weapon_l": "hand.L", "SOCKET_head": "head",
        "SOCKET_back": "chest", "SOCKET_fx_root": "root"
    }
    existing = {obj.name: obj for obj in bpy.context.scene.objects}
    for socket_name in contract["asset_ingest"]["required_sockets"]:
        obj = existing.get(socket_name)
        if obj is None:
            obj = bpy.data.objects.new(socket_name, None)
            bpy.context.scene.collection.objects.link(obj)
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = socket_to_bone[socket_name]
    arm["litd_standard_rig"] = True
    arm["litd_asset_id"] = asset_id
    save_blend(bpy, output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(script_argv())
    rig(args.asset_id, args.output)
    print("LITD_AUTO_RIG_OK", args.asset_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
