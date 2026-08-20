#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from tools.blender.automation_common import ROOT, VISUAL_CONTRACT, bpy_module, load_json, save_blend, scene_armatures, script_argv


def retarget(source_blend: str, output: str, action_prefix: str = "") -> int:
    bpy = bpy_module()
    target_arms = scene_armatures(bpy)
    if len(target_arms) != 1:
        raise SystemExit("Target scene must contain exactly one armature")
    target = target_arms[0]
    required = set(load_json(VISUAL_CONTRACT)["asset_ingest"]["required_bones"])
    target_bones = {bone.name for bone in target.data.bones}
    if not required.issubset(target_bones):
        raise SystemExit("Target does not use the standard LITD bone contract")

    source_path = ROOT / source_blend
    with bpy.data.libraries.load(str(source_path), link=False) as (data_from, data_to):
        data_to.actions = list(data_from.actions)
    copied = 0
    for action in data_to.actions:
        if action is None:
            continue
        if action_prefix and not action.name.startswith(action_prefix):
            continue
        action["litd_retargeted"] = True
        copied += 1
    target["litd_retarget_source"] = source_blend
    target["litd_retarget_action_count"] = copied
    save_blend(bpy, output)
    return copied


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-blend", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--action-prefix", default="")
    args = parser.parse_args(script_argv())
    count = retarget(args.source_blend, args.output, args.action_prefix)
    print("LITD_RETARGET_OK", count)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
