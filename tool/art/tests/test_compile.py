"""The compiler reproduces the studio-facing facts of the pre-compiler Gatekeeper spec."""
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import colour as C  # noqa: E402
import compile_family as CF  # noqa: E402
import definitions as D  # noqa: E402
from sync_family import apply_rig  # noqa: E402

BASELINE = "37f04af"  # last commit with the hand-maintained family spec


def baseline_spec():
    out = subprocess.run(["git", "show", f"{BASELINE}:tool/art/families/gatekeeper-v3.json"],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return json.loads(out)


class Compile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec, cls.palette, motion = CF.compile_character("gatekeeper")
        cwd = os.getcwd()
        os.chdir(ROOT)
        apply_rig(cls.spec, motion.get("research"))
        os.chdir(cwd)
        cls.old = baseline_spec()

    def test_pose_ids_count_and_order_match(self):
        self.assertEqual([p["id"] for p in self.spec["poses"]], [p["id"] for p in self.old["poses"]])
        self.assertEqual(len(self.spec["poses"]), 64)

    def test_prompt_matches(self):
        # The character prompt moved on from the baseline with the owner's style guide (2026-11-04).
        self.assertIn("clean-shaven", self.spec["character_prompt"])
        self.assertIn("beard", self.spec["style_negative"])
        self.assertEqual(self.spec["style_prompt"], self.old["style_prompt"])

    def test_clip_and_profile_data_match(self):
        self.assertEqual(self.spec["clips"], self.old["clips"])
        self.assertEqual(self.spec["generation"]["profileRules"], self.old["generation"]["profileRules"])
        self.assertEqual([p["profile"] for p in self.spec["poses"]], [p["profile"] for p in self.old["poses"]])
        self.assertEqual(self.spec["generation"]["seed_base"], self.old["generation"]["seed_base"])

    def test_palette_has_one_ramp_per_colour_and_fails_gates(self):
        cols = self.palette["colours"]
        self.assertEqual(len(cols), len(set(cols)))
        for col in cols:
            self.assertEqual(C.gates_hit(C.hex_to_rgb(col), self.spec["reservedRamps"]), [], col)


if __name__ == "__main__":
    unittest.main()
