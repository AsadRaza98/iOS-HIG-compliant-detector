#!/usr/bin/env python3
"""Convert the Create ML folders (made by merge_annotations.py) into a YOLO dataset + zip.

    python3 scripts/make_yolo_dataset.py [DATASET=~/HIGSynthDataset]

Creates:
    <dataset>/yolo/images/{train,val,test}/*.png
    <dataset>/yolo/labels/{train,val,test}/*.txt     (class cx cy w h, normalised 0-1)
    <dataset>/yolo/data.yaml
    <dataset>/higsynth_yolo.zip                       (upload this to Google Drive for Colab)
"""
import json
import os
import shutil
import struct
import sys
import zipfile
from pathlib import Path

# Fixed order: the class index is what the model outputs, so never reorder this list.
CLASSES = ["navBar", "tabBar", "button", "textField", "toggle", "listRow", "segmentedControl", "searchField"]
SPLITS = {"train": "train", "validation": "val", "test": "test"}


def png_size(path: Path):
    with open(path, "rb") as f:
        header = f.read(24)
    return struct.unpack(">II", header[16:24])


def link_or_copy(src: Path, dst: Path):
    if dst.exists():
        return
    try:
        os.link(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "~/HIGSynthDataset").expanduser()
    createml = root / "createml"
    out = root / "yolo"
    if not createml.exists():
        sys.exit(f"{createml} not found. Run scripts/merge_annotations.py first.")

    totals = {}
    for src_split, dst_split in SPLITS.items():
        entries = json.loads((createml / src_split / "annotations.json").read_text())
        img_dir = out / "images" / dst_split
        lbl_dir = out / "labels" / dst_split
        img_dir.mkdir(parents=True, exist_ok=True)
        lbl_dir.mkdir(parents=True, exist_ok=True)
        boxes = 0
        for entry in entries:
            image = createml / src_split / entry["image"]
            width, height = png_size(image)
            lines = []
            for ann in entry["annotations"]:
                c = ann["coordinates"]
                lines.append(
                    f'{CLASSES.index(ann["label"])} '
                    f'{c["x"] / width:.6f} {c["y"] / height:.6f} '
                    f'{c["width"] / width:.6f} {c["height"] / height:.6f}'
                )
            link_or_copy(image, img_dir / entry["image"])
            (lbl_dir / (Path(entry["image"]).stem + ".txt")).write_text("\n".join(lines) + "\n")
            boxes += len(lines)
        totals[dst_split] = (len(entries), boxes)

    # No "path:" key, so Ultralytics resolves these relative to the yaml file's folder.
    yaml = ["train: images/train", "val: images/val", "test: images/test", "names:"]
    yaml += [f"  {i}: {name}" for i, name in enumerate(CLASSES)]
    (out / "data.yaml").write_text("\n".join(yaml) + "\n")

    zip_path = root / "higsynth_yolo.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_STORED) as z:  # PNGs are already compressed
        for path in sorted(out.rglob("*")):
            if path.is_file():
                z.write(path, Path("higsynth_yolo") / path.relative_to(out))

    for split, (images, boxes) in totals.items():
        print(f"{split:>5}: {images:5} images, {boxes:6} boxes")
    print(f"Zip: {zip_path}  ({zip_path.stat().st_size / 1e6:.0f} MB)")


if __name__ == "__main__":
    main()
