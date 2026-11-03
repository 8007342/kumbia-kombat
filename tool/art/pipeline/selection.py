"""Selection state keyed by frame identity, so acceptance survives unrelated edits.

selection.json: {pose: {"k": candidate, "key": frame key, "accepted": bool}}
A frame whose key changed returns to review; everything else stays as it was.
"""
from __future__ import annotations


def reconcile(selection: dict, new_keys: dict[str, str]) -> tuple[dict, list[str]]:
    """Returns (updated selection, poses that went back to review)."""
    out, returned = {}, []
    for pose, key in new_keys.items():
        cur = selection.get(pose)
        if cur is None:
            out[pose] = {"k": None, "key": key, "accepted": False}
        elif cur.get("key") == key:
            out[pose] = cur
        else:
            if cur.get("accepted"):
                returned.append(pose)
            out[pose] = {**cur, "key": key, "accepted": False}
    return out, sorted(returned)


def unaccepted(selection: dict, required: list[str]) -> list[str]:
    return sorted(p for p in required if not (selection.get(p) or {}).get("accepted"))


def promotion_refusal(selection: dict, required: list[str]) -> str | None:
    missing = unaccepted(selection, required)
    return f"promotion refused: {len(missing)} frames unaccepted: {', '.join(missing)}" if missing else None
