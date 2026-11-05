"""The scorer reads colours from the definition, handles skirts, and refuses bad scores loudly."""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import colour as C  # noqa: E402
import definitions as D  # noqa: E402
import score_frames as S  # noqa: E402

W, H = 200, 400
SKIN = (226, 136, 69)
SHIRT = (232, 221, 194)
SHOE = (224, 138, 30)


def openpose(wrist=(40, 200), knee=(90, 300), ankle=(90, 380)):
    """COCO-18, with only the joints the scorer reads made visible."""
    pts = [[0, 0, 0] for _ in range(18)]
    pts[0] = [100, 40, 1]
    pts[4] = [*wrist, 1]
    pts[7] = [W - wrist[0], wrist[1], 1]
    pts[3] = [60, 160, 1]
    pts[6] = [W - 60, 160, 1]
    pts[9] = [*knee, 1]
    pts[12] = [W - knee[0], knee[1], 1]
    pts[10] = [*ankle, 1]
    pts[13] = [W - ankle[0], ankle[1], 1]
    return {"openpose": pts, "headWidthPx": 40}


def dancer(leg_colour, hands=True, legs=True):
    """A flat figure: arms, torso, a garment from waist to shin, and shoes, on transparent."""
    a = np.zeros((H, W, 4), np.uint8)
    a[20:60, 80:120] = (*SKIN, 255)
    a[60:220, 60:140] = (*SHIRT, 255)
    a[150:165, 40:160] = (*SHIRT, 255)
    if hands:
        a[190:210, 30:50] = (*SKIN, 255)
        a[190:210, 150:170] = (*SKIN, 255)
        a[160:190, 35:45] = (*SHIRT, 255)
        a[160:190, 155:165] = (*SHIRT, 255)
    if legs:
        a[220:370, 60:140] = (*leg_colour, 255)
        a[370:395, 70:130] = (*SHOE, 255)
    return a


def definition(colour="#7A223D", **score):
    """A dancer in a dress: no trousers garment anywhere."""
    c = copy.deepcopy(D.load_character("bartender"))
    c["garments"] = [g for g in c["garments"] if g["region"] != "trousers"]
    c["garments"].append({"id": "dress", "shape": "waist-apron", "region": "cloth", "colour": colour})
    c["garments"] = [g for g in c["garments"] if g["id"] != "waistcoat"]
    c["drawing"]["score"] = {"knee": ["dress"], **score}
    return c


class Parts(unittest.TestCase):
    def setUp(self):
        self.style = D.load_style("party-pixel")

    def test_existing_characters_keep_the_family_colours(self):
        """Moving colours to the definition must not change how the accepted runs rank."""
        for cid, family in (("gatekeeper", "gatekeeper-v3"), ("bartender", "bartender-v1")):
            proxy = json.loads((ART / "families" / f"{family}.json").read_text())["regionProxyColours"]
            parts = S.part_colours(D.load_character(cid), self.style)
            self.assertEqual(C.rgb_to_hex(parts["kne"][0]), proxy["trousers"].upper())
            self.assertEqual(C.rgb_to_hex(parts["ank"][0]), proxy["shoes"].upper())
            self.assertEqual(parts["tolerance"], S.TOLERANCE)

    def test_a_skirted_dancer_without_score_data_is_refused_by_name(self):
        c = definition()
        c["drawing"].pop("score")
        with self.assertRaisesRegex(S.ScoreFailure, "drawing.score.knee: no trousers garment"):
            S.part_colours(c, self.style)

    def test_an_unknown_part_is_refused(self):
        with self.assertRaisesRegex(S.ScoreFailure, "unknown part"):
            S.part_colours(definition(ankle=["clogs"]), self.style)


class Skirt(unittest.TestCase):
    """Synthetic frames: the rig's knee sits inside the skirt, and no trousers exist to find."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.style = D.load_style("party-pixel")
        self.pose = openpose()
        self.rig_mask = dancer((90, 30, 60))[..., 3] > 0
        self.parts = S.part_colours(definition(), self.style)
        self.skirt = tuple(int(v) for v in self.parts["kne"][0])

    def tearDown(self):
        self.tmp.cleanup()

    def save(self, name, a):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(a, "RGBA").save(p)
        return p

    def test_knees_inside_a_skirt_score_on_the_skirt(self):
        m = S.measure(self.save("good.png", dancer(self.skirt)), self.pose, self.rig_mask, self.parts)
        self.assertEqual((m["errors"]["r_kne"], m["errors"]["l_kne"]), (0.0, 0.0))
        self.assertEqual(m["lost"], [])

    def test_the_old_trousers_assumption_would_have_scored_this_blind(self):
        trousers = {**self.parts, "kne": [np.array(C.hex_to_rgb("#2A1C2A"))]}
        m = S.measure(self.save("good.png", dancer(self.skirt)), self.pose, self.rig_mask, trousers)
        self.assertEqual(m["errors"]["r_kne"], S.LOST)

    def test_a_known_bad_candidate_ranks_last(self):
        for k, a in {"good": dancer(self.skirt), "no_hands": dancer(self.skirt, hands=False), "no_legs": dancer(self.skirt, legs=False)}.items():
            self.save(f"p.a/{k}.png", a)
        self.save("rig/p.a.regions.png", dancer((90, 30, 60)))
        scores, selection, _ = S.score_run({"p.a": self.pose}, self.root, self.root / "rig", self.parts)
        order = sorted(scores["p.a"], key=lambda k: scores["p.a"][k]["score"])
        self.assertEqual(order[0], "good")
        self.assertEqual(order[-1], "no_legs")
        self.assertEqual(selection["p.a"]["k"], "good")

    def test_a_wider_tolerance_forgives_a_swinging_skirt(self):
        a = dancer(self.skirt)
        a[300:370, 30:170] = (*self.skirt, 255)
        path = self.save("swing.png", a)
        tight = S.measure(path, self.pose, self.rig_mask, {**self.parts, "tolerance": 4})
        loose = S.measure(path, self.pose, self.rig_mask, S.part_colours(definition(silhouetteTolerance=40), self.style))
        self.assertGreater(tight["extra"], 0)
        self.assertEqual(loose["extra"], 0)


class Loud(unittest.TestCase):
    """LESSONS_LEARNED A2: all 256 candidates once scored 0.0, and the run looked fine."""

    def cand(self, score, knee=3.0):
        return {"score": score, "errors": {"r_kne": knee, "r_elb": 1.0}, "lost": []}

    def test_good_scores_pass(self):
        S.check_scores({"a": {"0": self.cand(4.0), "1": self.cand(9.0)}, "b": {"0": self.cand(5.0)}}, ["a", "b"])

    def test_no_scores_abort(self):
        with self.assertRaisesRegex(S.ScoreFailure, "no candidates scored"):
            S.check_scores({}, ["a"])

    def test_missing_poses_abort_unless_partial(self):
        scores = {"a": {"0": self.cand(4.0), "1": self.cand(9.0)}}
        with self.assertRaisesRegex(S.ScoreFailure, "1 poses have no candidates: b"):
            S.check_scores(scores, ["a", "b"])
        S.check_scores(scores, ["a", "b"], partial=True)

    def test_uniform_scores_abort(self):
        scores = {p: {"0": self.cand(0.0), "1": self.cand(0.0)} for p in "ab"}
        with self.assertRaisesRegex(S.ScoreFailure, "every candidate scored 0.0"):
            S.check_scores(scores, ["a", "b"])

    def test_a_colour_found_nowhere_aborts(self):
        scores = {"a": {"0": self.cand(1000.0, knee=S.LOST), "1": self.cand(1100.0, knee=S.LOST)}}
        with self.assertRaisesRegex(S.ScoreFailure, "kne: its colour appears in no candidate"):
            S.check_scores(scores, ["a"])

    def test_a_not_a_number_aborts(self):
        with self.assertRaisesRegex(S.ScoreFailure, "not a number"):
            S.check_scores({"a": {"0": self.cand(float("nan"))}}, ["a"])


if __name__ == "__main__":
    unittest.main()
