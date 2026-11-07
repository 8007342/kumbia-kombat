"""Decode the share page's QR code the way a phone would, outside Flutter.

`flutter test test/qr_page_test.dart` writes build/share-qr.png; then:

    uv run --no-project --with zxing-cpp --with pillow python -I \
        tool/console/decode_qr.py build/share-qr.png

Prints the text and exits 0 when it is https://kumbias.tlatoani.net. It also
tries the code shrunk to 120 px and blurred, roughly a phone at arm's length.
"""

import sys

import zxingcpp
from PIL import Image, ImageFilter

EXPECTED = "https://kumbias.tlatoani.net"


def decode(image):
    found = zxingcpp.read_barcodes(image)
    return [r.text for r in found if r.format == zxingcpp.BarcodeFormat.QRCode]


def main(path):
    full = Image.open(path).convert("RGB")
    trials = {
        "as drawn": full,
        "120 px": full.resize((120, 120), Image.BILINEAR),
        "blurred": full.filter(ImageFilter.GaussianBlur(2.5)),
    }
    ok = True
    for name, image in trials.items():
        texts = decode(image)
        print(f"{name}: {texts}")
        ok &= texts == [EXPECTED]
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
