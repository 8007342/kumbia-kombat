"""The Qwen route as data: prompts reproduce what the accepted run baked, and hand fixes survive."""
import copy
import json
import os
import re
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
import plan_qwen_frames as Q  # noqa: E402
from stages import Store  # noqa: E402

RUN = "bartender-v1-20261105q"
HAND_EDITED = {"clap.open", "groove.pass_l2"}


def baked(pid: str) -> dict:
    return json.loads((ROOT / "art_runs" / RUN / "workflows" / f"{pid}.api.json").read_text())


class BartenderReproduces(unittest.TestCase):
    """The run the owner accepted is the proof that moving the text to data changed nothing."""

    @classmethod
    def setUpClass(cls):
        cls.c = D.load_character("bartender")
        cls.backend = D.load_backend("qwen-frame")
        cls.prompts = Q.prompts(cls.c, cls.backend)

    def test_every_pose_equals_the_baked_prompt(self):
        self.assertEqual(len(self.prompts), 64)
        different = [p for p, text in self.prompts.items() if text != baked(p)["10"]["inputs"]["prompt"]]
        self.assertEqual(different, [])

    def test_the_two_hand_edits_exist_only_as_overrides(self):
        """Without the data override, these two go back to the pose table's disagreeing words."""
        bare = copy.deepcopy(self.c)
        bare["drawing"].pop("poseOverrides")
        different = {p for p, text in Q.prompts(bare, self.backend).items() if text != baked(p)["10"]["inputs"]["prompt"]}
        self.assertEqual(different, HAND_EDITED)

    def test_pose_table_matches_the_rendered_rig_intents(self):
        rendered = json.loads((ROOT / "art_runs/inputs/bartender-v1/poses.intent.json").read_text())["poses"]
        self.assertEqual(Q.pose_table(self.c), rendered)

    def test_job_plan_matches_the_accepted_jobs(self):
        with tempfile.TemporaryDirectory() as t:
            planned = Q.plan_run(self.c, self.backend, RUN, runs_root=Path(t), stage=False)
            self.assertEqual(planned["sheet"], [])
            old = json.loads((ROOT / "art_runs" / RUN / "jobs.json").read_text())
            mine = {j["pose"]: j["args"] for j in planned["frames"]}
            self.assertEqual({j["pose"] for j in old}, set(mine))
            for j in old:
                got = mine[j["pose"]]
                self.assertEqual(got["inputs"], j["args"]["inputs"], j["pose"])
                self.assertEqual((got["tier"], got["count"], got["overrides"]), (j["args"]["tier"], j["args"]["count"], j["args"]["overrides"]))
            # Beyond the prompt, the baked graph must be the one the route still uses.
            graph = json.loads(Path(mine["groove.down_l"]["workflow"]).read_text())
            self.assertEqual(graph, baked("groove.down_l"))


class GatekeeperV4(unittest.TestCase):
    """The peer's A8 wording, moved to data, against the workflows its pilot baked from CAST."""

    def test_every_pose_equals_the_v4_plan(self):
        run = ROOT / "art_runs/gatekeeper-v4-20261105q"
        prompts = Q.prompts(D.load_character("gatekeeper"), D.load_backend("qwen-frame"))
        self.assertEqual(len(prompts), 64)
        for pid, text in prompts.items():
            baked_v4 = json.loads((run / "workflows" / f"{pid}.api.json").read_text())
            self.assertEqual(text, baked_v4["10"]["inputs"]["prompt"], pid)

    def test_a_trial_sheet_replaces_the_front_without_touching_it(self):
        c = D.load_character("gatekeeper")
        accepted = (ROOT / "tool/art/references/gatekeeper/front.png").read_bytes()
        with tempfile.TemporaryDirectory() as t:
            lane, runs = Path(t) / "lane", Path(t) / "runs"
            Q.plan_run(c, D.load_backend("qwen-frame"), "r", only=set(), runs_root=runs, lane_root=lane,
                       sheet=str(ROOT / "tool/art/references/gatekeeper/front-stocky.png"))
            staged = (lane / "r/in/sheet_front.png").read_bytes()
        self.assertEqual(staged, (ROOT / "tool/art/references/gatekeeper/front-stocky.png").read_bytes())
        self.assertEqual(accepted, (ROOT / "tool/art/references/gatekeeper/front.png").read_bytes())


class Wording(unittest.TestCase):
    def setUp(self):
        self.c = copy.deepcopy(D.load_character("bartender"))
        self.backend = D.load_backend("qwen-frame")

    def test_a_prop_names_its_hand_by_picture_side_by_default(self):
        self.c["props"][0].pop("wording")
        text = Q.prompts(self.c, self.backend)["groove.down_l"]
        self.assertIn("in the hand on the left side of the picture; her other hand is empty.", text)
        self.assertNotIn("her right hand", text)

    def test_a_prop_stays_out_of_clips_that_do_not_carry_it(self):
        self.assertNotIn("shaker", Q.prompts(self.c, self.backend)["clap.close"])

    def test_they_them_agree_with_their_verbs(self):
        self.c["pronouns"] = ["they", "them", "their"]
        self.c["drawing"]["poseOverrides"] = {}
        text = Q.prompts(self.c, self.backend)["groove.down_l"]
        self.assertIn("They keep their ", text)
        self.assertIn("They have exactly two arms", text)
        self.assertIn("they face the viewer", text)
        self.assertNotIn("They keeps", text)

    def test_no_unfilled_template_field_reaches_a_prompt(self):
        for cid in ("gatekeeper", "bartender"):
            for pid, text in Q.prompts(D.load_character(cid), self.backend).items():
                self.assertIsNone(re.search(r"[{}]", text), pid)

    def test_a_fix_for_an_unknown_pose_is_refused(self):
        self.c["drawing"]["poseOverrides"]["clap.opne"] = {"description": "typo"}
        with self.assertRaisesRegex(D.DefinitionError, r"drawing.poseOverrides.clap.opne: unknown pose"):
            Q.prompts(self.c, self.backend)


class Build(unittest.TestCase):
    """art.py on the default route, no GPU: the plan, then a wave's whole bookkeeping."""

    @classmethod
    def setUpClass(cls):
        cls.cwd = os.getcwd()
        os.chdir(ROOT)
        cls.tmp = tempfile.TemporaryDirectory()
        cls.t = Path(cls.tmp.name)
        for d in ("runs", "fam", "pal", "atlas", "lane"):
            (cls.t / d).mkdir()
        cls.paths = A.Paths(store=Store(cls.t / "store"), runs=cls.t / "runs", lane=cls.t / "lane",
                            families=cls.t / "fam", palettes=cls.t / "pal", atlas_dir=cls.t / "atlas")
        cls.bar = D.load_character("bartender")
        cls.gk = D.load_character("gatekeeper")
        cls.rig = json.loads((ROOT / "art_runs/inputs/gatekeeper-v3/rig.json").read_text())

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.cwd)
        cls.tmp.cleanup()

    def dry(self, c, **kw):
        return A.build(c, self.paths, dry_run=True, **kw)

    def test_accepted_frames_cost_nothing(self):
        rep = self.dry(self.bar)
        self.assertEqual(rep["counts"], {"accepted": 64})
        self.assertEqual((rep["jobsTotal"], rep["estimatedImages"], rep["gpu"]), (0, 0, False))

    def test_a_look_edit_redraws_all_and_says_what_it_costs(self):
        c = copy.deepcopy(self.bar)
        c["drawing"]["look"] += ", red scarf"
        rep = self.dry(c)
        self.assertEqual(rep["counts"], {"full": 64})
        self.assertEqual(rep["redrawReasons"], {"prompt differs from the accepted run": 64})
        self.assertEqual((rep["jobsTotal"], rep["estimatedImages"], rep["estimatedMinutes"]), (64, 256, 98.1))

    def test_one_fix_redraws_one_pose(self):
        c = copy.deepcopy(self.bar)
        c["drawing"]["poseOverrides"]["clap.close"] = {"description": "hands nearly meeting at chest height"}
        rep = self.dry(c)
        self.assertEqual(rep["counts"], {"accepted": 63, "full": 1})
        self.assertEqual((rep["jobsTotal"], rep["estimatedImages"]), (1, 4))
        self.assertEqual(list(rep["samplePrompt"]), ["clap.close"])

    def test_the_old_route_stays_selectable(self):
        rig = json.loads((ROOT / "art_runs/inputs/bartender-v1/rig.json").read_text())
        rep = self.dry(self.bar, backend_id="sdxl-base-1", rig=rig)
        self.assertEqual(rep["estimatedImages"], 256)

    def test_a_dry_run_writes_nothing(self):
        before = sorted(str(p) for p in self.t.rglob("*"))
        self.dry(self.gk, show_prompts=True)
        self.assertEqual(before, sorted(str(p) for p in self.t.rglob("*")))

    def test_a_wave_queues_ingests_packs_and_recolours(self):
        first = A.build(self.gk, self.paths, rig=self.rig, run="wave")
        self.assertEqual((first["queued"], first["held"], first["packed"]), (64, 0, False))
        jobs = json.loads((self.paths.runs / "wave" / "jobs.json").read_text())
        self.assertEqual(len(jobs), 64)
        moved = next(j for j in jobs if j["pose"] == "clap.open")
        self.assertTrue(Path(moved["args"]["inputs"]["pose_proxy"]).exists())
        self.assertTrue((self.paths.lane / "wave" / "in" / "clap.open.adjusted.png").exists(), "skeleton overrides reach the drawing")
        baked = json.loads(Path(moved["args"]["workflow"]).read_text())
        self.assertIn("standing in that exact pose", baked["10"]["inputs"]["prompt"])
        shirt = C.build_ramps(self.gk, D.load_style("party-pixel"))["shirt"]["shades"][1]
        final = self.paths.runs / "wave" / "final"
        final.mkdir(parents=True)
        for i, pid in enumerate(j["pose"] for j in jobs):
            a = np.zeros((120, 96, 4), np.uint8)
            a[40:100, 20:70] = (*C.hex_to_rgb(shirt), 255)
            a[100, 20 + i] = (0x1A, 0x10, 0x18, 255)
            Image.fromarray(a, "RGBA").save(final / f"{pid}.png")
        self.assertEqual(A.ingest(self.gk, "wave", self.paths)["missing"], [])
        packed = A.build(self.gk, self.paths, rig=self.rig, run="wave")
        self.assertEqual(packed["counts"], {"reuse": 64})
        self.assertTrue(packed["packed"])

        def edited(**drawing):
            c = copy.deepcopy(self.gk)
            c["drawing"].update(drawing)
            return c

        recoloured = copy.deepcopy(self.gk)
        next(g for g in recoloured["garments"] if g["id"] == "shirt")["colour"] = "#27548A"
        rep = self.dry(recoloured, rig=self.rig)
        self.assertEqual(rep["counts"].get("full", 0), 0, "a colour edit needs no GPU")
        self.assertGreater(rep["counts"]["recolour"], 0)
        look = self.dry(edited(look=self.gk["drawing"]["look"] + ", wide round face"), rig=self.rig)
        self.assertEqual(look["counts"], {"full": 64})
        self.assertEqual(look["redrawReasons"], {"prompt changed": 64})
        fix = self.dry(edited(poseOverrides={"clap.close": {"description": "hands nearly meeting"}}), rig=self.rig)
        self.assertEqual(fix["counts"], {"full": 1, "reuse": 63})


if __name__ == "__main__":
    unittest.main()
