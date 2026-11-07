"""A cue in a dancer's hand: the free hand lands on its line, and it doesn't count toward her height."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pipeline"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "rig"))
import definitions as D  # noqa: E402
import plan_qwen_frames as Q  # noqa: E402
import register_frames as RF  # noqa: E402


class Cue(unittest.TestCase):
    def setUp(self):
        self.c = D.load_character("pool-player")
        self.rig = {"cue": [[0, 100], [0, 0]], "openpose": [[0, 0, 1]] * 18}
        self.rig["openpose"] = [[0, 0, 1]] * 4 + [[0, 80, 1]] + [[0, 0, 1]] * 13

    def test_a_pose_without_other_hand_moves_nothing(self):
        self.assertEqual(Q.hand_on_cue(self.c, self.rig, "groove.down_l"), {})

    def test_the_free_hand_goes_past_the_grip_along_the_cue(self):
        self.assertEqual(Q.hand_on_cue(self.c, self.rig, "clap.contact"), {"7": [0, 20]})

    def test_the_free_hand_can_go_to_the_tip(self):
        self.assertEqual(Q.hand_on_cue(self.c, self.rig, "challenge.load"), {"7": [0, 14]})

    def test_every_cue_override_names_a_real_pose(self):
        table = Q.pose_table(self.c)
        self.assertFalse(set(self.c["drawing"]["cue"]["poses"]) - set(table))

    def test_a_thin_cue_above_the_head_doesnt_count_toward_height(self):
        mask = np.zeros((300, 200), bool)
        mask[100:300, 60:140] = True   # the body
        mask[10:300, 30:42] = True     # a 12 px cue, far taller
        ys = np.where(RF.without_thin_prop(mask).any(axis=1))[0]
        self.assertEqual(int(ys.min()), 100)


if __name__ == "__main__":
    unittest.main()
