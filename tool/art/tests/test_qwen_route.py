"""The Qwen route as data: prompts reproduce what the accepted run baked, and hand fixes survive."""
import copy
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import definitions as D  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402

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


if __name__ == "__main__":
    unittest.main()
