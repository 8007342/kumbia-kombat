# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy>=1.26,<3"]
# ///
"""Trains the small comparison network, in numpy only: no PyTorch.

    dart run tool/gesture/compare.dart --export "$OUT"
    uv run tool/gesture/train.py --data "$OUT" --features raw --hidden 24 \
        --out "$OUT/mlp-raw-24.json"

The strokes come from synth.dart, so there's one generator. See README.md.
"""
import argparse
import json
import pathlib

import numpy as np

LABELS = ["spin", "flick", "wave", "stomp", "circle"]


def load(path):
    rows = json.loads(pathlib.Path(path).read_text())
    x = np.array([row["x"] for row in rows], dtype=np.float64)
    y = np.array([LABELS.index(row["y"]) if row["y"] in LABELS else -1 for row in rows])
    keep = y >= 0  # Taps are gated by the same slop rule before any candidate.
    return x[keep], y[keep]


def forward(params, x):
    activations = [x]
    for i, (w, b) in enumerate(params):
        z = activations[-1] @ w.T + b
        activations.append(z if i == len(params) - 1 else np.maximum(z, 0))
    return activations


def train(x, y, val_x, val_y, hidden, epochs, seed):
    rng = np.random.default_rng(seed)
    sizes = [x.shape[1], *hidden, len(LABELS)]
    params = [
        (rng.normal(0, np.sqrt(2 / a), (b, a)), np.zeros(b))
        for a, b in zip(sizes, sizes[1:])
    ]
    moments = [
        [np.zeros_like(w), np.zeros_like(b), np.zeros_like(w), np.zeros_like(b)]
        for w, b in params
    ]
    best, best_acc, step = None, -1.0, 0
    total_steps = epochs * (len(x) // 128)
    for epoch in range(epochs):
        order = rng.permutation(len(x))
        for start in range(0, len(x) - 127, 128):
            batch = order[start : start + 128]
            act = forward(params, x[batch])
            logits = act[-1]
            logits = logits - logits.max(1, keepdims=True)
            probs = np.exp(logits)
            probs /= probs.sum(1, keepdims=True)
            probs[np.arange(len(batch)), y[batch]] -= 1
            grad = probs / len(batch)
            step += 1
            rate = 0.003 * 0.5 * (1 + np.cos(np.pi * step / total_steps))
            for i in reversed(range(len(params))):
                w, b = params[i]
                gw = grad.T @ act[i] + 1e-4 * w
                gb = grad.sum(0)
                m = moments[i]
                for j, (p, g) in enumerate(((w, gw), (b, gb))):
                    m[j] = 0.9 * m[j] + 0.1 * g
                    m[j + 2] = 0.999 * m[j + 2] + 0.001 * g * g
                    hat = m[j] / (1 - 0.9**step)
                    var = m[j + 2] / (1 - 0.999**step)
                    p -= rate * hat / (np.sqrt(var) + 1e-8)
                if i > 0:
                    grad = (grad @ w) * (act[i] > 0)
        acc = (forward(params, val_x)[-1].argmax(1) == val_y).mean()
        if acc > best_acc:
            best_acc = acc
            best = [(w.copy(), b.copy()) for w, b in params]
    return best, best_acc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True)
    parser.add_argument("--features", required=True, choices=["raw", "positions", "measures"])
    parser.add_argument("--hidden", type=int, nargs="*", default=[24])
    parser.add_argument("--epochs", type=int, default=40)
    parser.add_argument("--seed", type=int, default=1852)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    x, y = load(f"{args.data}/{args.features}-train.json")
    vx, vy = load(f"{args.data}/{args.features}-validate.json")
    params, acc = train(x, y, vx, vy, args.hidden, args.epochs, args.seed)
    pathlib.Path(args.out).write_text(
        json.dumps(
            {
                "features": args.features,
                "steps": 16,
                "labels": LABELS,
                "seed": args.seed,
                "validationAccuracy": acc,
                "layers": [
                    {
                        "w": [[round(float(v), 5) for v in row] for row in w],
                        "b": [round(float(v), 5) for v in b],
                    }
                    for w, b in params
                ],
            }
        )
    )
    print(f"{args.features} {args.hidden}: validation {acc * 100:.2f}%")


if __name__ == "__main__":
    main()
