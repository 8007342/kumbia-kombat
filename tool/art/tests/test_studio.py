#!/usr/bin/env python3
"""Studio workflows: one UI source each, a conversion that matches the frontend, a safe sync."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
STUDIO = ROOT / "tool" / "art" / "studio"
sys.path.insert(0, str(STUDIO))
import stage_parts as P  # noqa: E402
import sync_studio as Y  # noqa: E402
import ui_to_api as U  # noqa: E402

import numpy as np  # noqa: E402

SCHEMAS = U.load_schemas()
RECORDED = STUDIO / "recorded"
SOURCES = {p.stem: p for p in U.sources()}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def tiny_ui() -> dict:
    return {"nodes": [
        {"id": 1, "type": "LoadImage", "title": "$photo", "pos": [0.4, 0], "mode": 0, "widgets_values": ["a.png", "image"],
         "inputs": [], "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [1]}]},
        {"id": 2, "type": "SaveImage", "pos": [10, 0], "mode": 0, "widgets_values": ["x"],
         "inputs": [{"name": "images", "type": "IMAGE", "link": 1}], "outputs": []}],
        "links": [[1, 1, 0, 2, 0, "IMAGE"]], "groups": [], "extra": {}}


class Conversion(unittest.TestCase):
    def test_workflows_are_committed(self):
        self.assertLessEqual({"frame-multipass", "model-sheet", "parts-from-frame"}, set(SOURCES))

    def test_matches_a_recording_of_the_frontend(self):
        for name, path in {**SOURCES, "features": RECORDED / "features.ui.json"}.items():
            with self.subTest(name):
                self.assertEqual(U.convert(load(path), SCHEMAS), load(RECORDED / f"{name}.frontend.json"))

    def test_is_deterministic(self):
        for path in SOURCES.values():
            ui = load(path)
            self.assertEqual(U.dumps(U.bind(U.convert(ui, SCHEMAS))), U.dumps(U.bind(U.convert(json.loads(json.dumps(ui)), SCHEMAS))))

    def test_committed_api_files_match_their_source(self):
        for path in SOURCES.values():
            for target, text in U.generated_files(path, SCHEMAS).items():
                with self.subTest(target.name):
                    self.assertEqual(target.read_text(), text)

    def test_every_class_is_in_the_snapshot(self):
        for name, path in SOURCES.items():
            for node in load(path)["nodes"]:
                if node["type"] not in U.VIRTUAL:
                    self.assertIn(node["type"], SCHEMAS, f"{name} node {node['id']}")

    def test_reroute_bypass_mute_and_notes(self):
        api = U.convert(load(RECORDED / "features.ui.json"), SCHEMAS)
        self.assertNotIn("2", api)  # reroute
        self.assertNotIn("3", api)  # bypassed
        self.assertNotIn("5", api)  # muted
        self.assertEqual(api["4"]["inputs"]["image"], ["1", 0])  # through the reroute and the bypass
        self.assertNotIn("mask", api["7"]["inputs"])  # its parent is muted
        self.assertEqual(api["7"]["inputs"]["x"], ["6", 0])  # a widget fed by a link

    def test_widget_values_skip_the_frontend_only_slots(self):
        api = U.convert(tiny_ui(), SCHEMAS)
        self.assertEqual(api["1"]["inputs"], {"image": "a.png"})

    def test_too_many_widget_values_are_refused(self):
        ui = tiny_ui()
        ui["nodes"][1]["widgets_values"] = ["x", "y"]
        with self.assertRaisesRegex(U.ConversionError, "schema snapshot may be stale"):
            U.convert(ui, SCHEMAS)

    def test_subgraphs_are_refused_by_name(self):
        ui = tiny_ui()
        ui["definitions"] = {"subgraphs": [{"id": "x"}]}
        with self.assertRaisesRegex(U.ConversionError, "subgraphs"):
            U.convert(ui, SCHEMAS)

    def test_unknown_class_names_the_fix(self):
        ui = tiny_ui()
        ui["nodes"][1]["type"] = "NotANode"
        with self.assertRaisesRegex(U.ConversionError, "refresh-schemas"):
            U.convert(ui, SCHEMAS)

    def test_bind_touches_only_titled_load_images(self):
        api = U.bind(U.convert(tiny_ui(), SCHEMAS))
        self.assertEqual(api["1"]["inputs"]["image"], "$photo")
        self.assertEqual(api["2"]["inputs"]["filename_prefix"], "x")


class Graphs(unittest.TestCase):
    def api(self, name: str) -> dict:
        return load(SOURCES[name].with_name(f"{name}.api.json"))

    def test_no_hidden_composition_weight(self):
        for name in SOURCES:
            for node in self.api(name).values():
                if node["class_type"] == "IPAdapterAdvanced":
                    self.assertNotEqual(node["inputs"]["weight_type"], "style and composition", name)

    def test_every_pass_saves_its_output(self):
        titles = {n["_meta"]["title"] for n in self.api("frame-multipass").values() if n["class_type"] == "SaveImage"}
        for word in ("base", "shirt", "embroidery", "hat", "head", "matte"):
            self.assertTrue(any(word in t for t in titles), word)

    def test_every_sampler_takes_the_run_seed(self):
        for node in self.api("frame-multipass").values():
            if node["class_type"] == "KSampler":
                self.assertEqual(node["_meta"]["title"], "$seed")

    def test_partial_denoise_is_real(self):
        for node in self.api("frame-multipass").values():
            if node["class_type"] == "KSampler" and node["inputs"]["denoise"] < 1:
                self.assertGreater(int(node["inputs"]["steps"] / node["inputs"]["denoise"]), node["inputs"]["steps"])

    def test_profiles_change_only_control_strengths(self):
        base, peak = self.api("frame-multipass"), load(SOURCES["frame-multipass"].with_name("frame-multipass.peak.api.json"))
        changed = {k for k in base if base[k] != peak[k]}
        self.assertEqual(changed, {"20", "21", "22"})

    def test_crops_use_the_staged_window_sizes(self):
        api = self.api("frame-multipass")
        self.assertEqual(api["301"]["inputs"]["width"], P.WINDOW)
        self.assertEqual(api["503"]["inputs"]["width"], P.TORSO_WINDOW)

    def test_sources_keep_their_sample_inputs(self):
        for name, path in SOURCES.items():
            for node in load(path)["nodes"]:
                if node["type"] == "LoadImage":
                    self.assertTrue((Y.SAMPLES / node["widgets_values"][0]).exists(), f"{name}: {node['widgets_values'][0]}")


class Canonical(unittest.TestCase):
    def test_a_resave_with_no_edit_is_not_drift(self):
        ui = tiny_ui()
        saved = json.loads(json.dumps(ui))
        saved["nodes"].reverse()
        saved["revision"] = 7
        saved["extra"]["ds"] = {"scale": 2}
        saved["nodes"][1]["pos"] = [0.0, 0.0]
        saved["nodes"][1]["properties"] = {"Node name for S&R": "LoadImage", "ver": "1"}
        saved["nodes"][1]["inputs"] = [{"name": "image", "type": "COMBO", "widget": {"name": "image"}, "link": None,
                                        "localized_name": "image"}]
        self.assertEqual(Y.digest(ui), Y.digest(saved))

    def test_real_edits_are_drift(self):
        for edit in (lambda u: u["nodes"][1]["widgets_values"].__setitem__(0, "y"),
                     lambda u: u["nodes"][1]["pos"].__setitem__(0, 500),
                     lambda u: u["nodes"][1].__setitem__("mode", 4)):
            ui = tiny_ui()
            edit(ui)
            self.assertNotEqual(Y.digest(tiny_ui()), Y.digest(ui))

    def test_classify(self):
        repo, edited = tiny_ui(), tiny_ui()
        edited["nodes"][1]["widgets_values"] = ["owner"]
        base = Y.digest(repo)
        self.assertEqual(Y.classify(repo, None, base), "missing")
        self.assertEqual(Y.classify(repo, repo, base), "in-sync")
        self.assertEqual(Y.classify(repo, edited, base), "owner-edit")
        self.assertEqual(Y.classify(edited, repo, base), "repo-ahead")
        third = tiny_ui()
        third["nodes"][1]["widgets_values"] = ["third"]
        self.assertEqual(Y.classify(third, edited, base), "conflict")
        self.assertEqual(Y.classify(repo, edited, None), "conflict")  # no record: don't assume it's disposable


class FakeStudio:
    def __init__(self, files=None):
        self.files = dict(files or {})

    def read(self, name):
        return self.files.get(name)

    def write(self, name, ui):
        self.files[name] = ui

    def upload_input(self, path, as_name=None):
        pass


class Sync(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmp.name)
        self.saved = Y.STATE, Y.SAMPLES, Y.repo_workflows
        Y.STATE = self.folder / "sync_state.json"
        Y.SAMPLES = self.folder / "samples"
        self.path = self.folder / "w.json"
        self.path.write_text(json.dumps(tiny_ui()))
        Y.repo_workflows = lambda: {"w": self.path}

    def tearDown(self):
        Y.STATE, Y.SAMPLES, Y.repo_workflows = self.saved
        self.tmp.cleanup()

    def args(self, **kw):
        return type("A", (), {"names": [], "force": False, **kw})()

    def test_push_restores_a_wiped_studio(self):
        studio = FakeStudio()
        self.assertEqual(Y.cmd_push(studio, self.args()), 0)
        self.assertEqual(Y.digest(studio.files["w"]), Y.digest(tiny_ui()))

    def test_push_refuses_over_owner_edits_until_forced(self):
        studio = FakeStudio()
        Y.cmd_push(studio, self.args())
        studio.files["w"] = json.loads(json.dumps(tiny_ui()))
        studio.files["w"]["nodes"][1]["widgets_values"] = ["owner"]
        self.assertEqual(Y.cmd_push(studio, self.args()), 1)
        self.assertEqual(studio.files["w"]["nodes"][1]["widgets_values"], ["owner"])
        self.assertEqual(Y.cmd_push(studio, self.args(force=True)), 0)
        self.assertEqual(studio.files["w"]["nodes"][1]["widgets_values"], ["x"])

    def test_pull_conflict_leaves_the_source_alone(self):
        studio = FakeStudio()
        Y.cmd_push(studio, self.args())
        changed = tiny_ui()
        changed["nodes"][1]["widgets_values"] = ["repo"]
        self.path.write_text(json.dumps(changed))
        studio.files["w"] = tiny_ui()
        studio.files["w"]["nodes"][1]["widgets_values"] = ["owner"]
        Y.cmd_pull(studio, self.args())
        self.assertEqual(load(self.path)["nodes"][1]["widgets_values"], ["repo"])
        self.assertEqual(load(self.folder / "w.studio.json")["nodes"][1]["widgets_values"], ["owner"])

    def test_pulled_side_files_are_not_sources(self):
        other = self.folder / "other"
        other.mkdir()
        for name in ("a.json", "a.api.json", "a.peak.api.json", "a.studio.json", "sync_state.json"):
            (other / name).write_text("{}")
        self.assertEqual([p.name for p in U.sources(other)], ["a.json"])


class Parts(unittest.TestCase):
    def rig(self):
        rgba = np.zeros((960, 768, 4), "uint8")

        def fill(box, region):
            x0, y0, x1, y1 = box
            rgba[y0:y1, x0:x1] = (*P.REGION[region], 255)
        fill((340, 250, 440, 350), "skin")      # head
        fill((370, 310, 410, 318), "hair")      # mustache, inside the head
        fill((300, 180, 480, 250), "hat")
        fill((330, 240, 450, 248), "accessory")  # band, on the hat
        fill((300, 380, 480, 600), "cloth")
        fill((340, 400, 350, 560), "accessory")  # stripes
        fill((430, 400, 440, 560), "accessory")
        fill((480, 380, 560, 420), "skin")      # an arm, away from the head
        fill((310, 600, 470, 880), "trousers")
        fill((310, 880, 470, 900), "shoes")
        return rgba

    def test_parts_never_overlap_and_cover_the_rig(self):
        rgba = self.rig()
        parts = P.part_masks(rgba, (390.0, 300.0))
        total = sum(m.astype(int) for m in parts.values())
        self.assertEqual(int(total.max()), 1)
        self.assertTrue(((total > 0) == (rgba[..., 3] > 0)).all())

    def test_band_goes_with_the_hat_and_stripes_with_the_shirt(self):
        parts = P.part_masks(self.rig(), (390.0, 300.0))
        self.assertTrue(parts["hat"][244, 390])
        self.assertTrue(parts["shirt"][480, 345])

    def test_an_arm_outside_the_disc_isnt_head(self):
        parts = P.part_masks(self.rig(), (390.0, 300.0))
        self.assertTrue(parts["arms"][400, 520])
        self.assertFalse(parts["head"][400, 520])

    def test_window_stays_inside_the_canvas_and_above_zero(self):
        head = np.zeros((960, 768), bool)
        head[0:20, 0:20] = True
        self.assertEqual(P.head_window(head, (768, 960)), (1, 1))
        head[:] = False
        head[940:960, 748:768] = True
        self.assertEqual(P.head_window(head, (768, 960)), (768 - P.WINDOW, 960 - P.WINDOW))

    def test_mustache_axis_finds_the_mustache(self):
        rgba = self.rig()
        parts = P.part_masks(rgba, (390.0, 300.0))
        centre, axis, half = P.mustache_axis(rgba, parts["head"], parts["hat"])
        self.assertAlmostEqual(centre[1], 313.5, delta=1)
        self.assertGreater(abs(axis[0]), 0.99)
        self.assertAlmostEqual(half, 19.5, delta=1)

    def test_face_mask_excludes_the_hat(self):
        rgba = self.rig()
        parts = P.part_masks(rgba, (390.0, 300.0))
        face = P.face_mask(parts["head"], parts["hat"], (390.0, 300.0), (390.0, 360.0))
        self.assertFalse((face & parts["hat"]).any())
        self.assertTrue(face[360, 390])  # the neck, below the rig's chin

    def test_drawn_mustache_is_one_native_pixel_tall(self):
        from PIL import Image
        rgba = self.rig()
        parts = P.part_masks(rgba, (390.0, 300.0))
        out = np.array(P.draw_face(Image.new("RGB", (768, 960), "white"), parts, rgba))
        column = (out[:, 390] == P.INK).all(axis=-1)
        below_eyes = column[300:330]
        self.assertAlmostEqual(int(below_eyes.sum()), P.MUSTACHE_TALL, delta=1)


if __name__ == "__main__":
    unittest.main()
