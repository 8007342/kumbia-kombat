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


if __name__ == "__main__":
    unittest.main()
