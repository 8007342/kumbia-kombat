import json
import sys
import tempfile
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import stages as S  # noqa: E402


class Store(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.store = S.Store(Path(self.tmp.name))
        self.calls = 0

    def tearDown(self):
        self.tmp.cleanup()

    def work(self, d):
        self.calls += 1
        (d / "out.txt").write_text("x")

    def test_unchanged_inputs_do_no_work(self):
        a = self.store.run("rig", {"a": 1, "b": 2}, self.work)
        b = self.store.run("rig", {"b": 2, "a": 1}, self.work)
        self.assertEqual(a, b)
        self.assertEqual(self.calls, 1)
        self.assertEqual(len(self.store.reused), 1)

    def test_changed_inputs_run_again_and_keep_old_output(self):
        a = self.store.run("rig", {"a": 1}, self.work)
        b = self.store.run("rig", {"a": 2}, self.work)
        self.assertNotEqual(a, b)
        self.assertTrue((a / "out.txt").exists())
        self.assertEqual(self.calls, 2)

    def test_interrupted_run_resumes_only_the_remainder(self):
        poses = [f"p{i}" for i in range(6)]
        done = []

        def job(pose, fail_at=None):
            def w(d):
                if pose == fail_at:
                    raise KeyboardInterrupt
                done.append(pose)
                (d / "f.png").write_text(pose)
            return w

        with self.assertRaises(KeyboardInterrupt):
            for p in poses:
                self.store.run("generate", {"pose": p}, job(p, fail_at="p3"))
        self.assertEqual(done, ["p0", "p1", "p2"])
        self.assertFalse(self.store.has("generate", S.key_of({"pose": "p3"})))
        leftovers = [x for x in (Path(self.tmp.name) / "generate").iterdir() if x.name.startswith(".")]
        self.assertEqual(leftovers, [])
        done.clear()
        for p in poses:
            self.store.run("generate", {"pose": p}, job(p))
        self.assertEqual(done, ["p3", "p4", "p5"])

    def test_default_root_honours_env(self):
        import os
        os.environ["KUMBIA_ART_CACHE"] = "/x/y"
        try:
            self.assertEqual(S.default_root(), Path("/x/y"))
        finally:
            del os.environ["KUMBIA_ART_CACHE"]


if __name__ == "__main__":
    unittest.main()
