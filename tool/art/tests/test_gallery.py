"""Gallery builder: discovery, partial sets stay partial, anchors and game scale match the game."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ART = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ART / "gallery"))
import build_gallery as B  # noqa: E402

MOTION = {
    "id": "tiny",
    "referencePose": "groove.a",
    "clips": [
        {"id": "groove", "drawings": 2, "view": "front", "loop": True, "durationBeats": 2.0, "events": []},
        {"id": "hit", "drawings": 2, "view": "front", "loop": False, "durationBeats": 1.0,
         "events": [{"beat": 0.5, "type": "accent", "drawing": "peak"}]},
    ],
    "runtimeAliases": {"occupied": "groove.a", "ready": "hit.prep"},
}
POSES = ["groove.a", "groove.b", "hit.prep", "hit.peak"]
PIXEL_SCALE = 4


def png(path, size=(24, 30), box=(4, 6, 20, 28), colour=(200, 40, 40, 255)):
    path.parent.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    if box:
        im.paste(colour, box)
    im.save(path)


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data))


def make_repo(root: Path):
    """A family, its motion set and its rig: the definitions every other source leans on."""
    write(root / "tool/art/motion/tiny.json", MOTION)
    write(root / "tool/art/families/hero-v1.json", {
        "$notes": {"character": "hero", "motionSet": "tiny"},
        "rigInputs": "art_runs/inputs/hero-v1",
        "frame": {"native": {"perRoom": True, "garden": {"width": 24, "height": 30, "pixelScale": PIXEL_SCALE}},
                  "scale": {"referencePose": "groove.a"}},
        "targets": [{"type": "kumbiaManifest", "atlas": "hero", "room": "garden", "frameId": "{clip}_{drawing}"}],
        "poses": [{"id": p, "clip": p.split(".")[0], "order": i} for i, p in enumerate(POSES)],
    })
    rig_poses = [{"id": p, "pivotX": 48, "groundY": 112, "bbox": [16, 24, 80, 112]} for p in POSES]
    write(root / "art_runs/inputs/hero-v1/rig.json", {"character": "hero", "poses": rig_poses})
    for p in POSES:
        png(root / f"art_runs/inputs/hero-v1/{p}.regions.png", (96, 120), (16, 24, 80, 112))


def by_id(index):
    return {s["id"]: s for s in index["sets"]}


def drawings(s, clip):
    return next(c for c in s["clips"] if c["id"] == clip)["drawings"]


class GalleryCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "repo"
        self.out = Path(self.tmp.name) / "out"
        make_repo(self.root)

    def build(self, *sources):
        return B.build(self.root, self.out, list(sources))


class Rig(GalleryCase):
    def test_labelled_and_anchored_in_image_pixels(self):
        s = by_id(self.build())["rig:hero-v1"]
        self.assertEqual((s["status"], s["sourceKind"], s["character"]), ("rig stand-in", "rig", "hero"))
        d = drawings(s, "groove")[0]
        self.assertEqual(d["rect"], [16, 24, 64, 88])
        self.assertEqual(d["anchor"], [32, 88])  # pivot and ground relative to the trimmed rect
        self.assertEqual(s["nativeDivisor"], PIXEL_SCALE)

    def test_prefers_proxy_over_regions(self):
        folder = self.root / "art_runs/inputs/hero-v1"
        png(folder / "groove.a.proxy.png", (96, 120), (10, 10, 20, 112), (1, 2, 3, 255))
        s = by_id(self.build())["rig:hero-v1"]
        self.assertEqual(drawings(s, "groove")[0]["rect"][2], 10)
        self.assertEqual(drawings(s, "groove")[1]["rect"][2], 64)

    def test_pose_without_a_render_is_missing(self):
        (self.root / "art_runs/inputs/hero-v1/hit.peak.regions.png").unlink()
        s = by_id(self.build())["rig:hero-v1"]
        peak = drawings(s, "hit")[1]
        self.assertTrue(peak["missing"])
        self.assertNotIn("img", peak)
        self.assertEqual(s["counts"], {"present": 3, "missing": 1, "expected": 4})


class Run(GalleryCase):
    def run_folder(self, name="run-1", poses=("groove.a",)):
        folder = self.root / "art_runs" / name
        write(folder / "run.json", {"run": name, "family": "tool/art/families/hero-v1.json"})
        for p in poses:
            png(folder / "final" / f"{p}.png")
        return folder

    def test_partial_run_shows_only_what_exists(self):
        self.run_folder()
        s = by_id(self.build())["run:run-1"]
        self.assertEqual((s["status"], s["sourceKind"], s["runId"]), ("candidate", "run", "run-1"))
        self.assertEqual(s["counts"], {"present": 1, "missing": 3, "expected": 4})
        groove = drawings(s, "groove")
        self.assertIn("img", groove[0])
        self.assertTrue(groove[1]["missing"])
        self.assertTrue(self.out.joinpath(groove[0]["img"]).is_file())
        self.assertTrue(any("partial" in w for w in s["warnings"]))

    def test_anchor_maps_through_pixel_scale_and_trim_like_pack_atlas(self):
        self.run_folder()
        d = drawings(by_id(self.build())["run:run-1"], "groove")[0]
        self.assertEqual(d["rect"], [4, 6, 16, 22])
        self.assertEqual(d["anchor"], [48 / PIXEL_SCALE - 4, 112 / PIXEL_SCALE - 6])
        self.assertNotIn("anchorAssumed", d)

    def test_run_with_no_frames_is_listed_empty(self):
        write(self.root / "art_runs/waiting/run.json", {"run": "waiting", "family": "tool/art/families/hero-v1.json"})
        s = by_id(self.build())["run:waiting"]
        self.assertEqual(s["counts"]["present"], 0)
        self.assertEqual(s["counts"]["expected"], 4)
        self.assertIn("no frames yet", s["warnings"])

    def test_loose_source_without_run_json_assumes_anchor_and_says_so(self):
        outside = Path(self.tmp.name) / "elsewhere/loose"
        png(outside / "final/groove.a.png")
        s = by_id(self.build(str(outside)))["run:loose"]
        d = drawings(s, "groove")[0]
        self.assertTrue(d["anchorAssumed"])
        self.assertEqual(d["anchor"], [8, 22])
        self.assertEqual(s["character"], "unknown")
        self.assertTrue(any("no readable run.json" in w for w in s["warnings"]))
        self.assertEqual(next(c for c in s["clips"] if c["id"] == "groove")["timing"]["source"], "assumed")

    def test_half_written_png_is_missing_not_a_crash(self):
        folder = self.run_folder(poses=("groove.a",))
        (folder / "final/groove.b.png").write_bytes((folder / "final/groove.a.png").read_bytes()[:40])
        s = by_id(self.build())["run:run-1"]
        bad = drawings(s, "groove")[1]
        self.assertTrue(bad["missing"])
        self.assertIn("unreadable", bad["reason"])

    def test_transparent_frame_is_missing(self):
        folder = self.run_folder(poses=("groove.a",))
        png(folder / "final/groove.b.png", box=None)
        self.assertIn("transparent", drawings(by_id(self.build())["run:run-1"], "groove")[1]["reason"])

    def test_absolute_family_path_from_another_checkout_resolves_here(self):
        folder = self.run_folder()
        write(folder / "run.json", {"run": "run-1", "family": "/somewhere/else/tool/art/families/hero-v1.json"})
        self.assertEqual(by_id(self.build())["run:run-1"]["character"], "hero")

    def test_changed_family_is_flagged(self):
        folder = self.run_folder()
        write(folder / "run.json", {"run": "run-1", "family": "tool/art/families/hero-v1.json", "familySha256": "0" * 64})
        self.assertTrue(any("family changed" in w for w in by_id(self.build())["run:run-1"]["warnings"]))

    def test_new_frames_appear_on_rerun_and_old_images_are_pruned(self):
        folder = self.run_folder()
        first = by_id(self.build())["run:run-1"]
        old = self.out / drawings(first, "groove")[0]["img"]
        self.assertEqual(first["counts"]["present"], 1)
        png(folder / "final/groove.a.png", box=(1, 1, 9, 9))
        png(folder / "final/groove.b.png", colour=(9, 200, 9, 255))
        again = by_id(self.build())["run:run-1"]
        self.assertEqual(again["counts"]["present"], 2)
        self.assertFalse(old.exists())


class Atlases(GalleryCase):
    def candidate(self, frames, name="hero-v1.candidate.json", image="hero-v1.png", **extra):
        folder = self.root / "assets/art/ensemble"
        png(folder / "hero-v1.png", (64, 64), (0, 0, 64, 64))
        write(folder / name, {"atlas": "hero", "image": image, "family": "tool/art/families/hero-v1.json",
                              "frames": frames, **extra})

    def frame(self, pose=None, rect=(0, 0, 10, 20), anchor=(5, 20), **extra):
        f = {"rect": list(rect), "anchor": list(anchor), "pixelsPerUnit": 2.0, **extra}
        if pose:
            f["provenance"] = {"run": "run-9", "pose": pose}
        return f

    def test_partial_candidate_keeps_gaps(self):
        self.candidate({"groove_a": self.frame("groove.a"), "hit_peak": self.frame("hit.peak")})
        s = by_id(self.build())["candidate:hero-v1"]
        self.assertEqual((s["status"], s["runId"], s["character"]), ("candidate", "run-9", "hero"))
        self.assertEqual(s["counts"], {"present": 2, "missing": 2, "expected": 4})
        self.assertEqual([bool(d.get("missing")) for d in drawings(s, "groove")], [False, True])
        self.assertEqual(drawings(s, "groove")[0]["anchor"], [5, 20])

    def test_frames_found_without_provenance_through_frame_id_template(self):
        self.candidate({"hit_prep": self.frame()})
        self.assertEqual(by_id(self.build())["candidate:hero-v1"]["counts"]["present"], 1)

    def test_alias_copies_are_not_counted_twice(self):
        self.candidate({"groove_a": self.frame("groove.a"), "occupied": self.frame(aliasOf="groove_a")})
        s = by_id(self.build())["candidate:hero-v1"]
        self.assertEqual(s["counts"]["present"], 1)
        self.assertEqual(drawings(s, "groove")[0]["aliases"], ["occupied"])

    def test_rect_outside_image_is_missing(self):
        self.candidate({"groove_a": self.frame("groove.a", rect=(60, 60, 10, 10))})
        d = drawings(by_id(self.build())["candidate:hero-v1"], "groove")[0]
        self.assertTrue(d["missing"])
        self.assertIn("outside", d["reason"])

    def test_missing_atlas_image_marks_every_frame_missing(self):
        self.candidate({"groove_a": self.frame("groove.a")}, image="nope.png")
        s = by_id(self.build())["candidate:hero-v1"]
        self.assertEqual(s["counts"]["present"], 0)
        self.assertTrue(any("nope.png" in w for w in s["warnings"]))

    def test_malformed_json_is_listed_not_fatal(self):
        folder = self.root / "assets/art/ensemble"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "bad.candidate.json").write_text("{not json")
        s = by_id(self.build())["candidate:bad"]
        self.assertEqual(s["counts"]["present"], 0)
        self.assertEqual(s["warnings"], ["candidate JSON is unreadable"])

    def manifest(self, atlases):
        folder = self.root / "assets/art/ensemble"
        png(folder / "hero-v1.png", (64, 64), (0, 0, 64, 64))
        write(folder / "manifest.json", {"version": 1, "atlases": atlases})

    def test_shipped_atlas_names_poses_through_runtime_aliases(self):
        self.manifest({"hero": {"image": "hero-v1.png", "referenceFrame": "occupied", "frames": {
            "occupied": self.frame(rect=(0, 0, 10, 30), anchor=(5, 30)),
            "ready": self.frame(rect=(0, 0, 10, 40), anchor=(5, 40), mirror=True)}}})
        s = by_id(self.build())["shipped:hero"]
        self.assertEqual(s["status"], "shipped")
        self.assertEqual(s["counts"], {"present": 2, "missing": 2, "expected": 4})
        prep = drawings(s, "hit")[0]
        self.assertEqual(prep["poseId"], "hit.prep")
        self.assertEqual(prep["aliases"], ["ready"])
        self.assertTrue(prep["mirror"])
        self.assertEqual(s["gameReference"]["heightPx"], 40)  # the game scales by 'ready', not the listed reference

    def test_atlas_with_no_motion_groups_lettered_frames_and_assumes_timing(self):
        self.manifest({"guest": {"image": "hero-v1.png", "referenceFrame": "stand_a", "frames": {
            "stand_a": self.frame(), "stand_b": self.frame(), "table": self.frame()}}})
        s = by_id(self.build())["shipped:guest"]
        stand = next(c for c in s["clips"] if c["id"] == "stand")
        self.assertEqual([d["poseId"] for d in stand["drawings"]], ["stand.a", "stand.b"])
        self.assertEqual(stand["timing"]["source"], "assumed")
        self.assertEqual(stand["durationBeats"], 2 * B.ASSUMED_BEATS_PER_DRAWING)
        self.assertIn("table", [c["id"] for c in s["clips"]])

    def test_party_manifest_can_be_added_as_a_source(self):
        folder = self.root / "assets/art/party"
        png(folder / "sheet.png", (64, 64), (0, 0, 64, 64))
        write(folder / "manifest.json", {"atlases": {"crowd": {"image": "sheet.png", "frames": {"cheer_a": self.frame()}}}})
        sets = by_id(self.build("assets/art/party/manifest.json"))
        self.assertEqual(sets["shipped:crowd"]["counts"]["present"], 1)


class Timing(GalleryCase):
    def test_motion_timing_is_even_spacing_of_duration(self):
        s = by_id(self.build())["rig:hero-v1"]
        groove = next(c for c in s["clips"] if c["id"] == "groove")
        self.assertEqual(groove["timing"]["source"], "motion")
        self.assertEqual([d["beats"] for d in groove["drawings"]], [1.0, 1.0])

    def test_real_accent_events_land_on_drawing_boundaries(self):
        """Even spacing is an assumption; the authored events are its only check."""
        real = json.loads((ART / "motion/opponent-64.json").read_text()) if (ART / "motion/opponent-64.json").exists() else None
        if real is None:
            self.skipTest("opponent-64 is not on this branch")
        for clip in real["clips"]:
            step = clip["durationBeats"] / clip["drawings"]
            for event in clip["events"]:
                self.assertAlmostEqual(event["beat"] / step, round(event["beat"] / step), places=2, msg=clip["id"])

    def test_motion_count_disagreeing_with_table_is_warned(self):
        motion = json.loads(json.dumps(MOTION))
        motion["clips"][0]["drawings"] = 3
        write(self.root / "tool/art/motion/tiny.json", motion)
        self.assertTrue(any("motion says 3" in w for w in by_id(self.build())["rig:hero-v1"]["warnings"]))

    def test_runtime_phrases_only_use_aliases_and_fill_each_beat(self):
        move = dict(B.RUNTIME_PHRASES["left_hand"])
        self.assertAlmostEqual(sum(move.values()), 1.0, places=6)
        s = by_id(self.build())["rig:hero-v1"]
        watch = next(c for c in s["clips"] if c["id"] == "game:watch")
        self.assertTrue(all(d["missing"] for d in watch["drawings"]))  # tiny set has no watch aliases
        lead = next(c for c in s["clips"] if c["id"] == "game:lead_in")
        self.assertEqual(lead["timing"]["source"], "game")
        self.assertIn("img", lead["drawings"][0])

    def test_runtime_phrases_do_not_inflate_counts(self):
        self.assertEqual(by_id(self.build())["rig:hero-v1"]["counts"]["expected"], 4)


class GameScale(GalleryCase):
    LAYOUT = """
      static const logicalWidth = 180.0;
      'garden': PartyRoomLayout(
        id: 'garden',
        floor: const PartyFloorPlane(
          horizonY: .255,
          referenceFootY: .40,
          referenceHeight: .094,
        ),
      'bar': PartyRoomLayout(
        floor: const PartyFloorPlane(
          horizonY: .205,
          referenceFootY: .40,
          referenceHeight: .23,
        ),
    """
    SCENE = """
      final floor = PartyPoint(.5 + .2 * pose.floorYield, isBar ? .45 : .53);
      final homeY = isBar ? .62 : .69;
      final height = _adultHeight(viewport, room, floor, stature: .35);
    """

    def write_game(self, layout=None, scene=None):
        folder = self.root / "lib/gameplay"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "party_layout.dart").write_text(layout or self.LAYOUT)
        (folder / "garden_scene.dart").write_text(scene or self.SCENE)

    def test_reads_floor_planes_and_marks(self):
        self.write_game()
        g = self.build()["game"]
        self.assertTrue(g["available"])
        self.assertEqual(g["logicalWidth"], 180.0)
        self.assertEqual(g["heroStature"], .35)
        self.assertEqual(g["rooms"]["garden"], {"horizonY": .255, "referenceFootY": .40, "referenceHeight": .094,
                                                "challengerFootY": .53, "heroFootY": .69})
        self.assertEqual(g["rooms"]["bar"]["challengerFootY"], .45)

    def test_changed_game_code_reports_unavailable_rather_than_guessing(self):
        self.write_game(scene="nothing recognisable")
        g = self.build()["game"]
        self.assertFalse(g["available"])
        self.assertIn("reason", g)

    def test_no_game_code_reports_unavailable(self):
        self.assertFalse(self.build()["game"]["available"])

    def test_reference_uses_ready_alias_for_candidates_without_alias_frames(self):
        folder = self.root / "assets/art/ensemble"
        png(folder / "hero-v1.png", (64, 64), (0, 0, 64, 64))
        write(folder / "hero-v1.candidate.json", {"atlas": "hero", "image": "hero-v1.png", "family": "tool/art/families/hero-v1.json",
              "referenceFrame": "groove_a", "frames": {
                  "groove_a": {"rect": [0, 0, 10, 30], "anchor": [5, 30], "provenance": {"pose": "groove.a"}},
                  "hit_prep": {"rect": [0, 0, 10, 44], "anchor": [5, 44], "provenance": {"pose": "hit.prep"}}}})
        ref = by_id(self.build())["candidate:hero-v1"]["gameReference"]
        self.assertEqual((ref["frame"], ref["heightPx"], ref["approx"]), ("ready", 44, False))

    def test_set_lacking_the_reference_frame_uses_rig_bbox_and_marks_approximate(self):
        folder = self.root / "art_runs/run-1"
        write(folder / "run.json", {"run": "run-1", "family": "tool/art/families/hero-v1.json"})
        png(folder / "final/groove.a.png")
        ref = by_id(self.build())["run:run-1"]["gameReference"]
        self.assertTrue(ref["approx"])
        self.assertEqual(ref["heightPx"], (112 - 24) / PIXEL_SCALE)

    def test_atlas_the_game_sizes_case_by_case_is_marked_approximate(self):
        folder = self.root / "assets/art/ensemble"
        png(folder / "props.png", (64, 64), (0, 0, 64, 64))
        write(folder / "manifest.json", {"version": 1, "atlases": {"furniture": {
            "image": "props.png", "referenceFrame": "chair",
            "frames": {"chair": {"rect": [0, 0, 10, 30], "anchor": [5, 30]}}}}})
        ref = by_id(self.build())["shipped:furniture"]["gameReference"]
        self.assertEqual((ref["heightPx"], ref["approx"]), (30, True))

    def test_set_with_no_reference_at_all_is_none(self):
        outside = Path(self.tmp.name) / "elsewhere/loose"
        png(outside / "final/thing.a.png")
        self.assertIsNone(by_id(self.build(str(outside)))["run:loose"]["gameReference"])


class Output(GalleryCase):
    def test_relative_source_means_the_repository_not_the_working_directory(self):
        folder = self.root / "extra/hero-run"
        png(folder / "final/groove.a.png")
        self.assertIn("run:hero-run", by_id(self.build("extra/hero-run")))

    def test_writes_viewer_and_index(self):
        self.build()
        for name in ("index.html", "gallery.css", "core.js", "gallery.js", "index.json"):
            self.assertTrue((self.out / name).is_file(), name)
        self.assertEqual(json.loads((self.out / "index.json").read_text())["schema"], 1)

    def test_viewer_has_no_external_or_absolute_references(self):
        for name in B.VIEWER_FILES:
            text = (B.HERE / name).read_text()
            self.assertNotIn("http://", text, name)
            self.assertNotIn("https://", text, name)
            self.assertNotIn('src="/', text, name)
            self.assertNotIn('href="/', text, name)

    def test_every_image_in_the_index_exists(self):
        index = self.build()
        for s in index["sets"]:
            for c in s["clips"]:
                for d in c["drawings"]:
                    if not d.get("missing"):
                        self.assertTrue((self.out / d["img"]).is_file())

    def test_only_opaque_paintings_count_as_backgrounds(self):
        folder = self.root / "assets/art/garden"
        folder.mkdir(parents=True)
        Image.new("RGB", (32, 48), (9, 9, 9)).save(folder / "room.png")
        png(folder / "sprite.png")
        index = self.build()
        self.assertEqual([b["id"] for b in index["backgrounds"]], ["garden/room.png"])
        self.assertEqual((index["backgrounds"][0]["width"], index["backgrounds"][0]["height"]), (32, 48))
        self.assertIn("assets/art/party/ has no opaque room background", index["backgroundNotes"])

    def test_source_with_nothing_viewable_is_a_warning(self):
        index = self.build("does/not/exist")
        self.assertTrue(any("does/not/exist" in w for w in index["warnings"]))

    def test_same_named_runs_stay_distinct(self):
        for parent in ("a", "b"):
            png(Path(self.tmp.name) / parent / "same/final/groove.a.png")
        sets = by_id(self.build(str(Path(self.tmp.name) / "a/same"), str(Path(self.tmp.name) / "b/same")))
        self.assertIn("run:same", sets)
        self.assertIn("run:same-2", sets)

    def test_a_source_named_twice_is_built_once(self):
        folder = "art_runs/inputs/hero-v1"
        self.assertEqual(sum(s["sourceKind"] == "rig" for s in self.build(folder, folder)["sets"]), 1)

    def test_refuses_to_write_over_the_repository(self):
        with self.assertRaises(SystemExit):
            B.build(self.root, self.root, [])
        with self.assertRaises(SystemExit):
            B.build(self.root, self.root.parent, [])

    def test_cli_runs(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(B.main(["--root", str(self.root), "--out", str(self.out)]), 0)
        self.assertTrue((self.out / "index.json").is_file())


if __name__ == "__main__":
    unittest.main()
