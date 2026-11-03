"""Ramp stage, recolour and variants: the frame says which part each pixel is."""
import copy
import io
import subprocess
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import colour as C  # noqa: E402
import colourmatch as CM  # noqa: E402
import definitions as D  # noqa: E402
import masked as M  # noqa: E402
import ramps as R  # noqa: E402


def png(a):
    b = io.BytesIO()
    Image.fromarray(a, "RGBA").save(b, format="PNG", optimize=False)
    return b.getvalue()


class Fixture(unittest.TestCase):
    def setUp(self):
        self.c = copy.deepcopy(D.load_character("gatekeeper"))
        self.style = D.load_style("party-pixel")
        self.ramps = C.build_ramps(self.c, self.style)
        self.regions = D.rig_regions(self.c)
        # 12x12: top half hat region, bottom half trousers region, transparent corner.
        self.mask = np.zeros((12, 12, 4), np.uint8)
        self.mask[:6] = (*C.hex_to_rgb(self.regions["hat"]), 255)
        self.mask[6:] = (*C.hex_to_rgb(self.regions["trousers"]), 255)
        self.frame = np.zeros((12, 12, 4), np.uint8)
        # Both regions in the same shared-palette cream.
        self.frame[..., :3] = C.hex_to_rgb("#E5C996")
        self.frame[..., 3] = 255

    def ramped(self):
        return R.apply_ramps(self.frame, self.mask, self.ramps, self.regions, self.style["outline"], radius=0)


class RampStage(Fixture):
    def test_each_pixel_gets_a_shade_of_its_own_region(self):
        res, report = self.ramped()
        self.assertEqual(R.check_frame(res, self.ramps, self.style["outline"]), [])
        hat = set(self.ramps["hat"]["shades"])
        trousers = set(self.ramps["trousers"]["shades"])
        self.assertTrue(R.colours_in(res[:6]) <= hat)
        self.assertTrue(R.colours_in(res[6:]) <= trousers)
        self.assertEqual(report["offMask"], 0)
        self.assertFalse(report["flagged"])

    def test_off_mask_pixels_are_flagged_and_still_on_a_ramp(self):
        self.mask[0, 0] = 0
        res, report = R.apply_ramps(self.frame, self.mask, self.ramps, self.regions, self.style["outline"], radius=0)
        self.assertEqual(report["offMask"], 1)
        self.assertTrue(report["flagged"])
        self.assertEqual(R.check_frame(res, self.ramps, self.style["outline"]), [])

    def test_off_ramp_pixels_are_flagged(self):
        self.frame[0, 0, :3] = (0, 255, 0)
        _, report = self.ramped()
        self.assertGreaterEqual(report["offRamp"], 1)
        self.assertTrue(report["flagged"])

    def test_also_in_keeps_embroidery_on_the_shirt(self):
        teal = C.hex_to_rgb(self.ramps["band"]["shades"][2])
        mask = np.zeros((4, 4, 4), np.uint8)
        mask[...] = (*C.hex_to_rgb(self.regions["cloth"]), 255)
        frame = np.zeros((4, 4, 4), np.uint8)
        frame[..., :3], frame[..., 3] = teal, 255
        res, report = R.apply_ramps(frame, mask, self.ramps, self.regions, self.style["outline"], radius=0)
        self.assertTrue(R.colours_in(res) <= set(self.ramps["band"]["shades"]))
        self.assertFalse(report["flagged"])

    def test_alpha_is_binary(self):
        self.frame[3, 3, 3] = 40
        res, _ = self.ramped()
        self.assertEqual(set(np.unique(res[..., 3])), {0, 255})


class Recolour(Fixture):
    def test_only_the_edited_part_changes(self):
        base, _ = self.ramped()
        c2 = copy.deepcopy(self.c)
        next(g for g in c2["garments"] if g["id"] == "hat")["colour"] = "#B3202A"
        lut = R.lut_between(self.ramps, C.build_ramps(c2, self.style))
        res = R.apply_lut(base, lut)
        self.assertTrue(np.array_equal(res[6:], base[6:]))
        self.assertFalse(np.array_equal(res[:6], base[:6]))
        self.assertTrue(R.colours_in(res[:6]) <= set(C.build_ramps(c2, self.style)["hat"]["shades"]))

    def test_no_gpu_tool_is_imported(self):
        out = subprocess.run([sys.executable, "-c",
                              "import sys; sys.path.insert(0, 'tool/art/pipeline'); import ramps; "
                              "print([m for m in sys.modules if 'studio' in m or 'torch' in m or 'mcp' in m])"],
                             cwd=D.ROOT, capture_output=True, text=True, check=True)
        self.assertEqual(out.stdout.strip(), "[]")


class Variants(Fixture):
    def test_lut_equals_recolour_byte_for_byte(self):
        base, _ = self.ramped()
        self.c["variants"]["replay-1"] = {"colours": {"hat": "#B3202A", "trousers": "#2B3A67"}}
        table = R.variant_lut(self.c, self.style, "replay-1")
        c2 = copy.deepcopy(self.c)
        for g in c2["garments"]:
            if g["id"] == "hat":
                g["colour"] = "#B3202A"
            if g["id"] == "trousers":
                g["colour"] = "#2B3A67"
        edited = R.lut_between(self.ramps, C.build_ramps(c2, self.style))
        self.assertEqual(png(R.apply_lut(base, table)), png(R.apply_lut(base, edited)))

    def test_shape_variant_is_refused_as_a_table(self):
        self.c["variants"]["replay-2"] = {"garments": [{"id": "cape", "shape": "waist-apron", "region": "apron"}]}
        with self.assertRaises(ValueError):
            R.variant_lut(self.c, self.style, "replay-2")

    def test_in_gate_variant_is_refused(self):
        self.c["variants"]["bad"] = {"colours": {"hat": "#A0308F"}}
        with self.assertRaises(C.GateViolation):
            R.variant_lut(self.c, self.style, "bad")

    def test_manifest_block(self):
        self.c["variants"]["replay-1"] = {"colours": {"hat": "#B3202A"}}
        block = R.manifest_block(self.c, self.style)
        self.assertEqual(set(block["ramps"]["hat"]), {"region", "alsoIn", "shades"})
        self.assertIn("replay-1", block["variants"])


class Masked(unittest.TestCase):
    def setUp(self):
        self.regions = {"skin": "#FF0000", "hat": "#FFFF00"}
        self.old = np.zeros((40, 40, 4), np.uint8)
        self.old[20:, :] = (255, 0, 0, 255)
        self.new = self.old.copy()
        self.new[5:10, 5:10] = (255, 255, 0, 255)

    def test_mask_covers_change_plus_dilation_only(self):
        m = M.changed_mask(self.old, self.new, ["hat"], self.regions, dilate=3)
        self.assertTrue(m[7, 7])
        self.assertTrue(m[2, 7])     # within 3 px
        self.assertFalse(m[1, 7])    # beyond it
        self.assertFalse(m[35, 35])  # untouched skin

    def test_job_args_keep_seed_and_controls(self):
        base = {"workflow": "w.json", "tier": "I1", "count": 4, "inputs": {"pose": "p.png"},
                "init_image": "proxy.png", "overrides": {"seed": 7, "prompt": "x"}}
        args = M.job_args(base, "/work/tmp/imagegen/m.png", "/work/tmp/imagegen/prev.png")
        self.assertEqual(args["workflow"], M.MASKED_WORKFLOW)
        self.assertEqual(args["mask"], "/work/tmp/imagegen/m.png")
        self.assertEqual(args["init_image"], "/work/tmp/imagegen/prev.png")
        self.assertEqual(args["overrides"]["seed"], 7)
        self.assertEqual(args["inputs"], base["inputs"])
        self.assertEqual(base["init_image"], "proxy.png")

    def test_composite_keeps_outside_pixels_byte_identical(self):
        prev = np.random.default_rng(1).integers(0, 255, (40, 40, 3), np.uint8)
        gen = np.random.default_rng(2).integers(0, 255, (40, 40, 3), np.uint8)
        m = M.changed_mask(self.old, self.new, ["hat"], self.regions, dilate=3)
        out = M.composite(prev, gen, m)
        self.assertTrue(np.array_equal(out[~m], prev[~m]))
        self.assertTrue(np.array_equal(out[m], gen[m]))


class ColourMatch(unittest.TestCase):
    def test_median_moves_to_target_and_others_stay(self):
        rgb = np.zeros((40, 40, 3), np.uint8)
        rgb[:20] = (209, 95, 31)   # orange hat that should be cream
        rgb[20:] = (99, 26, 87)
        hat = np.zeros((40, 40), bool)
        hat[:20] = True
        res, report = CM.match_regions(rgb, {"hat": hat}, {"hat": "#F2D9AD"})
        self.assertLess(report["hat"]["after"], 2)
        self.assertGreater(report["hat"]["before"], 20)
        self.assertTrue(np.array_equal(res[20:], rgb[20:]))

    def test_small_regions_are_left_alone(self):
        rgb = np.full((10, 10, 3), 90, np.uint8)
        m = np.zeros((10, 10), bool)
        m[0, 0] = True
        res, report = CM.match_regions(rgb, {"hat": m}, {"hat": "#F2D9AD"})
        self.assertEqual(report, {})
        self.assertTrue(np.array_equal(res, rgb))

    def test_shading_structure_survives(self):
        rgb = np.zeros((40, 40, 3), np.uint8)
        rgb[:, :20] = (180, 80, 30)
        rgb[:, 20:] = (120, 50, 20)
        m = np.ones((40, 40), bool)
        res, _ = CM.match_regions(rgb, {"hat": m}, {"hat": "#F2D9AD"})
        self.assertFalse(np.array_equal(res[:, 0], res[:, 39]))


if __name__ == "__main__":
    unittest.main()
