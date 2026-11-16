#!/usr/bin/env python3
"""Download and prepare two rabbinic photographs for a portrait Kindle screen.

Output is 8-bit grayscale PNG at 1072x1448.  The crops are intentionally
subject-aware: Rav Osher Arieli is kept toward the right side of his source
photo rather than being cropped around the geometric centre.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path
from typing import Any
from urllib.error import URLError

import requests
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

WIDTH = 1072
HEIGHT = 1448
MAX_DOWNLOAD_BYTES = 60 * 1024 * 1024
TIMEOUT_SECONDS = 45

SOURCES: list[dict[str, Any]] = [
    {
        "name": "Rav_Zvi_Kushelevsky",
        "filename": "01_Rav_Zvi_Kushelevsky.png",
        "url": "https://upload.wikimedia.org/wikipedia/commons/e/e1/R%27_Zvi_Kushelevsky.jpg",
        "fallbacks": [],
        "centering": (0.50, 0.42),
        "contrast": 1.16,
        "brightness": 1.035,
        "sharpen": 115,
        "source_note": (
            "Wikimedia Commons: R' Zvi Kushelevsky.jpg, 3549x4724. "
            "Photographer Yzfreeman; CC BY-SA 4.0."
        ),
    },
    {
        "name": "Rav_Osher_Arieli",
        "filename": "02_Rav_Osher_Arieli.png",
        "url": (
            "https://i.vimeocdn.com/video/"
            "2123355371-d30093f3d2af5b3c3be757a95fea26cde6559c5da5a269f7495767c76b5c87a3-d"
            "?f=webp&region=us"
        ),
        "fallbacks": [
            (
                "https://i.kikar.co.il/2026/02/19/"
                "8e3364a0-0d7a-11f1-a200-4dc719697151__h683_w1024.jpg?width=1400"
            ),
            (
                "https://hm-news.co.il/wp-content/uploads/2026/02/"
                "%D7%99%D7%A9%D7%99%D7%91%D7%AA-%D7%9E%D7%99%D7%A8-42-1024x683.jpg"
            ),
        ],
        "centering": (0.60, 0.49),
        "fallback_centerings": [(0.39, 0.50), (0.39, 0.50)],
        "contrast": 1.20,
        "brightness": 1.045,
        "sharpen": 125,
        "source_note": (
            "Primary: Agudath Israel Vimeo recording, 'YYK, 2.17.2026, "
            "Shiur from HaRav Asher Arieli'. Fallbacks: Kikar photo from "
            "the 19 February 2026 Malchei Rabbanan event; then Hm-News "
            "Malchei Rabbanan gallery image 42."
        ),
    },
]


def download_image(session: requests.Session, url: str) -> tuple[Image.Image, str, int]:
    response = session.get(url, timeout=TIMEOUT_SECONDS, stream=True)
    response.raise_for_status()

    content_length = response.headers.get("Content-Length")
    if content_length and int(content_length) > MAX_DOWNLOAD_BYTES:
        raise ValueError(f"Image is too large ({content_length} bytes)")

    chunks: list[bytes] = []
    total = 0
    for chunk in response.iter_content(chunk_size=1024 * 128):
        if not chunk:
            continue
        total += len(chunk)
        if total > MAX_DOWNLOAD_BYTES:
            raise ValueError("Image download exceeded the 60 MB safety limit")
        chunks.append(chunk)

    payload = b"".join(chunks)
    image = Image.open(io.BytesIO(payload))
    image.load()
    image = ImageOps.exif_transpose(image).convert("RGB")
    final_url = response.url
    response.close()
    return image, final_url, len(payload)


def prepare_image(
    image: Image.Image,
    width: int,
    height: int,
    centering: tuple[float, float],
    contrast: float,
    brightness: float,
    sharpen: int,
) -> Image.Image:
    # Crop to the Kindle's portrait aspect ratio, using a chosen subject focus.
    image = ImageOps.fit(
        image,
        (width, height),
        method=Image.Resampling.LANCZOS,
        centering=centering,
    )

    # Keep full 8-bit grayscale; the Kindle will map it to the display's
    # available gray levels. This avoids prematurely posterising the image.
    gray = ImageOps.grayscale(image)
    gray = ImageOps.autocontrast(gray, cutoff=(0.35, 0.35))
    gray = ImageEnhance.Contrast(gray).enhance(contrast)
    gray = ImageEnhance.Brightness(gray).enhance(brightness)

    # Mild sharpening restores facial/beard detail after downscaling.
    gray = gray.filter(
        ImageFilter.UnsharpMask(radius=1.25, percent=sharpen, threshold=3)
    )
    return gray


def main() -> int:
    output_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("dist")
    output_dir.mkdir(parents=True, exist_ok=True)

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (compatible; KindleScreensaverPrep/1.0; "
                "+https://github.com/E-Abenson/royalroad-kindle-tools)"
            ),
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        }
    )

    manifest: dict[str, Any] = {
        "output_size": f"{WIDTH}x{HEIGHT}",
        "format": "PNG, 8-bit grayscale",
        "processing": (
            "Portrait crop; gentle levels and contrast; slightly lifted "
            "brightness; restrained unsharp mask."
        ),
        "images": [],
    }

    for item in SOURCES:
        candidates = [item["url"], *item.get("fallbacks", [])]
        source_image: Image.Image | None = None
        source_url = ""
        source_bytes = 0
        centering = tuple(item["centering"])
        errors: list[str] = []

        for index, candidate in enumerate(candidates):
            try:
                source_image, source_url, source_bytes = download_image(
                    session, candidate
                )
                if index > 0:
                    centerings = item.get("fallback_centerings", [])
                    if index - 1 < len(centerings):
                        centering = tuple(centerings[index - 1])
                break
            except Exception as exc:  # try the next explicitly listed source
                errors.append(f"{candidate}: {type(exc).__name__}: {exc}")

        if source_image is None:
            raise RuntimeError(
                f"Could not download {item['name']} from any source:\n"
                + "\n".join(errors)
            )

        source_width, source_height = source_image.size
        prepared = prepare_image(
            source_image,
            WIDTH,
            HEIGHT,
            centering,
            item["contrast"],
            item["brightness"],
            item["sharpen"],
        )

        output_path = output_dir / item["filename"]
        prepared.save(output_path, format="PNG", optimize=True)

        manifest["images"].append(
            {
                "name": item["name"].replace("_", " "),
                "file": item["filename"],
                "source_dimensions": f"{source_width}x{source_height}",
                "output_dimensions": f"{WIDTH}x{HEIGHT}",
                "download_bytes": source_bytes,
                "actual_source_url": source_url,
                "source_note": item["source_note"],
                "fallback_used": source_url != item["url"],
                "processing": {
                    "centering": centering,
                    "contrast": item["contrast"],
                    "brightness": item["brightness"],
                    "sharpen_percent": item["sharpen"],
                },
            }
        )
        print(
            f"Created {output_path} from {source_width}x{source_height} "
            f"({source_bytes:,} bytes)"
        )

    (output_dir / "SOURCE_AND_PROCESSING_NOTES.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (output_dir / "README.txt").write_text(
        "KINDLE SCREENSAVERS — RAV ZVI KUSHELEVSKY & RAV OSHER ARIELI\n"
        f"Image size: {WIDTH} x {HEIGHT} pixels\n"
        "Format: PNG, 8-bit grayscale\n\n"
        "Both photos have been cropped for a portrait Kindle display, "
        "with modest e-ink contrast and brightness adjustments and "
        "restrained sharpening to retain facial detail.\n\n"
        "See SOURCE_AND_PROCESSING_NOTES.json for the exact image sources, "
        "original dimensions and processing settings.\n",
        encoding="utf-8",
    )
    print(f"Finished. Output directory: {output_dir.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
