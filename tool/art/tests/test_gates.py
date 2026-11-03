"""Non-recolourable colours must fail every reserved-ramp gate (spec: outfit recolour gates)."""
import copy
import sys
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import colour as C  # noqa: E402
import definitions as D  # noqa: E402

PLUM_HAT = "#A0308F"


class Gates(unittest.TestCase):
    def setUp(self):
        self.c = copy.deepcopy(D.load_character("gatekeeper"))
        self.style = D.load_style("party-pixel")
        self.rr = self.style["reservedRamps"]
        self.hat = next(g for g in self.c["garments"] if g["id"] == "hat")

    def test_plum_hits_plum_gate(self):
        self.assertIn("plum", C.gates_hit(C.hex_to_rgb(PLUM_HAT), self.rr))

    def test_red_passes(self):
        self.assertEqual(C.gates_hit(C.hex_to_rgb("#B3202A"), self.rr), [])

    def test_in_gate_hat_refused_naming_gate_and_colour(self):
        self.hat["colour"] = PLUM_HAT
        with self.assertRaises(C.GateViolation) as e:
            C.build_ramps(self.c, self.style)
        msg = str(e.exception)
        self.assertIn("hat", msg)
        self.assertIn(PLUM_HAT, msg)
        self.assertIn("plum", msg)

    def test_declared_nudge_is_applied_and_leaves_gates(self):
        self.hat.update(colour=PLUM_HAT, nudge=True)
        ramps = C.build_ramps(self.c, self.style)
        for shade in ramps["hat"]["shades"]:
            self.assertEqual(C.gates_hit(C.hex_to_rgb(shade), self.rr), [], shade)

    def test_recolourable_region_may_stay_in_gate(self):
        self.hat.update(colour=PLUM_HAT, recolourable=True)
        self.assertIn(PLUM_HAT, C.build_ramps(self.c, self.style)["hat"]["shades"])

    def test_derived_shades_leave_gates_without_being_refused(self):
        ramps = C.build_ramps(self.c, self.style)
        for part, v in ramps.items():
            for shade in v["shades"]:
                self.assertEqual(C.gates_hit(C.hex_to_rgb(shade), self.rr), [], (part, shade))

    def test_ramps_disjoint_and_avoid_outline(self):
        ramps = C.build_ramps(self.c, self.style)
        all_shades = [s for v in ramps.values() for s in v["shades"]]
        self.assertEqual(len(all_shades), len(set(all_shades)))
        self.assertNotIn(self.style["outline"].upper(), all_shades)


class Maths(unittest.TestCase):
    def test_oklab_round_trip(self):
        for rgb in ((181, 101, 58), (0, 0, 0), (255, 255, 255), (41, 115, 122)):
            self.assertEqual(tuple(C.oklab_to_rgb(C.oklab(rgb))), rgb)

    def test_ramp_dark_to_light_keeps_base(self):
        ramp = C.make_ramp("#B5653A", 4)
        self.assertIn(C.hex_to_rgb("#B5653A"), ramp)
        lum = [C.oklab(c)[0] for c in ramp]
        self.assertEqual(lum, sorted(lum))


if __name__ == "__main__":
    unittest.main()
