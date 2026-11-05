"""Mācron's route and a brand-new character, planned end to end with no GPU."""
import dataclasses
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
import art as A  # noqa: E402
import collect_qwen as CQ  # noqa: E402
import definitions as D  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402
import register_frames as RF  # noqa: E402
import score_frames as S  # noqa: E402
from stages import Store  # noqa: E402

FIXTURE = ART / "tests/fixtures/trial-dancer.json"
CLIPS = {"fist_bump": 3, "gulp": 3, "rear34_walk": 4, "high_five": 3}


class TempPaths(unittest.TestCase):
    def setUp(self):
        self.cwd = os.getcwd()
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.t = t
        for d in ("runs", "fam", "pal", "atlas", "lane"):
            (t / d).mkdir()
        self.paths = A.Paths(store=Store(t / "store"), runs=t / "runs", lane=t / "lane", families=t / "fam",
                             palettes=t / "pal", atlas_dir=t / "atlas")

    def tearDown(self):
        os.chdir(self.cwd)
        self.tmp.cleanup()


class Macron(TempPaths):
    def setUp(self):
        super().setUp()
        self.c = D.load_character("macron")

    def test_his_clips_and_the_reserved_slot(self):
        table = Q.pose_table(self.c)
        got = {}
        for p in table.values():
            got[p["clip"]] = got.get(p["clip"], 0) + 1
        self.assertEqual(got, CLIPS)
        self.assertEqual(Q.reserved_clips(self.c), ["signature_step"])
        declared = {m["id"]: m["drawings"] for m in Q.motion_of(self.c)["clips"]}
        self.assertEqual(declared, {**CLIPS, "signature_step": 0})

    def test_the_reserved_clip_has_no_invented_step(self):
        motion = Q.motion_of(self.c)
        self.assertFalse([p for p, v in motion["poses"].items() if v["clip"] == "signature_step"])

    def test_a_pose_in_a_reserved_clip_is_refused(self):
        real = D.load_motion
        def with_step(ident):
            m = real(ident)
            m["poses"]["signature_step.a"] = {"clip": "signature_step", "phase": "x", "view": "front", "description": "a step"}
            return m
        D.load_motion = with_step
        try:
            with self.assertRaisesRegex(D.DefinitionError, "reserved"):
                Q.pose_table(self.c)
        finally:
            D.load_motion = real

    def test_arms_are_named_by_picture_side_in_every_prompt_that_raises_one(self):
        prompts = Q.prompts(self.c, D.load_backend("qwen-frame"))
        for pid in ("fist_bump.contact", "high_five.contact", "gulp.sip"):
            self.assertIn("right side of the picture", prompts[pid], pid)
        self.assertIn("forearm on the right side of the picture only", prompts["rear34_walk.step_r"],
                      "from behind, his cuff arm is on the other side")
        self.assertNotIn("face screen with", prompts["rear34_walk.step_r"])

    def test_the_plan_holds_frames_until_the_sheet_is_approved(self):
        rep = A.build(self.c, self.paths, run="m", dry_run=False)
        self.assertEqual(rep["sheetQueued"], len(self.c["drawing"]["sheet"]["views"]))
        self.assertEqual((rep["queued"], rep["held"]), (0, 13))
        sheet = json.loads((self.paths.runs / "m/jobs.sheet.json").read_text())
        held = json.loads((self.paths.runs / "m/jobs.held.json").read_text())
        self.assertFalse((self.paths.runs / "m/jobs.json").exists())
        for job in sheet + held:
            self.assertEqual(list(job["args"]["inputs"]), ["sheet_front"], "no OpenPose for his body")
            graph = json.loads(Path(job["args"]["workflow"]).read_text())
            self.assertNotIn("2", graph, "no second image node left unbound: the studio refuses those")
            self.assertNotIn("image2", graph["10"]["inputs"])
            self.assertNotIn("image2", graph["11"]["inputs"])
        source = Image.open(sheet[0]["args"]["inputs"]["sheet_front"])
        self.assertEqual(source.size, (768, 960))
        self.assertEqual(source.getpixel((0, 0)), Q.GREY, "edit models get a flat background, not alpha")
        by_pose = {j["pose"]: j for j in held}
        self.assertTrue(by_pose["rear34_walk.step_r"]["args"]["inputs"]["sheet_front"].endswith("sheet_rear_three_quarter.png"))
        self.assertTrue(by_pose["gulp.sip"]["args"]["inputs"]["sheet_front"].endswith("sheet_front.png"))

    def test_jobs_with_no_skeleton_still_collect_to_their_pose(self):
        doc = {"inputs": [{"name": "sheet_front", "path": "/work/x"}], "workflow": {"path": "art_runs/r1/workflows/gulp.sip.api.json"}}
        self.assertEqual(CQ.pose_of(doc, "r1"), "gulp.sip")
        self.assertIsNone(CQ.pose_of(doc, "r2"))
        human = {"inputs": [{"name": "pose_proxy", "path": "/work/tmp/imagegen/kumbia/r1/in/clap.open.skeleton.png"}]}
        self.assertEqual(CQ.pose_of(human, "r1"), "clap.open")
        self.assertIsNone(CQ.pose_of(human, "r2"))

    def test_the_scorer_refuses_him(self):
        r = subprocess.run([sys.executable, str(ART / "pipeline/score_frames.py"), "--run", "x", "--family", "macron-v1"],
                           cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("posed by words", r.stderr)

    def test_registration_fixes_height_and_floor_for_any_drawn_size(self):
        spec = self.c["drawing"]["register"]
        for height, bottom, x in ((400, 800, 300), (610, 900, 420)):
            a = np.zeros((960, 768, 4), np.uint8)
            a[bottom - height:bottom, x - 60:x + 60] = (200, 180, 150, 255)
            a[bottom - height + 80:bottom - height + 100, x + 60:x + 110] = (200, 180, 150, 255)  # a raised arm
            src, dst = self.t / f"in{height}.png", self.t / f"out{height}.png"
            Image.fromarray(a, "RGBA").save(src)
            RF.register_fixed(src, dst, spec)
            m = np.array(Image.open(dst))[..., 3] > 128
            ys, xs = np.where(m)
            self.assertAlmostEqual(ys.max() + 1 - ys.min(), spec["standingHeightPx"], delta=3)
            self.assertAlmostEqual(ys.max() + 1, spec["floorY"], delta=3)
            feet = np.where(m[spec["floorY"] - 40 : spec["floorY"] - 4])[1]
            self.assertAlmostEqual(float(np.median(feet)), spec["centerX"], delta=3, msg="the arm must not shift the body")

    def test_a_shorter_pose_says_so_in_its_motion_data(self):
        spec = self.c["drawing"]["register"]
        a = np.zeros((960, 768, 4), np.uint8)
        a[300:800, 300:420] = (200, 180, 150, 255)
        src, dst = self.t / "in.png", self.t / "out.png"
        Image.fromarray(a, "RGBA").save(src)
        RF.register_fixed(src, dst, spec, 0.9)
        ys = np.where(np.array(Image.open(dst))[..., 3] > 128)[0]
        self.assertAlmostEqual(ys.max() + 1 - ys.min(), spec["standingHeightPx"] * 0.9, delta=3)

    def test_pixels_per_unit_matches_the_live_atlas_scale(self):
        """A standing frame must come out as tall in world units as the hero's front_idle."""
        spec = self.c["drawing"]["register"]
        live = json.loads((ROOT / "assets/art/party/manifest.json").read_text())["atlases"]["hero"]["frames"][spec["referenceFrame"]]
        world = live["rect"][3] / live["pixelsPerUnit"]
        self.assertEqual(spec["referenceWorldHeight"], world)
        native = spec["standingHeightPx"] / spec["pixelScale"]
        self.assertAlmostEqual(native / RF.pixels_per_unit(spec), world, places=3)

    def test_the_committed_plan_is_what_the_definition_generates(self):
        """art_runs/macron-v1-planned must not drift from the data it was generated from."""
        paths = dataclasses.replace(self.paths, lane=Q.STAGE)  # stage=False writes nothing there
        rep = A.build(self.c, paths, run="macron-v1-planned", stage=False)
        self.assertFalse((self.paths.runs / "selections").exists())
        self.assertEqual(rep["held"], 13)
        fresh, committed = self.paths.runs / "macron-v1-planned", ROOT / "art_runs/macron-v1-planned"
        for name in ("jobs.sheet.json", "jobs.held.json"):
            mine = json.loads((fresh / name).read_text())
            theirs = json.loads((committed / name).read_text())
            self.assertEqual([(j["pose"], j["args"]["inputs"], j["args"]["overrides"]) for j in mine],
                             [(j["pose"], j["args"]["inputs"], j["args"]["overrides"]) for j in theirs])
            for j in mine:
                a = json.loads((fresh / "workflows" / f"{j['pose']}.api.json").read_text())
                b = json.loads((committed / "workflows" / f"{j['pose']}.api.json").read_text())
                self.assertEqual(a, b, j["pose"])


class NewCharacter(TempPaths):
    """Point 7: a definition and one command give prompts, job count and cost."""

    def test_the_dry_run_needs_no_rig_gpu_or_blender(self):
        env = {**os.environ, "KUMBIA_ART_CACHE": str(self.t / "store"), "KUMBIA_BPY_PYTHON": "/nonexistent"}
        r = subprocess.run([sys.executable, str(ART / "pipeline/art.py"), "build", str(FIXTURE), "--dry-run", "--prompts"],
                           cwd=ROOT, capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        rep = json.loads(r.stdout)
        self.assertEqual(rep["jobs"], {"sheet": 1, "frames": 0, "held": 64})
        self.assertEqual((rep["jobsTotal"], rep["estimatedImages"], rep["estimatedMinutes"]), (65, 260, 99.7))
        self.assertEqual(rep["rigRender"], "needed")
        self.assertEqual(len(rep["prompts"]), 64)
        self.assertIn("They keep their tall, long-limbed adult build", rep["prompts"]["clap.close"])
        self.assertFalse((ROOT / "art_runs/inputs/trial-dancer-v1").exists(), "a dry run writes nothing")

    def test_its_sheet_prompt_reads_properly(self):
        c = D.load_character(str(FIXTURE))
        text = Q.sheet_prompt(c, D.load_backend("qwen-frame"), "front")
        self.assertIn("Image 1 shows the art style only", text)
        self.assertIn("They have their tall", text)
        self.assertNotIn("{", text)

    def test_its_dress_scores_without_trousers(self):
        c = D.load_character(str(FIXTURE))
        parts = S.part_colours(c, D.load_style("party-pixel"))
        self.assertEqual((len(parts["kne"]), parts["tolerance"]), (1, 40))


if __name__ == "__main__":
    unittest.main()
