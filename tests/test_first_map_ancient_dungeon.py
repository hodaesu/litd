from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_first_map_exposes_an_optional_ancient_dungeon() -> None:
    manifest = load("data/levels/terre_des_cendres_blockout_manifest.json")
    first = next(z for z in manifest["zones"] if z["id"] == "zone_01_faubourg_cendreux")
    entrance = next(e for e in first["exits"] if e["to"] == "zone_16_salles_du_premier_accord")
    assert entrance["dungeon"] is True
    assert entrance["optional"] is True
    dungeon_zone = next(z for z in manifest["zones"] if z["id"] == entrance["to"])
    assert dungeon_zone["ancient_civilization"] is True
    assert dungeon_zone["depths"] == 3


def test_dungeon_teaches_danger_and_retreat_without_blocking_campaign() -> None:
    dungeon = load("data/dungeons/first_map_hall_of_first_accord.json")
    assert dungeon["required_for_campaign"] is False
    assert len(dungeon["floors"]) == 3
    assert all(floor["retreat_exit"] for floor in dungeon["floors"])
    assert dungeon["rules"]["death_and_injuries_persist"] is True
    assert dungeon["rules"]["difficulty_mode_selection"] is False
    assert dungeon["rules"]["hud_in_exploration"] == "hidden"
    assert dungeon["miniboss"]["capturable"] is False


def test_chapter_registers_dungeon_as_optional_content() -> None:
    chapter = load("data/levels/chapter_01_vertical_slice.json")
    assert chapter["optional_dungeon"]["required"] is False
    stage_zones = {stage["zone"] for stage in chapter["stages"]}
    assert "zone_16_salles_du_premier_accord" not in stage_zones


def test_dungeon_scene_and_router_are_registered() -> None:
    scene = ROOT / "scenes/world/terre_des_cendres/zone_16_salles_du_premier_accord.tscn"
    assert scene.exists()
    router = (ROOT / "scripts/world/ashlands_scene_router.gd").read_text(encoding="utf-8")
    assert '"zone_16_salles_du_premier_accord"' in router
