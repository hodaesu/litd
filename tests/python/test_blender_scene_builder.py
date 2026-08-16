import unittest

from tools.blender.build_ashlands_scene import build_scene_plan, load_job


class BlenderSceneBuilderTests(unittest.TestCase):
    def test_every_job_generates_a_compliant_scene_plan(self):
        for index in range(1, 16):
            job = load_job(f"zone_{index:02d}_" + {
                1: "faubourg_cendreux", 2: "village_ravage", 3: "moulin_calcine",
                4: "foret_morte", 5: "ravin_des_pendus", 6: "chapelle_effondree",
                7: "cimetiere", 8: "catacombes", 9: "ossuaire",
                10: "hameau_deserte", 11: "route_des_penitents", 12: "abbaye",
                13: "clocher_boss", 14: "clairiere_des_corbeaux", 15: "crypte_du_sans_nom",
            }[index])
            plan = build_scene_plan(job)
            self.assertEqual(set(plan["collections"]), {"ENVIRONMENT", "COLLISION", "GAMEPLAY_SOCKETS", "LIGHTING", "CAMERA"})
            names = [obj["name"] for obj in plan["objects"]]
            self.assertTrue(any(name.startswith("SM_") for name in names))
            self.assertTrue(any(name.startswith("COL_") for name in names))
            self.assertTrue(any(name.startswith("SOCKET_") for name in names))
            self.assertEqual(plan["zone_id"], job["zone_id"])

    def test_scene_plan_preserves_gameplay_socket_counts(self):
        job = load_job("zone_13_clocher_boss")
        plan = build_scene_plan(job)
        names = [obj["name"] for obj in plan["objects"]]
        self.assertEqual(sum(name.startswith("SOCKET_encounters_") for name in names), job["gameplay_sockets"]["encounters"])
        self.assertIn("SOCKET_boss", names)

    def test_unknown_job_is_rejected(self):
        with self.assertRaises(KeyError):
            load_job("zone_99_absente")
