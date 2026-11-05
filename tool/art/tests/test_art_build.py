"""art.py chain, no GPU: first build queues, ingest then packs, rebuilds are incremental."""
import copy
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import art as A  # noqa: E402
import colour as C  # noqa: E402
import definitions as D  # noqa: E402
from stages import Store  # noqa: E402


class Chain(unittest.TestCase):
    """One flow, since each step needs the store the previous step left behind."""

    @classmethod
    def setUpClass(cls):
        cls.cwd = os.getcwd()
        os.chdir(ROOT)
        cls.tmp = tempfile.TemporaryDirectory()
        t = Path(cls.tmp.name)
        for d in ("runs", "fam", "pal", "atlas", "lane"):
            (t / d).mkdir()
        cls.paths = A.Paths(store=Store(t / "store"), runs=t / "runs", lane=t / "lane", families=t / "fam", palettes=t / "pal", atlas_dir=t / "atlas")
        cls.c = D.load_character("gatekeeper")
        cls.c["backend"] = "sdxl-base-1"  # this chain proves the older route stays selectable
        cls.style = D.load_style("party-pixel")
        cls.rig = json.loads((ROOT / "art_runs/inputs/gatekeeper-v3/rig.json").read_text())
        ramps = C.build_ramps(cls.c, cls.style)
        cls.hat_shade = ramps["hat"]["shades"][1]
        cls.shirt_shade = ramps["shirt"]["shades"][1]
        # First build: everything queues, then finished frames arrive and pack.
        cls.first = A.build(cls.c, cls.paths, rig=cls.rig)
        final = t / "runs" / cls.first["run"] / "final"
        final.mkdir(parents=True)
        for i, p in enumerate(cls.rig["poses"]):
            a = np.zeros((120, 96, 4), np.uint8)
            a[10:40, 20:70] = (*C.hex_to_rgb(cls.hat_shade), 255)
            a[40:100, 20:70] = (*C.hex_to_rgb(cls.shirt_shade), 255)
            a[100, 20 + i] = (*C.hex_to_rgb(cls.style["outline"]), 255)  # every frame unique
            Image.fromarray(a, "RGBA").save(final / f"{p['id']}.png")
        cls.ingested = A.ingest(cls.c, cls.first["run"], cls.paths)
        cls.packed = A.build(cls.c, cls.paths, rig=cls.rig)
        cls.atlas = (t / "atlas" / "gatekeeper-v3.png").read_bytes()

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.cwd)
        cls.tmp.cleanup()

    def edited(self, **colours):
        c = copy.deepcopy(self.c)
        for g in c["garments"]:
            if g["id"] in colours:
                g["colour"] = colours[g["id"]]
        return c

    def test_1_first_build_queues_every_pose(self):
        self.assertEqual(self.first["queued"], 64)
        self.assertTrue(self.first["gpu"])
        self.assertFalse(self.first["packed"])
        jobs = json.loads((self.paths.runs / self.first["run"] / "jobs.json").read_text())
        self.assertEqual(len(jobs), 64)

    def test_2_ingest_then_build_packs_without_jobs(self):
        self.assertEqual(self.ingested["missing"], [])
        self.assertEqual(self.packed["counts"], {"reuse": 64})
        self.assertTrue(self.packed["packed"])
        self.assertFalse(self.packed["gpu"])

    def test_3_unchanged_rebuild_queues_nothing_and_is_byte_identical(self):
        again = A.build(self.c, self.paths, rig=self.rig)
        self.assertEqual(again["queued"], 0)
        self.assertEqual(again["run"], self.packed["run"])
        self.assertEqual((self.paths.atlas_dir / "gatekeeper-v3.png").read_bytes(), self.atlas)

    def test_4_dry_run_changes_nothing(self):
        before = sorted(str(p) for p in Path(self.tmp.name).rglob("*"))
        rep = A.build(self.edited(hat="#B3202A"), self.paths, rig=self.rig, dry_run=True)
        self.assertEqual(rep["counts"], {"recolour": 64})
        self.assertEqual(before, sorted(str(p) for p in Path(self.tmp.name).rglob("*")))

    def test_5_colour_edit_recolours_with_no_jobs_and_revert_reuses(self):
        red = self.edited(hat="#B3202A")
        rep = A.build(red, self.paths, rig=self.rig)
        self.assertEqual(rep["queued"], 0)
        self.assertFalse(rep["gpu"])
        self.assertEqual(rep["recoloured"], 64)
        self.assertTrue(rep["packed"])
        self.assertFalse((self.paths.runs / rep["run"] / "jobs.json").exists())
        pid = self.rig["poses"][0]["id"]
        a = np.asarray(Image.open(self.paths.runs / self.packed["run"] / "final" / f"{pid}.png"))
        b = np.asarray(Image.open(self.paths.runs / rep["run"] / "final" / f"{pid}.png"))
        hat = np.all(a[..., :3] == C.hex_to_rgb(self.hat_shade), axis=-1) & (a[..., 3] > 0)
        self.assertTrue(hat.any())
        self.assertTrue(np.array_equal(a[~hat], b[~hat]), "pixels outside the hat must be byte-identical")
        self.assertFalse(np.array_equal(a[hat], b[hat]))
        # Revert: the earlier frames come straight back from the store.
        back = A.build(self.c, self.paths, rig=self.rig)
        self.assertEqual(back["counts"], {"reuse": 64})
        self.assertEqual(back["recoloured"], 0)
        self.assertEqual((self.paths.atlas_dir / "gatekeeper-v3.png").read_bytes(), self.atlas)

    def test_6_body_change_plans_full_regeneration(self):
        c = copy.deepcopy(self.c)
        c["body"]["overrides"] = {"head_r": 0.2}
        rep = A.build(c, self.paths, rig=self.rig, dry_run=True)
        self.assertEqual(rep["counts"], {"full": 64})
        self.assertTrue(rep["gpu"])

    def test_7_gate_violation_refused_before_work(self):
        with self.assertRaises(C.GateViolation):
            A.build(self.edited(hat="#C03CA0"), self.paths, rig=self.rig, dry_run=True)

    def test_8_derived_reference_holds_jobs_until_accepted(self):
        c = copy.deepcopy(self.c)
        c["references"]["mode"] = "derive"
        c["traits"] = c["traits"] + ", new"
        rep = A.build(c, self.paths, rig=self.rig)
        self.assertEqual(rep["queued"], 0)
        self.assertEqual(rep["held"], 64)
        self.assertTrue((self.paths.runs / rep["run"] / "jobs.held.json").exists())
        self.assertFalse((self.paths.runs / rep["run"] / "jobs.json").exists())
        A._write(self.paths.runs / "references" / "gatekeeper.json",
                 {"key": A.reference_key(c, self.style), "accepted": True, "image": str(ROOT / "assets/art/bar/bartender.png")})
        rep = A.build(c, self.paths, rig=self.rig)
        self.assertEqual(rep["queued"], 64)
        self.assertEqual(rep["held"], 0)
        (self.paths.runs / "references" / "gatekeeper.json").unlink()


if __name__ == "__main__":
    unittest.main()
