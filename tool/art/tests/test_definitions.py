"""Valid files pass; refusals name the bad field."""
import copy
import json
import sys
import unittest
from pathlib import Path

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART / "pipeline"))
import definitions as D  # noqa: E402


def base():
    return json.loads((ART / "characters" / "gatekeeper.json").read_text())


class Valid(unittest.TestCase):
    def test_committed_definitions_pass(self):
        for f in (ART / "characters").glob("*.json"):
            self.assertEqual(D.character_problems(json.loads(f.read_text())), [], f.name)
        for f in (ART / "styles").glob("*.json"):
            self.assertEqual(D.schema_problems("style", json.loads(f.read_text())), [], f.name)
        for f in (ART / "backends").glob("*.json"):
            self.assertEqual(D.schema_problems("backend", json.loads(f.read_text())), [], f.name)


class Refusals(unittest.TestCase):
    def refused(self, mutate, needle):
        c = base()
        mutate(c)
        joined = " | ".join(D.character_problems(c))
        self.assertIn(needle, joined)

    def test_unknown_shape(self):
        self.refused(lambda c: c["garments"][0].update(shape="cape"), "garments.0.shape: unknown garment shape 'cape'")

    def test_unknown_region(self):
        self.refused(lambda c: c["garments"][0].update(region="wings"), "garments.0.region: unknown region 'wings'")

    def test_unknown_motion(self):
        self.refused(lambda c: c["motion"].update(set="tango-9"), "motion.set: unknown motion set 'tango-9'")

    def test_unknown_style(self):
        self.refused(lambda c: c.update(style="nope"), "style: unknown style 'nope'")

    def test_unknown_preset(self):
        self.refused(lambda c: c["body"].update(preset="giant"), "body.preset: unknown body preset 'giant'")

    def test_missing_reference(self):
        self.refused(lambda c: c["references"]["sources"][0].update(image="assets/none.png"),
                     "references.sources.0.image: missing reference file")

    def test_bad_colour_names_field(self):
        self.refused(lambda c: c["garments"][0].update(colour="red"), "garments.0.colour")

    def test_unknown_key_names_it(self):
        self.refused(lambda c: c.update(wings=True), "wings")

    def test_active_requires_traits(self):
        self.refused(lambda c: c.pop("traits"), "traits: required for an active character")

    def test_variant_unknown_garment(self):
        self.refused(lambda c: c["variants"].update({"replay-1": {"colours": {"cape": "#112233"}}}),
                     "variants.replay-1.colours.cape: unknown garment or prop")

    def test_backend_schema_names_field(self):
        problems = D.schema_problems("backend", {"id": "x", "role": "painting"})
        self.assertTrue(any(p.startswith("role:") for p in problems), problems)

    def test_style_schema_names_field(self):
        problems = D.schema_problems("style", {"id": "x", "prompt": "p", "negative": "n", "frame": {"generationCanvas": {}}, "outline": "black", "ramp": {"shades": 4}})
        self.assertTrue(any(p.startswith("outline:") for p in problems), problems)


class BackendChoice(unittest.TestCase):
    def test_precedence(self):
        s = D.load_style("party-pixel")
        c = base()
        self.assertEqual(D.resolve_backend(c, s)["id"], s["backend"])
        c["backend"] = "lightning-4step"
        self.assertEqual(D.resolve_backend(c, s, None)["id"], "lightning-4step")
        with self.assertRaises(D.DefinitionError):
            D.resolve_backend(c, s, "not-a-backend")


if __name__ == "__main__":
    unittest.main()
