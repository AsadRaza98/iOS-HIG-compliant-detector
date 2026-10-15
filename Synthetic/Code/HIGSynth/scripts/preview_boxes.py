#!/usr/bin/env python3
"""Draw the generated boxes on a few screenshots so you can check the labels by eye.

    python3 -m pip install pillow        # once
    python3 scripts/preview_boxes.py [DATASET=~/HIGSynthDataset] [-n 12]

Writes annotated copies to <dataset>/preview/ and opens the folder.
"""
import argparse
import json
import random
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is missing. Install it with:  python3 -m pip install pillow")

COLORS = {
    "navBar": (52, 120, 246),
    "tabBar": (175, 82, 222),
    "button": (255, 59, 48),
    "textField": (52, 199, 89),
    "toggle": (255, 149, 0),
    "listRow": (142, 142, 147),
    "segmentedControl": (0, 199, 190),
    "searchField": (255, 204, 0),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", nargs="?", default=str(Path.home() / "HIGSynthDataset"))
    parser.add_argument("-n", type=int, default=12, help="number of images to preview")
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    root = Path(args.dataset).expanduser()
    label_files = sorted((root / "labels").glob("*.json"))
    if not label_files:
        sys.exit(f"No label files found in {root / 'labels'}")

    out = root / "preview"
    out.mkdir(exist_ok=True)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22)
    except OSError:
        font = ImageFont.load_default()

    for label_file in random.sample(label_files, min(args.n, len(label_files))):
        entry = json.loads(label_file.read_text())
        image = Image.open(root / "images" / entry["image"]).convert("RGB")
        draw = ImageDraw.Draw(image)
        for ann in entry["annotations"]:
            c = ann["coordinates"]
            x0, y0 = c["x"] - c["width"] / 2, c["y"] - c["height"] / 2
            x1, y1 = x0 + c["width"], y0 + c["height"]
            color = COLORS.get(ann["label"], (255, 0, 255))
            draw.rectangle([x0, y0, x1, y1], outline=color, width=3)
            draw.text((x0 + 4, y0 + 2), ann["label"], fill=color, font=font)
        image.save(out / entry["image"])

    print(f"Previews written to {out}")
    if not args.no_open and sys.platform == "darwin":
        subprocess.run(["open", str(out)], check=False)


if __name__ == "__main__":
    main()
