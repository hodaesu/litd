from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'data/levels/terre_des_cendres_blockout_manifest.json'
SURVIVAL = ROOT / 'data/levels/ashlands_survival_rules.json'
MINIBOSSES = ROOT / 'data/levels/ashlands_minibosses.json'
BLUEPRINTS = ROOT / 'data/levels/ashlands_zone_blueprints.json'
LAYOUT_PROFILES = ROOT / 'data/levels/ashlands_layout_profiles.json'
BLENDER_HANDOFF = ROOT / 'data/levels/ashlands_blender_handoff.json'
CAMERA_PROFILES = ROOT / 'data/levels/ashlands_camera_profiles.json'
PACING_TARGETS = ROOT / 'data/levels/ashlands_pacing_targets.json'
BLENDER_JOBS = ROOT / 'data/levels/ashlands_blender_jobs.json'
LORE = ROOT / 'data/levels/ashlands_lore.json'

class AshlandsPreBlenderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        cls.survival = json.loads(SURVIVAL.read_text(encoding='utf-8'))
        cls.minibosses = json.loads(MINIBOSSES.read_text(encoding='utf-8'))
        cls.blueprints = json.loads(BLUEPRINTS.read_text(encoding='utf-8'))
        cls.layout_profiles = json.loads(LAYOUT_PROFILES.read_text(encoding='utf-8'))
        cls.blender_handoff = json.loads(BLENDER_HANDOFF.read_text(encoding='utf-8'))
        cls.camera_profiles = json.loads(CAMERA_PROFILES.read_text(encoding='utf-8'))
        cls.pacing_targets = json.loads(PACING_TARGETS.read_text(encoding='utf-8'))
        cls.blender_jobs = json.loads(BLENDER_JOBS.read_text(encoding='utf-8'))
        cls.lore = json.loads(LORE.read_text(encoding='utf-8'))

    def test_ashlands_lore_has_complete_collections(self):
        entries = self.lore['entries']
        self.assertEqual(self.lore['total_entries'], 40)
        self.assertEqual(len(entries), 40)
        self.assertEqual(len({entry['id'] for entry in entries}), 40)
        counts = {}
        for entry in entries:
            counts[entry['collection']] = counts.get(entry['collection'], 0) + 1
            self.assertTrue(entry['title'])
            self.assertTrue(entry['text'])
        self.assertEqual(counts, {
            'echoes_before_fall': 12,
            'broken_world_meditations': 10,
            'fear_treatises': 6,
            'hope_vigils': 6,
            'broken_city_archives': 6,
        })

    def test_political_archives_cover_before_and_after_the_fall(self):
        political = [entry for entry in self.lore['entries'] if entry['collection'] == 'broken_city_archives']
        self.assertEqual({entry['era'] for entry in political}, {'before_fall', 'after_fall'})
        self.assertEqual(sum(entry['era'] == 'before_fall' for entry in political), 3)
        self.assertEqual(sum(entry['era'] == 'after_fall' for entry in political), 3)

    def test_ashlands_lore_positions_are_authored_inside_zones(self):
        zones = {zone['id']: zone for zone in self.manifest['zones']}
        for entry in self.lore['entries']:
            self.assertIn(entry['zone_id'], zones)
            self.assertEqual(len(entry['position']), 3)
            width, depth = zones[entry['zone_id']]['size_m']
            x, _y, z = entry['position']
            self.assertLessEqual(abs(x), width / 2, entry['id'])
            self.assertLessEqual(abs(z), depth / 2, entry['id'])

    def test_lore_runtime_collection_and_reader_contracts_exist(self):
        collectible = (ROOT / 'scripts/world/lore_collectible.gd').read_text(encoding='utf-8')
        runtime = (ROOT / 'scripts/world/ashlands_zone_runtime.gd').read_text(encoding='utf-8')
        builder = (ROOT / 'scripts/world/ashlands_blockout_builder.gd').read_text(encoding='utf-8')
        hud = (ROOT / 'scripts/world/ashlands_hud.gd').read_text(encoding='utf-8')
        self.assertIn('AshlandsRuntime.collect_lore(entry)', collectible)
        self.assertIn('"collected_lore": collected_lore', runtime)
        self.assertIn('_build_lore_slots()', builder)
        self.assertIn('_on_lore_discovered', hud)
        self.assertIn('_meets_madness_requirement', collectible)

    def test_environmental_lore_has_production_markers(self):
        stories = self.lore['environmental_scenes']
        self.assertEqual(len(stories), 3)
        self.assertEqual(len({story['id'] for story in stories}), 3)
        builder = (ROOT / 'scripts/world/ashlands_blockout_builder.gd').read_text(encoding='utf-8')
        self.assertIn('_build_storytelling_markers()', builder)
        self.assertIn('environmental_storytelling', builder)

    def test_all_authored_zones_are_registered(self):
        self.assertEqual(len(self.manifest['zones']), 16)

    def test_zone_ids_are_unique(self):
        ids = [z['id'] for z in self.manifest['zones']]
        self.assertEqual(len(ids), len(set(ids)))

    def test_all_zone_scenes_exist(self):
        special = {'zone_07_cimetiere': 'zone_07_cimetiere_blockout.tscn'}
        for z in self.manifest['zones']:
            filename = special.get(z['id'], z['id'] + '.tscn')
            self.assertTrue((ROOT / 'scenes/world/terre_des_cendres' / filename).is_file(), filename)

    def test_every_zone_has_a_layout_profile(self):
        manifest_ids = {zone['id'] for zone in self.manifest['zones']}
        profile_ids = set(self.layout_profiles['zones'])
        self.assertEqual(profile_ids, manifest_ids)

    def test_layout_profiles_reference_complete_rules(self):
        rules = self.layout_profiles['profile_rules']
        for zone_id, profile in self.layout_profiles['zones'].items():
            with self.subTest(zone=zone_id):
                self.assertIn(profile['profile'], rules)
                self.assertGreaterEqual(profile['levels'], 1)
                self.assertGreaterEqual(profile['branching'], 1)
                self.assertIn(profile['cover_density'], {'low', 'medium', 'high'})
                self.assertTrue(profile['landmark'])

        referenced_rules = {profile['profile'] for profile in self.layout_profiles['zones'].values()}
        self.assertEqual(set(rules), referenced_rules)
        for profile_name, rule in rules.items():
            with self.subTest(profile=profile_name):
                self.assertEqual(
                    set(rule),
                    {'building_count', 'platform_count', 'wall_count'},
                )
                self.assertTrue(all(isinstance(count, int) and count >= 0 for count in rule.values()))
                self.assertGreater(sum(rule.values()), 0)

    def test_secret_zones_are_14_and_15(self):
        ids = {z['id'] for z in self.manifest['zones'] if z.get('miniboss_secret_pool')}
        self.assertEqual(ids, {'zone_14_clairiere_des_corbeaux', 'zone_15_crypte_du_sans_nom'})

    def test_ash_never_hides_bosses(self):
        never = set(self.manifest['global_rules']['ash_never_hides'])
        self.assertIn('miniboss', never)
        self.assertIn('boss', never)

    def test_minibosses_are_not_recruitable(self):
        self.assertFalse(self.manifest['global_rules']['minibosses_recruitable'])
        self.assertFalse(self.minibosses['rules']['recruitable'])

    def test_normal_minibosses_always_have_allowed_zones(self):
        zone_ids = {z['id'] for z in self.manifest['zones']}
        for boss in self.minibosses['normal_pool']:
            self.assertTrue(boss['allowed_zones'])
            self.assertTrue(set(boss['allowed_zones']).issubset(zone_ids))

    def test_secret_miniboss_rotation_only_uses_secret_zones(self):
        allowed = {'zone_14_clairiere_des_corbeaux', 'zone_15_crypte_du_sans_nom'}
        for boss in self.minibosses['secret_pool']:
            self.assertTrue(set(boss['allowed_zones']).issubset(allowed))

    def test_campfires_exist_at_designed_breakpoints(self):
        camp_zones = {z['id'] for z in self.manifest['zones'] if z.get('campfire')}
        self.assertEqual(camp_zones, {
            'zone_03_moulin_calcine',
            'zone_06_chapelle_effondree',
            'zone_09_ossuaire',
            'zone_12_abbaye'
        })

    def test_hub_is_only_full_resupply(self):
        self.assertTrue(self.manifest['global_rules']['hub_is_only_full_resupply'])
        self.assertTrue(self.survival['principles']['hub_only_full_resupply'])

    def test_crow_can_drop_food(self):
        crow = self.survival['corpse_harvest']['crow']
        self.assertTrue(any(x['item'] == 'food' and x['max'] >= 1 for x in crow))

    def test_required_runtime_scripts_exist(self):
        required = [
            'scripts/core/expedition_manager.gd',
            'scripts/world/ashlands_miniboss_director.gd',
            'scripts/world/ashlands_scene_router.gd',
            'scripts/world/ash_volume.gd',
            'scripts/world/resource_node.gd',
            'scripts/world/lore_collectible.gd',
            'scripts/world/corpse_harvest.gd',
            'scripts/world/campfire_interaction.gd',
            'scripts/world/zone_transition_gate.gd',
            'scripts/world/shortcut_gate.gd',
            'scripts/world/encounter_trigger.gd',
            'scripts/world/exploration_party_controller.gd',
            'scripts/world/isometric_camera_rig.gd',
            'scripts/world/ashlands_performance_probe.gd',
            'scripts/world/ashlands_ambience_controller.gd',
            'scripts/world/isometric_occludable.gd',
            'scripts/world/isometric_occlusion_manager.gd',
            'scripts/world/mobile_exploration_controls.gd',
            'scripts/world/ashlands_blockout_builder.gd',
            'scripts/world/ashlands_layout_generator.gd',
            'scripts/world/ashlands_asset_registry.gd',
            'scripts/world/ashlands_playtest_session.gd',
            'scripts/world/ashlands_playtest_panel.gd',
        ]
        for rel in required:
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_navigation_and_return_position_contracts_exist(self):
        builder = (ROOT / 'scripts/world/ashlands_blockout_builder.gd').read_text(encoding='utf-8')
        bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text(encoding='utf-8')
        self.assertIn('agent_radius = 0.6', builder)
        self.assertIn('PARSED_GEOMETRY_STATIC_COLLIDERS', builder)
        self.assertIn('return_position', bridge)
        self.assertIn('_restore_exploration_position', bridge)

    def test_mobile_occlusion_and_ambience_contracts_exist(self):
        mobile_scene = (ROOT / 'scenes/world/terre_des_cendres/mobile_exploration_controls.tscn').read_text(encoding='utf-8')
        layout = (ROOT / 'scripts/world/ashlands_layout_generator.gd').read_text(encoding='utf-8')
        ambience = (ROOT / 'scripts/world/ashlands_ambience_controller.gd').read_text(encoding='utf-8')
        self.assertIn('anchor_bottom = 1.0', mobile_scene)
        self.assertIn('ZoomIn', mobile_scene)
        self.assertIn('OCCLUDABLE_SCRIPT.new()', layout)
        self.assertIn('AshVFXPlaceholder', ambience)
        self.assertIn('WindLoopPlaceholder', ambience)

    def test_blender_handoff_covers_every_zone_and_slot(self):
        zone_ids = {zone['id'] for zone in self.manifest['zones']}
        self.assertEqual(set(self.blender_handoff['zone_kits']), zone_ids)
        self.assertEqual(self.blender_handoff['coordinate_system']['scale'], 1.0)
        self.assertEqual(self.blender_handoff['export']['format'], 'glb')
        self.assertTrue(self.blender_handoff['runtime_contract']['preserve_navigation_source'])
        self.assertGreaterEqual(len(self.blender_handoff['asset_slots']), 8)
        self.assertGreaterEqual(len(self.blender_handoff['approval_gates']), 7)

    def test_every_zone_has_an_authored_camera_profile(self):
        zone_ids = {zone['id'] for zone in self.manifest['zones']}
        self.assertEqual(set(self.camera_profiles['zones']), zone_ids)
        for zone_id, profile in self.camera_profiles['zones'].items():
            with self.subTest(zone=zone_id):
                self.assertGreaterEqual(profile['pitch'], 35.0)
                self.assertLessEqual(profile['pitch'], 55.0)
                self.assertGreaterEqual(profile['view_size'], 10.0)
                self.assertLessEqual(profile['view_size'], 18.0)
                self.assertEqual(len(profile['focus_offset']), 3)
                self.assertTrue(profile['intent'])

    def test_orthographic_zoom_changes_camera_size(self):
        rig = (ROOT / 'scripts/world/isometric_camera_rig.gd').read_text(encoding='utf-8')
        self.assertIn('camera.size = distance', rig)
        self.assertIn('apply_zone_profile(AshlandsRuntime.current_zone_id)', rig)

    def test_playtest_harness_covers_routes_camera_mobile_and_performance(self):
        session = (ROOT / 'scripts/world/ashlands_playtest_session.gd').read_text(encoding='utf-8')
        builder = (ROOT / 'scripts/world/ashlands_blockout_builder.gd').read_text(encoding='utf-8')
        project = (ROOT / 'project.godot').read_text(encoding='utf-8')
        for gate in ('primary_route_checked', 'bypass_route_checked', 'camera_checked', 'mobile_checked', 'performance'):
            self.assertIn(gate, session)
        self.assertIn('OS.is_debug_build()', builder)
        self.assertIn('AshlandsPlaytestSession=', project)

    def test_pacing_targets_and_route_telemetry_cover_all_zones(self):
        zone_ids = {zone['id'] for zone in self.manifest['zones']}
        self.assertEqual(set(self.pacing_targets['zones']), zone_ids)
        for zone_id, targets in self.pacing_targets['zones'].items():
            for route in ('primary_seconds', 'bypass_seconds'):
                self.assertEqual(len(targets[route]), 2, f'{zone_id}:{route}')
                self.assertLess(targets[route][0], targets[route][1])
        session = (ROOT / 'scripts/world/ashlands_playtest_session.gd').read_text(encoding='utf-8')
        for contract in ('duration_seconds', 'distance_m', 'average_speed_mps', 'trail', 'within_target'):
            self.assertIn(contract, session)

    def test_blender_production_jobs_are_complete_and_current(self):
        from tools.blender.generate_ashlands_jobs import build_plan
        self.assertEqual(self.blender_jobs, build_plan())
        jobs = self.blender_jobs['jobs']
        self.assertEqual(len(jobs), 16)
        self.assertEqual({job['zone_id'] for job in jobs}, {zone['id'] for zone in self.manifest['zones']})
        self.assertEqual(self.blender_jobs['export_format'], 'glb')
        for job in jobs:
            self.assertIn(job['priority'], {'P0', 'P1', 'P2'})
            self.assertTrue(job['landmark'])
            self.assertEqual(job['deliverables']['collision_policy'], 'keep_blockout_until_approved')
            self.assertGreaterEqual(len(job['approval_gates']), 7)

    def test_project_registers_ashlands_autoloads(self):
        text = (ROOT / 'project.godot').read_text(encoding='utf-8')
        for name in ('ExpeditionManager=', 'AshlandsMinibossDirector=', 'AshlandsRuntime=', 'AshlandsSceneRouter='):
            self.assertIn(name, text)

    def test_every_zone_has_an_authored_blueprint(self):
        zone_ids = {z['id'] for z in self.manifest['zones']}
        self.assertEqual(set(self.blueprints['zones']), zone_ids)

    def test_authored_slots_match_manifest_counts(self):
        for zone in self.manifest['zones']:
            blueprint = self.blueprints['zones'][zone['id']]
            for blueprint_key, manifest_key in (
                ('encounters', 'encounter_slots'), ('resources', 'resource_slots'),
                ('ash', 'ash_volumes'), ('shortcuts', 'shortcut_slots'),
            ):
                expected = len(zone[manifest_key]) if manifest_key == 'shortcut_slots' else zone[manifest_key]
                self.assertEqual(len(blueprint.get(blueprint_key, [])), expected, f"{zone['id']}:{blueprint_key}")

    def test_authored_positions_stay_inside_zone_envelopes(self):
        zones = {z['id']: z for z in self.manifest['zones']}
        for zone_id, blueprint in self.blueprints['zones'].items():
            width, depth = zones[zone_id]['size_m']
            for key in ('primary_route', 'bypass_route', 'encounters', 'resources', 'ash', 'shortcuts'):
                for x, _y, z in blueprint.get(key, []):
                    self.assertLessEqual(abs(x), width / 2, f"{zone_id}:{key}:x")
                    self.assertLessEqual(abs(z), depth / 2, f"{zone_id}:{key}:z")

    def test_routes_are_ready_for_navigation_bake(self):
        for zone_id, blueprint in self.blueprints['zones'].items():
            self.assertGreaterEqual(len(blueprint['primary_route']), 5, zone_id)
            self.assertGreaterEqual(len(blueprint['bypass_route']), 4, zone_id)

    def test_special_slots_have_authored_positions(self):
        for zone in self.manifest['zones']:
            blueprint = self.blueprints['zones'][zone['id']]
            if zone.get('campfire'):
                self.assertEqual(len(blueprint.get('campfire', [])), 3, zone['id'])
            if zone.get('boss'):
                self.assertEqual(len(blueprint.get('boss', [])), 3, zone['id'])

if __name__ == '__main__':
    unittest.main(verbosity=2)
