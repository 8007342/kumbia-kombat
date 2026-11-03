"""Renderer tests. Run with the bpy venv; skipped where Blender's module is absent:
~/.cache/kumbia-bpy/bin/python -m unittest tool/art/tests/test_rig.py
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART / "rig"))
try:
    import standin
    from PIL import Image
except ImportError:  # no bpy here
    standin = None

ALL_SHAPES = {
    "id": "fixture", "family": "fixture", "style": "party-pixel", "status": "rig-only",
    "body": {"preset": "slim-adult"}, "pronouns": ["she", "her", "her"], "skin": "#B5784A",
    "garments": [
        {"id": "hat", "shape": "brimmed-hat", "region": "hat", "colour": "#B3202A"},
        {"id": "band", "shape": "hat-band", "region": "accessory", "colour": "#29737A"},
        {"id": "hair", "shape": "puff", "region": "hair", "colour": "#2A1712"},
        {"id": "shirt", "shape": "shirt-fitted", "region": "shirt", "colour": "#E8DDC2"},
        {"id": "sleeves", "shape": "sleeve-rolled", "region": "shirt", "colour": "#E8DDC2"},
        {"id": "waistcoat", "shape": "waistcoat-fitted", "region": "cloth", "colour": "#0F5A5E"},
        {"id": "apron", "shape": "waist-apron", "region": "apron", "colour": "#7A1F57"},
        {"id": "trousers", "shape": "trousers", "region": "trousers", "colour": "#3A1A38"},
        {"id": "shoes", "shape": "shoes-heeled", "region": "shoes", "colour": "#C98A1E"},
    ],
    "props": [{"id": "shaker", "kind": "shaker", "hand": "right", "colour": "#BFC6CC"}],
    "motion": {"set": "opponent-64"},
}


@unittest.skipIf(standin is None, "needs bpy")
class Library(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        cls.rig = standin.Rig.from_definition(ALL_SHAPES)
        pose, support = cls.rig.clips["groove"]["down_l"]
        cls.rec = standin.render_pose(cls.rig, "floor-perspective", "groove.down_l", pose, support, cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_every_declared_region_renders(self):
        self.assertEqual(self.rec["problems"], [])
        missing = [r for r, n in self.rec["regionPixels"].items() if n == 0]
        self.assertEqual(missing, [], self.rec["regionPixels"])

    def test_regions_are_dynamic(self):
        self.assertIn("apron", self.rig.regions)
        self.assertIn("prop", self.rig.regions)
        self.assertNotIn("shell", self.rig.regions)

    def test_undeclared_colour_fails(self):
        path = self.out / "groove.down_l.regions.png"
        narrow = {k: v for k, v in self.rig.regions.items() if k != "apron"}
        problems = standin.check_regions(path, narrow)
        self.assertTrue(any("undeclared" in p for p in problems), problems)

    def test_mask_colours_are_exact(self):
        a = np.asarray(Image.open(self.out / "groove.down_l.regions.png").convert("RGBA"))
        self.assertTrue(np.all((a[..., 3] == 0) | (a[..., 3] == 255)))


@unittest.skipIf(standin is None, "needs bpy")
class SecondaryMotion(unittest.TestCase):
    """Consecutive drawings: a lag-1 hem sits toward where the hips were one drawing ago."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def render(self, lag: bool, pid: str):
        d = json.loads(json.dumps(ALL_SHAPES))
        for g in d["garments"]:
            if g["id"] == "apron" and lag:
                g["secondaryMotion"] = "lag-1"
        rig = standin.Rig.from_definition(d)
        clip, name = pid.split(".", 1)
        pose, support = rig.clips[clip][name]
        out = self.out / ("lag" if lag else "base") / pid
        out.mkdir(parents=True, exist_ok=True)
        rec = standin.render_pose(rig, "floor-perspective", pid, pose, support, out)
        a = np.asarray(Image.open(out / f"{pid}.regions.png").convert("RGB"))
        ys, xs = np.nonzero(np.all(a == standin.hex_rgb_255(rig.regions["apron"]), axis=-1))
        below = ys > np.percentile(ys, 70)  # the hem, not the waistband
        return float(xs[below].mean()), rec, rig

    def test_hem_trails_the_hips_across_consecutive_drawings(self):
        prev_id, pid = "groove.up_l", "groove.pass_l2"
        hem, rec, rig = self.render(True, pid)
        base, _, _ = self.render(False, pid)
        _, prev_rec, _ = self.render(False, prev_id)
        hips = lambda r: (r["joints"]["l_hip"][0] + r["joints"]["r_hip"][0]) / 2  # noqa: E731
        moved = hips(rec) - hips(prev_rec)
        self.assertGreater(abs(moved), 4, "fixture needs hips that really move between these drawings")
        self.assertLess((hem - base) * moved, 0, f"hem {hem} vs {base} should trail hip motion {moved}")

    def test_previous_drawing_wraps_only_in_loops(self):
        rig = standin.Rig.from_definition(ALL_SHAPES)
        self.assertIs(standin.previous_drawing(rig, "groove", "down_l"), rig.clips["groove"]["pass_r2"])
        self.assertIsNone(standin.previous_drawing(rig, "left_hand", "prep"))
        self.assertIs(standin.previous_drawing(rig, "left_hand", "peak"), rig.clips["left_hand"]["prep"])

    def test_no_lag_at_a_one_shot_start(self):
        a, _, _ = self.render(True, "left_hand.prep")
        b, _, _ = self.render(False, "left_hand.prep")
        self.assertAlmostEqual(a, b, delta=4.0)


if __name__ == "__main__":
    unittest.main()
