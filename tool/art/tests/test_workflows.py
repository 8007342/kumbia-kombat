#!/usr/bin/env python3
"""Per-backend workflows: deterministic, committed as built, and truly partial."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

WF = Path(__file__).resolve().parents[1] / "workflows"
sys.path.insert(0, str(WF))
import build_workflows as B  # noqa: E402

MODELS = json.loads((WF / "models.json").read_text())
BACKENDS = [b for b in (json.loads(p.read_text()) for p in sorted(B.BACKENDS.glob("*.json"))) if b.get("route") != "qwen"]


def sampler(wf: dict) -> dict:
    return wf["32"]["inputs"]


class BackendWorkflows(unittest.TestCase):
    def test_committed_files_match_a_fresh_build(self):
        for b in BACKENDS:
            for stem, wf in B.backend_workflows(b, MODELS).items():
                path = WF / b["id"] / f"{stem}.api.json"
                self.assertEqual(path.read_text(), json.dumps(wf, indent=1) + "\n", str(path))

    def test_legacy_baseline_graphs_are_untouched(self):
        for name, prof in B.PROFILES.items():
            path = WF / f"character-frame-{name}.api.json"
            self.assertEqual(path.read_text(), json.dumps(B.build(prof, MODELS), indent=1) + "\n", name)

    def test_backend_settings_reach_the_graph(self):
        for b in BACKENDS:
            wf = B.backend_workflows(b, MODELS)["peak"]
            self.assertEqual(wf["1"]["inputs"]["ckpt_name"], b["checkpoint"])
            self.assertEqual(sampler(wf)["steps"], b["sampler"]["steps"])
            self.assertEqual(sampler(wf)["sampler_name"], b["sampler"]["name"])
            self.assertEqual(sampler(wf)["denoise"], b["denoise"])

    def test_every_backend_really_denoises_partially(self):
        for b in BACKENDS:
            steps = b["sampler"]["steps"]
            self.assertGreater(int(steps / b["denoise"]), steps, b["id"])
            self.assertLess(B.effective_denoise(steps, b["denoise"]), 1.0, b["id"])

    def test_lightning_runs_above_four_steps(self):
        b = next(x for x in BACKENDS if x["id"] == "lightning-4step")
        self.assertGreater(b["sampler"]["steps"], 4)

    def test_truncating_settings_are_refused(self):
        with self.assertRaises(SystemExit):
            B.check_partial_denoise("x", 4, 0.85)


if __name__ == "__main__":
    unittest.main()
