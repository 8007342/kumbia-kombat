"""Run: ~/.cache/kumbia-art/bin/python -m unittest discover -s tool/art/tests"""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pipeline"))
import suggest  # noqa: E402

REGIONS = {"#FFFF00": "hat", "#0000FF": "cloth"}
CREAM, TEAL, ORANGE, PURPLE = (242, 217, 173), (41, 115, 122), (209, 95, 31), (99, 26, 87)
TARGET = {"hat": np.array(CREAM, float), "cloth": np.array(PURPLE, float)}


def mask():
    m = np.zeros((60, 60, 3), np.uint8)
    m[:30] = (255, 255, 0)
    m[30:] = (0, 0, 255)
    return m


def image(hat, cloth):
    im = np.zeros((60, 60, 3), float)
    im[:30] = hat
    im[30:] = cloth
    return im


class Scoring(unittest.TestCase):
    def setUp(self):
        self.masks = suggest.region_masks(mask(), REGIONS)

    def test_region_map_finds_regions_keyed_by_colour(self):
        self.assertEqual(set(self.masks), {"hat", "cloth"})
        self.assertTrue(self.masks["hat"].any())

    def test_wrong_hat_ranks_below_on_model(self):
        _, good = suggest.score_candidate(image(CREAM, PURPLE), self.masks, TARGET)
        _, bad = suggest.score_candidate(image(ORANGE, PURPLE), self.masks, TARGET)
        self.assertLess(good, 1.0)
        self.assertGreater(bad, good + 5)

    def test_either_region_off_model_scores_above_zero(self):
        _, hat_off = suggest.score_candidate(image(TEAL, PURPLE), self.masks, TARGET)
        _, cloth_off = suggest.score_candidate(image(CREAM, TEAL), self.masks, TARGET)
        self.assertGreater(hat_off, 0)
        self.assertGreater(cloth_off, 0)

    def test_nothing_measurable_is_none(self):
        empty = suggest.region_masks(np.zeros((60, 60, 3), np.uint8), REGIONS)
        self.assertIsNone(suggest.score_candidate(image(CREAM, PURPLE), empty, TARGET)[1])


class FailsClosed(unittest.TestCase):
    def test_uniform_scores_abort(self):
        with self.assertRaises(SystemExit):
            suggest.require_informative({"a": {"0": {"identityScore": 0.0}, "1": {"identityScore": 0.0}}})

    def test_missing_scores_abort(self):
        with self.assertRaises(SystemExit):
            suggest.require_informative({"a": {"0": {"identityScore": None}, "1": {"identityScore": 3.0}}})

    def test_real_scores_pass(self):
        suggest.require_informative({"a": {"0": {"identityScore": 3.0}, "1": {"identityScore": 9.0}}})


if __name__ == "__main__":
    unittest.main()
