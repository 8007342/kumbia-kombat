#!/usr/bin/env python3
"""The pure Python build at a chosen worker count, into a scratch root, for baselines.

  uv run --no-project --with numpy python -I tool/music/mixrs/compare/run_python_build.py WORKERS OUT [LEVEL...]

CONFIG in the environment names a levels.json; MIX_PY another mix.py; MIX_ENGINE=python or
MIXRS=BINARY chooses the engine. VERIFY=1 runs verify after, into OUT/verify.json. DUMP_RAW=1
keeps what each asset is given before encoding, in OUT/raw, so compare.py can test the audio
without the codecs in the way.
"""
import importlib.util
import json
import os
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mix", os.environ.get("MIX_PY") or HERE.parents[1] / "mix" / "mix.py")
mix = importlib.util.module_from_spec(spec)
sys.modules["mix"] = mix
spec.loader.exec_module(mix)

if __name__ == "__main__":
    workers, out = int(sys.argv[1]), pathlib.Path(sys.argv[2]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    cfg = mix.load_config(os.environ.get("CONFIG"))
    if os.environ.get("DUMP_RAW"):
        write_asset = mix.write_asset

        def keeping(audio, base, config, root):
            raw = out / "raw" / (base.relative_to(out / config["outDir"]).as_posix().replace("/", "__") + ".f32")
            raw.parent.mkdir(parents=True, exist_ok=True)
            audio.astype("float32").tofile(raw)
            return write_asset(audio, base, config, root)
        mix.write_asset = keeping
    mix.build(cfg, set(sys.argv[3:]) or None, out, workers=workers, report_path=out / "report.json")
    if os.environ.get("VERIFY"):
        results, failures = mix.verify(cfg, out)
        (out / "verify.json").write_text(json.dumps(results, indent=1) + "\n")
        print(f"{len(failures)} verify failures", *failures[:8], sep="\n")
