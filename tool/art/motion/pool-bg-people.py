#!/usr/bin/env python3
"""Writes the billiards room's background players into characters/pool-bg-*.json: three people, one table's routine.

They are adults, fully clothed, with their own silhouettes, and they aren't dancing or interested in Mācron.
"""
import json
from pathlib import Path

OUT = Path(__file__).parents[1] / "characters"
FLOOR = {"mode": "planted", "hand": "r", "butt": [-0.42, -0.05]}
CUE = {
    "length": 1.5,
    "default": FLOOR,
    "clips": {
        "chalk": {"mode": "held", "hand": "r", "dir": [0.42, -0.2, 0.88], "grip": 0.52, "otherHand": "tip"},
        "lean": {"mode": "held", "hand": "r", "dir": [0.85, -0.5, -0.02], "grip": 0.12},
        "watch": {"mode": "planted", "hand": "r", "butt": [0.1, -0.32], "otherHand": 50},
        "clap": {"mode": "planted", "through": "r_sho", "butt": [-0.42, -0.05]},
    },
    "poses": {"lean.stroke": {"mode": "held", "hand": "r", "dir": [0.85, -0.5, -0.02], "grip": 0.3}},
}
SHARED_EXTRA = ("Both eyes are open. This is a grown adult, fully clothed. There is exactly one pool cue, long, slim, straight and rigid, "
                "with a pale wooden shaft, a white tip and a dark wooden butt: it lies along the thin white line in image 2. "
                "Do not draw the line itself, and do not draw a table. ")
SHAFT = {"id": "cue_shaft", "shape": "cue-shaft", "region": "prop", "colour": "#C9984F", "alsoIn": ["skin", "shirt", "cloth", "trousers"], "text": "pale wooden cue shaft with a white tip"}
BUTT = {"id": "cue_butt", "shape": "cue-butt", "region": "prop_dark", "colour": "#5E3320", "alsoIn": ["skin", "trousers", "shoes"], "text": "dark wooden cue butt"}
CHALK = {"id": "chalk", "shape": "palette-only", "region": "accessory", "colour": "#3E8EDE", "alsoIn": ["skin", "prop"], "text": "a small cube of blue billiard chalk"}

PEOPLE = {
    "a": dict(
        noun="man", pronouns=["he", "him", "his"], skin="#B97F58", preset="slim-adult", seed=989400,
        description="Tall thin older man in a flat cap and shirtsleeves.",
        traits="tall thin adult man of about seventy, long face, grey moustache, a stoop",
        demeanor="absorbed in the shot",
        look="very tall and thin adult build with a slight stoop, long face with a grey moustache, tan skin, a flat brown tweed cap, pale blue shirt with the sleeves rolled, dark brown braces, baggy grey trousers and scuffed black shoes and thick dark ink outline",
        garments=[("hat", "brimmed-hat", "hat", "#6A5138", "flat brown tweed cap"), ("shirt", "shirt-fitted", "shirt", "#A9C2D6", "pale blue shirt with rolled sleeves"),
                  ("braces", "waistcoat-fitted", "cloth", "#4A3020", "dark brown braces"), ("trousers", "trousers", "trousers", "#6B6D70", "baggy grey trousers"), ("shoes", "shoes-flat", "shoes", "#26222A", "scuffed black shoes")]),
    "b": dict(
        noun="woman", pronouns=["she", "her", "her"], skin="#6E432C", preset="stocky-adult", seed=989500,
        description="Short round woman of about forty-five with a big halo of curls and a mustard cardigan.",
        traits="short round adult woman of about forty-five, big curly hair, round glasses",
        demeanor="cheerfully absorbed in the game",
        look="short, round, sturdy adult build, deep brown skin, a big round halo of dark curly hair, round glasses, a long-sleeved buttoned mustard cardigan, wide navy trousers and flat white shoes and thick dark ink outline",
        garments=[("hair", "puff", "hair", "#1C1412", "big halo of dark curly hair"), ("shirt", "shirt-stocky", "shirt", "#D8A32E", "long-sleeved mustard cardigan"),
                  ("trousers", "trousers", "trousers", "#28345C", "wide navy trousers"), ("shoes", "shoes-flat", "shoes", "#E4E0D6", "flat white shoes")]),
    "c": dict(
        noun="man", pronouns=["he", "him", "his"], skin="#D9A67E", preset="stocky-adult", seed=989600,
        description="Broad bald bearded man of about fifty in a plaid shirt.",
        traits="broad heavy adult man of about fifty, bald head, thick red-brown beard",
        demeanor="calm, unhurried",
        look="broad, heavy adult build with big shoulders, a bald head, a thick red-brown beard, light skin, a red and black plaid flannel shirt with long sleeves, dark blue jeans and tan work boots and thick dark ink outline",
        garments=[("beard", "short-hair-moustache", "hair", "#7A3F22", "thick red-brown beard"), ("shirt", "shirt-stocky", "shirt", "#A32A2A", "red and black plaid flannel shirt"),
                  ("trousers", "trousers", "trousers", "#2C3A58", "dark blue jeans"), ("shoes", "shoes-flat", "shoes", "#A8784A", "tan work boots")]),
}

for key, p in PEOPLE.items():
    cid = f"pool-bg-{key}"
    region_of = {g[2] for g in p["garments"]}
    alsoin = {"shirt": ["prop"]}
    garments = [{"id": i, "shape": s, "region": r, "colour": col, "text": t, **({"alsoIn": alsoin[i]} if i in alsoin else {})} for i, s, r, col, t in p["garments"]]
    c = {
        "$comment": "A background player in the billiards room, written by tool/art/motion/pool-bg-people.py. Agent's design choice; the owner can reverse it.",
        "id": cid, "family": f"{cid}-v1", "style": "party-pixel", "description": p["description"],
        "body": {"preset": p["preset"]}, "pronouns": p["pronouns"], "skin": p["skin"], "traits": p["traits"], "demeanor": p["demeanor"],
        "garments": garments + [SHAFT, BUTT, CHALK],
        "motion": {"set": "pool-bg", "overrides": {}},
        "drawing": {
            "noun": p["noun"], "fits": "head, both shoes and both hands", "look": p["look"], "extra": SHARED_EXTRA, "count": 2,
            "cue": CUE, "seed": p["seed"], "score": {"silhouetteTolerance": 30},
            "sheet": {"source": {"image": "tool/art/references/pool-player/front.png", "styleOnly": True},
                      "views": {"front": {"image": f"tool/art/references/{cid}/front.png",
                                          "description": "standing easy, turned three-quarters toward the right of the picture, a pool cue upright in the right hand with its butt on the floor, looking toward the right",
                                          "stageScale": 0.84}}},
        },
        "references": {"mode": "source", "sources": []},
        "targets": [{"room": "billiards", "atlas": cid, "out": f"assets/art/ensemble/{cid}-v1.png", "native": [256, 320], "pixelScale": 3}],
        "seedBase": p["seed"],
    }
    (OUT / f"{cid}.json").write_text(json.dumps(c, indent=1, ensure_ascii=False) + "\n")
