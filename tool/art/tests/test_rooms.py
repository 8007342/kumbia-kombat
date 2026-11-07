#!/usr/bin/env python3
"""The room compiler: both rooms compile from data alone, and bad layouts are refused by name."""
import copy
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "rooms"))
import compiler  # noqa: E402


def refusal(spec):
    with unittest.TestCase().assertRaises(compiler.RoomError) as caught:
        compiler.compile_room(spec)
    return str(caught.exception)


class Rooms(unittest.TestCase):
    def setUp(self):
        self.pool = compiler.load_spec("pool-garden")

    def test_both_rooms_compile_and_write_everything(self):
        for room in ("pool-garden", "ballroom"):
            spec = compiler.load_spec(room)
            with tempfile.TemporaryDirectory() as d:
                compiler.write_outputs(spec, d)
                for name in ("greybox.png", "ids.png", "floor.json", "overlay.png", "prompt-pass1.txt", "prompt-pass2.txt", "level.fragment.json"):
                    self.assertTrue((Path(d) / name).exists(), name)

    def test_compile_is_deterministic(self):
        a = compiler.compile_room(self.pool); b = compiler.compile_room(copy.deepcopy(self.pool))
        self.assertEqual(a[0].idm.tobytes(), b[0].idm.tobytes())
        self.assertEqual(a[2], b[2])

    def test_floor_formula_matches_the_projector(self):
        _, cam, floor, _ = compiler.compile_room(self.pool)
        for s in (1, 3, 6):
            x, y = cam.proj(s, 0.2)
            self.assertAlmostEqual(y - cam.proj(s, 0.2, 1.0)[1], (y - cam.hz) / cam.eye, places=6)
            self.assertAlmostEqual(cam.floor_at(x / cam.W, y / cam.H)[0], s, places=6)
        self.assertAlmostEqual(floor["horizonY"], self.pool["camera"]["horizonY"])

    def test_refuses_a_pool_outside_the_phone_crop(self):
        spec = copy.deepcopy(self.pool)
        for op in spec["paint"]:
            if op.get("id") == "water":
                op["t"] = [-9.0, -2.7]
            if op.get("id") == "deck":
                op["t"] = [-9.5, -2.3]
        self.assertIn("story.pool: x", refusal(spec))

    def test_refuses_a_shrunken_safe_box_outside_the_crop(self):
        spec = copy.deepcopy(self.pool); spec["safe"]["x"] = [0.1, 0.9]
        self.assertIn("safe.x", refusal(spec))

    def test_refuses_lawn_in_the_tap_band(self):
        spec = copy.deepcopy(self.pool); spec["camera"]["originBottomX"] = 0.05
        self.assertIn("tapBand", refusal(spec))

    def test_refuses_a_mark_on_the_lawn_and_a_route_off_the_path(self):
        spec = copy.deepcopy(self.pool); spec["marks"]["heroHome"] = [1.02, -1.9]
        self.assertIn("marks.heroHome", refusal(spec))
        spec = copy.deepcopy(self.pool); spec["marks"]["route"][2] = [3.0, 2.5]
        self.assertIn("marks.route[2]", refusal(spec))

    def test_refuses_a_hero_in_the_tap_band(self):
        spec = copy.deepcopy(self.pool); spec["marks"]["heroHome"] = [0.7, 0]
        self.assertIn("tap band", refusal(spec))

    def test_refuses_a_cast_that_is_too_small(self):
        spec = copy.deepcopy(self.pool); spec["camera"]["eyeHeightAdults"] = 3.0
        self.assertIn("cast:", refusal(spec))

    def test_refuses_columns_that_hide_the_pool(self):
        spec = copy.deepcopy(self.pool)
        next(el for el in spec["story"] if "minOpen" in el)["minOpen"]["ratio"] = 0.95
        self.assertIn("shows between its columns", refusal(spec))

    def test_refuses_unknown_kinds_fields_and_zones(self):
        spec = copy.deepcopy(self.pool); spec["paint"][0]["kind"] = "castle"
        self.assertIn("paint[0].kind", refusal(spec))
        spec = copy.deepcopy(self.pool); spec["paint"][0]["id"] = "moat"
        self.assertIn("paint[0].id", refusal(spec))
        spec = copy.deepcopy(self.pool); spec["paint"][1]["sideways"] = 1
        self.assertIn("paint[1]", refusal(spec))
        spec = copy.deepcopy(self.pool); spec["camera"]["roll"] = 3
        self.assertIn("camera", refusal(spec))

    def test_prompts_have_no_negation_and_name_every_painted_zone(self):
        for room in ("pool-garden", "ballroom"):
            for text in compiler.prompts(compiler.load_spec(room)).values():
                for word in (" no ", " not ", " without ", " never ", "Do not"):
                    self.assertNotIn(word, text)
        spec = copy.deepcopy(self.pool); del spec["zones"]["water"]
        with self.assertRaises(compiler.RoomError):
            compiler.prompts(spec)

    def test_level_fragment_uses_the_runtime_floor(self):
        _, cam, floor, _ = compiler.compile_room(self.pool)
        frag = compiler.level_fragment(self.pool, cam, floor)
        f = frag["stage"]["floor"]
        self.assertAlmostEqual((f["referenceFootY"] - f["horizonY"]) / f["referenceHeight"], cam.eye, places=2)
        wp = frag["departure"]["waypoints"]
        self.assertEqual((wp[0]["at"], wp[-1]["at"]), (0, 1))
        self.assertEqual(frag["departure"]["originY"], frag["stage"]["heroHome"][1])


class PlatformTest(unittest.TestCase):
    def test_the_bandstand_top_sits_on_the_accepted_plate(self):
        spec = compiler.load_spec("cool-crowd")
        cam = compiler.Camera(spec["camera"])
        top = compiler.platform_tops(spec, cam)[0]
        self.assertEqual(top["id"], "bandstand")
        self.assertGreater(top["heightAdults"], 0)
        # the corners measured by eye on the plate, to within a few pixels
        front = top["topCornersFrac"][1]
        rear = top["topCornersFrac"][2]
        self.assertAlmostEqual(front[0] * cam.W, 238, delta=16)
        self.assertAlmostEqual(front[1] * cam.H, 677, delta=16)
        self.assertAlmostEqual(rear[0] * cam.W, 300, delta=16)
        self.assertAlmostEqual(rear[1] * cam.H, 575, delta=16)

    def test_a_platform_must_name_one_box(self):
        spec = copy.deepcopy(compiler.load_spec("cool-crowd"))
        spec["platforms"] = [{"id": "x", "box": "nothing"}]
        with self.assertRaises(compiler.RoomError):
            compiler.platform_tops(spec, compiler.Camera(spec["camera"]))


if __name__ == "__main__":
    unittest.main()
