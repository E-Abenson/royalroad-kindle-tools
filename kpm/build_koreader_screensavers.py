#!/usr/bin/env python3
"""Build normal-grayscale KOReader screensavers in the KPM package.

The installed folder keeps its historical "-inverted" name so an existing
KOReader custom-screensaver folder selection does not need to be changed.
The image pixels written by this builder are normal (not inverted).
"""
from __future__ import annotations

import base64
import hashlib
import io
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "kpm" / "assets"
OUTPUT_DIR = ROOT / "kpm" / "package" / "files" / "koreader-screensavers-inverted"

SOURCES = [
    (
        "01_Rav_Zvi_Kushelevsky.png",
        "b8b6fc05c12f1d272a6247256b25a330116a3a5614d2c0052cf1d93b578c1920",
    ),
    (
        "02_Rav_Osher_Arieli.png",
        "736f9554e2f5b743f50fb4fd675bce7b4f68fcfb2b15ec2aafdd324f8024b67d",
    ),
]
PINNED_REF = "61e39709381cedb675d88b220abfb5d27164f865"
SOURCE_BASE = (
    "https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/"
    f"{PINNED_REF}/kindle-screensaver-generator/output/"
)
# This prepared JPEG is the negative/inverted source. We reverse it here so
# the installed Chofetz Chaim image is a normal grayscale photograph.
CHOFETZ_SHA256 = "adbaa80290c621e120e796cb5d5b0dae4460577f2e7b0bed453a7a714a2f3cf0"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fetch_verified(filename: str, expected_sha: str) -> bytes:
    request = urllib.request.Request(
        SOURCE_BASE + filename,
        headers={"User-Agent": "RoyalRoad-KindleTools-KPM-build/1.0"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read()
    actual = sha256(data)
    if actual != expected_sha:
        raise RuntimeError(
            f"Pinned source hash mismatch for {filename}: expected {expected_sha}, got {actual}"
        )
    return data


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    expected_outputs: list[str] = []

    # The pinned Rav Zvi and Rav Osher source portraits are already normal.
    # Keep their grayscale levels and contrast; do not invert them.
    for filename, expected_sha in SOURCES:
        source = fetch_verified(filename, expected_sha)
        with Image.open(io.BytesIO(source)) as image:
            normal = image.convert("L")
            target = OUTPUT_DIR / filename
            temp = target.with_suffix(target.suffix + ".tmp")
            normal.save(temp, format="PNG", optimize=True)
            temp.replace(target)
        expected_outputs.append(filename)
        print(f"Built normal-grayscale {filename} ({target.stat().st_size} bytes)")

    chunks = sorted(ASSET_DIR.glob("chofetz-inverted.jpg.b64.part*"))
    if not chunks:
        raise RuntimeError("No Chofetz Chaim base64 asset segments were found.")
    encoded = "".join(path.read_text(encoding="ascii").strip() for path in chunks)
    try:
        chofetz_inverted = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        raise RuntimeError(f"Chofetz Chaim base64 asset is invalid: {exc}") from exc
    actual_chofetz = sha256(chofetz_inverted)
    if actual_chofetz != CHOFETZ_SHA256:
        raise RuntimeError(
            f"Chofetz Chaim source hash mismatch: expected {CHOFETZ_SHA256}, got {actual_chofetz}"
        )
    with Image.open(io.BytesIO(chofetz_inverted)) as image:
        if image.format != "JPEG" or image.size != (420, 598):
            raise RuntimeError(
                f"Unexpected Chofetz image format/dimensions: {image.format}, {image.size}"
            )
        # Reverse the old negative so the image displays as an ordinary,
        # correctly toned grayscale portrait in KOReader's sleep screen.
        chofetz_normal = ImageOps.invert(image.convert("L"))
        chofetz_name = "03_Chofetz_Chaim.jpg"
        chofetz_path = OUTPUT_DIR / chofetz_name
        chofetz_tmp = chofetz_path.with_suffix(chofetz_path.suffix + ".tmp")
        chofetz_normal.save(chofetz_tmp, format="JPEG", quality=95, optimize=True)
        chofetz_tmp.replace(chofetz_path)
    expected_outputs.append(chofetz_name)
    print(f"Built normal-grayscale {chofetz_name} ({chofetz_path.stat().st_size} bytes)")

    lines = [
        f"{sha256((OUTPUT_DIR / filename).read_bytes())}  {filename}"
        for filename in expected_outputs
    ]
    (OUTPUT_DIR / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="ascii")
    print("Wrote SHA256SUMS for " + ", ".join(expected_outputs))


if __name__ == "__main__":
    main()
