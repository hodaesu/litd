from pathlib import Path
import json, re, unittest

ROOT=Path(__file__).resolve().parents[2]
def data(name): return json.loads((ROOT/'data'/name).read_text(encoding='utf-8'))

class ProjectTests(unittest.TestCase):
    def test_project_file(self): self.assertTrue((ROOT/'project.godot').is_file())
    def test_main_scene(self): self.assertTrue((ROOT/'scenes/Main.tscn').is_file())
    def test_class_count(self): self.assertGreaterEqual(len(data('classes.json')),10)
    def test_race_count(self): self.assertGreaterEqual(len(data('races.json')),4)
    def test_enemy_count(self): self.assertEqual(len(data('enemies.json')),39)
    def test_hero_count(self): self.assertGreaterEqual(len(data('heroes.json')),4)
    def test_skill_count(self): self.assertGreaterEqual(len(data('skills.json')),4)
    def test_unique_classes(self):
        ids=[x['id'] for x in data('classes.json')]; self.assertEqual(len(ids),len(set(ids)))
    def test_unique_races(self):
        ids=[x['id'] for x in data('races.json')]; self.assertEqual(len(ids),len(set(ids)))
    def test_unique_enemies(self):
        ids=[x['id'] for x in data('enemies.json')]; self.assertEqual(len(ids),len(set(ids)))
    def test_class_damage_ranges(self):
        for x in data('classes.json'): self.assertLessEqual(x['damage'][0],x['damage'][1])
    def test_enemy_damage_ranges(self):
        for x in data('enemies.json'): self.assertLessEqual(x['damage'][0],x['damage'][1])
    def test_enemy_hp_positive(self):
        for x in data('enemies.json'): self.assertGreater(x['hp'],0)
    def test_hero_hp_valid(self):
        for x in data('heroes.json'): self.assertTrue(0 <= x['hp'] <= x['max_hp'])
    def test_hero_jauges(self):
        for x in data('heroes.json'):
            for key in ('fear','madness','hope'): self.assertTrue(0 <= x[key] <= 100)
    def test_hero_class_references(self):
        ids={x['id'] for x in data('classes.json')}
        for x in data('heroes.json'): self.assertIn(x['class_id'],ids)
    def test_hero_race_references(self):
        ids={x['id'] for x in data('races.json')}
        for x in data('heroes.json'): self.assertIn(x['race_id'],ids)
    def test_enemy_images(self):
        for x in data('enemies.json'): self.assertTrue((ROOT/'assets/enemies'/x['art']).is_file())
    def test_class_images(self):
        for x in data('classes.json'): self.assertTrue((ROOT/'assets/heroes'/x['art']).is_file())
    def test_backgrounds(self): self.assertGreaterEqual(len(list((ROOT/'assets/backgrounds').glob('*'))),5)
    def test_autoload_order(self):
        text=(ROOT/'project.godot').read_text(encoding='utf-8')
        self.assertLess(text.index('DataLoader='),text.index('GameState='))
    def test_save_version(self):
        text=(ROOT/'scripts/core/save_manager.gd').read_text(encoding='utf-8')
        self.assertIn('"version"',text)
    def test_no_merge_markers(self):
        for p in ROOT.rglob('*'):
            if p.suffix in {'.gd','.tscn','.godot','.cfg','.json','.md','.yml'}:
                t=p.read_text(encoding='utf-8'); self.assertNotIn('<<<<<<<',t)
    def test_export_presets(self):
        text=(ROOT/'export_presets.cfg').read_text(encoding='utf-8')
        for preset in ('Web','Windows Desktop','Android','iOS'): self.assertIn(f'name="{preset}"',text)

if __name__=='__main__': unittest.main(verbosity=2)
