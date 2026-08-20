#!/usr/bin/env python3
from __future__ import annotations

import argparse

from tools.blender.automation_common import AUTOMATION_CONTRACT, bpy_module, load_json, save_blend, scene_meshes, script_argv


def generate(asset_id: str, output: str) -> None:
    bpy = bpy_module()
    config = load_json(AUTOMATION_CONTRACT)
    ratios = config.get("lod_ratios", {"lod0": 1.0, "lod1": 0.5, "lod2": 0.2})
    base_meshes = [obj for obj in scene_meshes(bpy) if "_LOD1" not in obj.name and "_LOD2" not in obj.name]
    scene = bpy.context.scene
    for lod_name, ratio in (("LOD1", float(ratios["lod1"])), ("LOD2", float(ratios["lod2"]))):
        collection = bpy.data.collections.get(lod_name) or bpy.data.collections.new(lod_name)
        if collection.name not in scene.collection.children:
            try:
                scene.collection.children.link(collection)
            except RuntimeError:
                pass
        for source in base_meshes:
            duplicate = source.copy()
            duplicate.data = source.data.copy()
            duplicate.name = source.name.replace("_LOD0", "_" + lod_name) if "_LOD0" in source.name else source.name + "_" + lod_name
            collection.objects.link(duplicate)
            modifier = duplicate.modifiers.new(name="LITD_%s_Decimate" % lod_name, type="DECIMATE")
            modifier.ratio = ratio
            bpy.context.view_layer.objects.active = duplicate
            duplicate.select_set(True)
            try:
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            except RuntimeError:
                pass
            duplicate.select_set(False)
            duplicate["litd_lod"] = lod_name.lower()
    for source in base_meshes:
        source["litd_lod"] = "lod0"
    bpy.context.scene["litd_lod_asset_id"] = asset_id
    save_blend(bpy, output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset-id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(script_argv())
    generate(args.asset_id, args.output)
    print("LITD_LODS_OK", args.asset_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
