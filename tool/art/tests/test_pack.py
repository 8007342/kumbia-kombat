"""Pack: runtime aliases, facing, determinism, candidate never touches the live manifest."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import pack_atlas as P  # noqa: E402

RUN = "gatekeeper-v3-20261103a"


def challenger_ids():
    import re
    src = (ROOT / "lib/gameplay/challenger_choreography.dart").read_text()
    body = src.split("const challengerFrameIds = [", 1)[1].split("];", 1)[0]
    return re.findall(r"'([a-z_]+)'", body)


class Pack(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.out = Path(cls.tmp.name)
        cls.manifest_before = (ROOT / "assets/art/ensemble/manifest.json").read_bytes()
        for sub in ("a", "b"):
            r = subprocess.run([sys.executable, str(ART / "pipeline/pack_atlas.py"), "tool/art/families/gatekeeper-v3.json",
                                "--run", RUN, "--out-dir", str(cls.out / sub)], cwd=ROOT, capture_output=True, text=True)
            assert r.returncode == 0, r.stderr
        cls.cand = json.loads((cls.out / "a/gatekeeper-v3.candidate.json").read_text())

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_all_runtime_ids_resolve_inside_the_image(self):
        ids = challenger_ids()
        self.assertEqual(len(ids), 20)
        for i in ids:
            self.assertIn(i, self.cand["frames"])
            x, y, w, h = self.cand["frames"][i]["rect"]
            self.assertTrue(x >= 0 and y >= 0 and x + w <= self.cand["imageWidth"] and y + h <= self.cand["imageHeight"], i)
        self.assertIn(self.cand["referenceFrame"], self.cand["frames"])

    def test_aliases_copy_their_drawing(self):
        f = self.cand["frames"]
        self.assertEqual(f["left_hand"]["rect"], f["left_hand_peak"]["rect"])
        self.assertEqual(f["left_hand"]["aliasOf"], "left_hand_peak")

    def test_one_scale_per_sheet(self):
        self.assertEqual(len({f["pixelsPerUnit"] for f in self.cand["frames"].values()}), 1)

    def test_rebuild_is_byte_identical(self):
        for name in ("gatekeeper-v3.png", "gatekeeper-v3.candidate.json"):
            self.assertEqual((self.out / "a" / name).read_bytes(), (self.out / "b" / name).read_bytes(), name)

    def test_ramps_are_emitted(self):
        self.assertIn("hat", self.cand["ramps"])

    def test_live_manifest_untouched(self):
        self.assertEqual((ROOT / "assets/art/ensemble/manifest.json").read_bytes(), self.manifest_before)

    def test_facing_from_yaw(self):
        self.assertEqual(P.facing_of(0), "front")
        self.assertEqual(P.facing_of(-30), "front_3q")
        self.assertEqual(P.facing_of(90), "profile")
        self.assertEqual(P.facing_of(145), "rear_3q")
        self.assertEqual(P.facing_of(180), "rear")

    def test_dangling_alias_refused(self):
        with self.assertRaises(SystemExit):
            P.resolve_aliases({}, {"x": "a.b"}, lambda p: p.replace(".", "_"))


if __name__ == "__main__":
    unittest.main()
