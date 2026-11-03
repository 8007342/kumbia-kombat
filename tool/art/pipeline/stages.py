"""Content-addressed stage store: an output is identified by the hash of its inputs.

A completed entry is <root>/<stage>/<key>/ holding .inputs.json. Work happens in a
temporary sibling that is renamed on success, so an interrupted run leaves nothing
that looks finished, and starting again redoes only what is missing.

The root must outlive a forge, because the checkout and /work/tmp do not:
$KUMBIA_ART_CACHE, else ~/.cache/tillandsias-project/kumbia-art.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Callable


def default_root() -> Path:
    env = os.environ.get("KUMBIA_ART_CACHE")
    return Path(env) if env else Path.home() / ".cache" / "tillandsias-project" / "kumbia-art"


def key_of(inputs) -> str:
    """Stable sha256 of JSON-serialisable inputs (dict order does not matter)."""
    blob = json.dumps(inputs, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(blob.encode()).hexdigest()


def sha_file(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class Store:
    def __init__(self, root: Path | None = None):
        self.root = Path(root) if root else default_root()
        self.ran: list[tuple[str, str]] = []
        self.reused: list[tuple[str, str]] = []

    def path(self, stage: str, key: str) -> Path:
        return self.root / stage / key

    def has(self, stage: str, key: str) -> bool:
        return (self.path(stage, key) / ".inputs.json").exists()

    def run(self, stage: str, inputs, work: Callable[[Path], None]) -> Path:
        """Reuse the output for these inputs, or run work(dir) and commit it atomically."""
        key = key_of(inputs)
        final = self.path(stage, key)
        if self.has(stage, key):
            self.reused.append((stage, key))
            return final
        final.parent.mkdir(parents=True, exist_ok=True)
        tmp = Path(tempfile.mkdtemp(prefix=f".{key[:12]}.", dir=final.parent))
        try:
            work(tmp)
            (tmp / ".inputs.json").write_text(json.dumps(inputs, sort_keys=True, indent=1, ensure_ascii=False) + "\n")
            if final.exists():
                shutil.rmtree(final)
            tmp.rename(final)
        except BaseException:
            shutil.rmtree(tmp, ignore_errors=True)
            raise
        self.ran.append((stage, key))
        return final
