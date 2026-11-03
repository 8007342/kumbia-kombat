import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import definitions as D  # noqa: E402
import planner as P  # noqa: E402
import selection as Sel  # noqa: E402


def pose(pid, **regions):
    return {"id": pid, "params": {"yaw": 0}, "support": "left", "regionPixels": regions}


FULL = dict(skin=100, hat=50, accessory=5, hair=9, cloth=500, trousers=300, shoes=40)
NO_HAT = dict(skin=100, hair=9, cloth=500, trousers=300, shoes=40)
RIG = {"poses": [pose(f"a.{i}", **FULL) for i in range(10)] + [pose(f"b.{i}", **NO_HAT) for i in range(6)]}


class Base(unittest.TestCase):
    def setUp(self):
        self.old = D.load_character("gatekeeper")
        self.new = copy.deepcopy(self.old)
        self.style = D.load_style("party-pixel")
        self.backend = D.load_backend("lightning-4step")

    def plan(self, **kw):
        return P.plan(self.old, self.new, RIG, self.style, self.backend, **kw)

    def hat(self):
        return next(g for g in self.new["garments"] if g["id"] == "hat")


class Colour(Base):
    def test_only_frames_showing_the_garment_recolour_with_no_gpu(self):
        self.hat().update(colour="#B3202A", text="red panama hat with teal band")
        r = self.plan()
        self.assertEqual(r["counts"]["recolour"], 10)
        self.assertEqual(r["counts"]["none"], 6)
        self.assertFalse(r["gpu"])
        self.assertEqual(r["estimatedImages"], 0)
        self.assertEqual(r["references"], "recolour")

    def test_large_value_change_warns_and_mode_can_be_forced(self):
        self.hat().update(colour="#101010")
        self.assertTrue(any("recolour may look flat" in w for w in self.plan()["warnings"]))
        r = self.plan(force="masked")
        self.assertEqual(r["counts"]["masked"], 10)
        self.assertEqual(r["counts"]["none"], 6)
        self.assertEqual(r["estimatedImages"], 40)


class AlsoIn(Base):
    def test_panel_colour_reaches_frames_where_its_own_region_is_hidden(self):
        next(g for g in self.new["garments"] if g["id"] == "band").update(colour="#7A4A1F")
        r = self.plan()
        self.assertEqual(r["counts"]["recolour"], 16)  # cloth shows everywhere


class Geometry(Base):
    def test_added_garment_without_new_rig_is_unresolved_for_all_frames(self):
        self.new["garments"].append({"id": "cape", "shape": "waist-apron", "region": "apron", "colour": "#112233"})
        r = self.plan()
        self.assertEqual(r["counts"]["masked"], 16)
        self.assertFalse(r["visibilityResolved"])
        self.assertTrue(r["gpu"])

    def test_added_garment_with_new_rig_skips_invisible_frames(self):
        self.new["garments"].append({"id": "cape", "shape": "waist-apron", "region": "apron", "colour": "#112233"})
        new_rig = {"poses": [pose(f"a.{i}", apron=30, **FULL) for i in range(10)] + [pose(f"b.{i}", **NO_HAT) for i in range(6)]}
        r = self.plan(new_rig=new_rig)
        self.assertEqual(r["counts"]["masked"], 10)
        self.assertEqual(r["counts"]["none"], 6)
        self.assertTrue(r["visibilityResolved"])

    def test_derived_reference_is_rebuilt_first(self):
        self.new["references"]["mode"] = "derive"
        self.old["references"]["mode"] = "derive"
        self.new["garments"].append({"id": "cape", "shape": "waist-apron", "region": "apron", "colour": "#112233"})
        self.assertEqual(self.plan()["references"], "rebuild-then-review")


class Whole(Base):
    def test_body_is_full_for_every_frame(self):
        self.new["body"]["overrides"] = {"head_r": 0.2}
        self.assertEqual(self.plan()["counts"]["full"], 16)

    def test_style_lists_users(self):
        s2 = copy.deepcopy(self.style)
        s2["prompt"] = "painted"
        r = P.plan_style_edit(self.style, s2, [self.old])
        self.assertEqual(r["affectedCharacters"], ["gatekeeper"])
        self.assertEqual(r["mode"], "full")

    def test_pose_override_only_touches_that_pose(self):
        self.new["motion"]["overrides"] = {"a.1": {"intent": "x"}}
        r = self.plan()
        self.assertEqual(r["counts"]["full"], 1)
        self.assertEqual(r["frames"]["a.1"]["mode"], "full")

    def test_negatives_warning_on_ineffective_backend(self):
        self.new["traits"] = "tall man"
        self.assertTrue(any("negative" in w for w in self.plan()["warnings"]))

    def test_no_edit_no_work(self):
        r = self.plan()
        self.assertEqual(r["counts"]["none"], 16)
        self.assertEqual(r["changes"], [])
        self.assertFalse(r["gpu"])


class KeysAndReview(Base):
    def keys(self, c):
        return {p["id"]: P.frame_key(c, self.style, self.backend, p) for p in RIG["poses"]}

    def test_key_ignores_hidden_garments(self):
        before = self.keys(self.old)
        self.hat().update(colour="#B3202A")
        after = self.keys(self.new)
        self.assertEqual({k for k in before if before[k] != after[k]}, {f"a.{i}" for i in range(10)})

    def test_backend_is_part_of_identity(self):
        other = {**self.backend, "id": "other"}
        p = RIG["poses"][0]
        self.assertNotEqual(P.frame_key(self.old, self.style, self.backend, p), P.frame_key(self.old, self.style, other, p))

    def test_edit_returns_exactly_affected_frames_to_review(self):
        before = self.keys(self.old)
        sel = {k: {"k": 0, "key": v, "accepted": True} for k, v in before.items()}
        self.hat().update(colour="#B3202A")
        new_sel, returned = Sel.reconcile(sel, self.keys(self.new))
        self.assertEqual(returned, sorted(f"a.{i}" for i in range(10)))
        self.assertTrue(all(new_sel[f"b.{i}"]["accepted"] for i in range(6)))
        self.assertFalse(any(new_sel[f"a.{i}"]["accepted"] for i in range(10)))
        report = self.plan(selection=sel)
        self.assertEqual(report["returnToReview"], returned)

    def test_revert_restores_key(self):
        before = self.keys(self.old)
        self.hat().update(colour="#B3202A")
        self.hat().update(colour=next(g for g in self.old["garments"] if g["id"] == "hat")["colour"])
        self.assertEqual(self.keys(self.new), before)

    def test_promotion_refused_names_frames(self):
        msg = Sel.promotion_refusal({"a": {"accepted": True}, "b": {"accepted": False}}, ["a", "b", "c"])
        self.assertIn("b", msg)
        self.assertIn("c", msg)
        self.assertIsNone(Sel.promotion_refusal({"a": {"accepted": True}}, ["a"]))


class DryRun(unittest.TestCase):
    def test_cli_changes_no_files(self):
        def status():
            return subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout
        before = status()
        out = subprocess.run([sys.executable, str(ART / "pipeline" / "planner.py"), "plan", "gatekeeper"],
                             cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertTrue(json.loads(out.stdout)["dryRun"])
        self.assertEqual(status(), before)


if __name__ == "__main__":
    unittest.main()
