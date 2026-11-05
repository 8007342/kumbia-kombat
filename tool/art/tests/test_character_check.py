"""The build check catches A8 on real frames and flags missing clips, without failing a run."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import character_check as K  # noqa: E402
import definitions as D  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402


def figure(width: int, height: int = 300, arms: bool = False, canvas=(400, 400)) -> Image.Image:
    a = np.zeros((canvas[1], canvas[0], 4), np.uint8)
    cx = canvas[0] // 2
    a[50:50 + height, cx - width // 2 : cx + width // 2] = (120, 40, 90, 255)
    if arms:  # an arm held away from the body, in the measured band
        a[180:200, 20 : cx - width // 2 - 10] = (120, 40, 90, 255)
    return Image.fromarray(a, "RGBA")


class Measure(unittest.TestCase):
    def test_build_is_width_over_height(self):
        self.assertEqual(K.build_ratio(np.array(figure(150))[..., 3] > 128), 0.5)

    def test_it_ignores_size(self):
        a = np.array(figure(150))[..., 3] > 128
        b = np.array(figure(76, 152))[..., 3] > 128
        self.assertEqual(K.build_ratio(a), K.build_ratio(b))

    def test_an_arm_held_out_does_not_widen_the_body(self):
        self.assertEqual(K.build_ratio(np.array(figure(150, arms=True))[..., 3] > 128), 0.5)


class Check(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.c = D.load_character("bartender")
        self.table = Q.pose_table(self.c)
        self.c["drawing"].pop("buildReference")
        sheet = self.root / "sheet.png"
        figure(150).save(sheet)
        self.c["drawing"]["sheet"]["views"]["front"]["image"] = os.path.relpath(sheet, D.ROOT)

    def tearDown(self):
        self.tmp.cleanup()

    def frames(self, width, poses=None):
        out = self.root / "final"
        out.mkdir(exist_ok=True)
        for pid in poses if poses is not None else self.table:
            figure(width).save(out / f"{pid}.png")
        return out

    def test_a_skinny_wave_is_flagged_and_a_matching_one_is_not(self):
        self.assertEqual(K.check(self.c, self.frames(150))["advisories"], [])
        skinny = K.check(self.c, self.frames(100))
        self.assertEqual(len(skinny["advisories"]), 1)
        self.assertIn("33% narrower than the sheet", skinny["advisories"][0])

    def test_a_missing_clip_is_named(self):
        poses = [p for p, v in self.table.items() if v["clip"] != "clap"]
        rep = K.check(self.c, self.frames(150, poses))
        self.assertEqual(list(rep["missing"]), ["clap"])
        self.assertEqual(len(rep["missing"]["clap"]), 4)
        self.assertIn("in clap", rep["advisories"][0])

    def test_a_reserved_clip_is_not_missing(self):
        rep = K.check(D.load_character("macron"), self.root)
        self.assertEqual(rep["reservedClips"], ["signature_step"])
        self.assertNotIn("signature_step", rep["missing"])


class RealFrames(unittest.TestCase):
    """A8, measured on the committed frames: the reference is what the owner compared them with."""

    def test_the_skinny_gatekeeper_wave_is_caught(self):
        rep = K.check(D.load_character("gatekeeper"), ROOT / "art_runs/gatekeeper-v3-20261105q/final")
        self.assertEqual(rep["missing"], {})
        self.assertEqual((rep["build"]["sheet"], rep["build"]["frames"]), (0.396, 0.294))
        self.assertTrue(any("26% narrower than the sheet" in a for a in rep["advisories"]), rep["advisories"])

    def test_the_bartender_passes(self):
        rep = K.check(D.load_character("bartender"), ROOT / "art_runs/bartender-v1-20261105q/final")
        self.assertEqual(rep["advisories"], [])

    def test_advisories_exit_zero_unless_strict(self):
        base = [sys.executable, str(ART / "pipeline/character_check.py"), "gatekeeper", "--run", "gatekeeper-v3-20261105q"]
        r = subprocess.run(base, cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(json.loads(r.stdout)["advisories"])
        self.assertEqual(subprocess.run([*base, "--strict"], cwd=ROOT, capture_output=True).returncode, 1)


if __name__ == "__main__":
    unittest.main()
