#!/usr/bin/env python3
"""Turn the per-image label files into Create ML object-detection folders.

    python3 scripts/merge_annotations.py [DATASET=~/HIGSynthDataset] [--out DIR] [--val 0.1] [--test 0.1]

Creates  <out>/train, <out>/validation, <out>/test  each holding the images plus an
annotations.json in Create ML's format. Drag the train folder into Create ML's
Object Detection template as Training Data, and validation/test as the other two.

The split is decided by a hash of the file name, so re-running after generating
more images never moves an existing image to a different split.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
from collections import Counter
from pathlib import Path

SPLITS = ("train", "validation", "test")


def split_for(name: str, val: float, test: float) -> str:
    bucket = int(hashlib.sha1(name.encode()).hexdigest(), 16) % 10_000 / 10_000
    if bucket < test:
        return "test"
    if bucket < test + val:
        return "validation"
    return "train"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dataset", nargs="?", default=str(Path.home() / "HIGSynthDataset"))
    parser.add_argument("--out", help="output folder (default: <dataset>/createml)")
    parser.add_argument("--val", type=float, default=0.1, help="validation fraction")
    parser.add_argument("--test", type=float, default=0.1, help="test fraction")
    parser.add_argument("--min-boxes", type=int, default=1, help="skip images with fewer boxes")
    parser.add_argument("--copy", action="store_true", help="copy images instead of hard-linking")
    args = parser.parse_args()

    root = Path(args.dataset).expanduser()
    label_files = sorted((root / "labels").glob("*.json"))
    if not label_files:
        sys.exit(f"No label files found in {root / 'labels'}")

    out = Path(args.out).expanduser() if args.out else root / "createml"
    entries = {s: [] for s in SPLITS}
    counts = {s: Counter() for s in SPLITS}
    skipped = 0

    for label_file in label_files:
        entry = json.loads(label_file.read_text())
        image = root / "images" / entry["image"]
        if not image.exists() or len(entry["annotations"]) < args.min_boxes:
            skipped += 1
            continue

        split = split_for(entry["image"], args.val, args.test)
        dest_dir = out / split
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / entry["image"]
        if not dest.exists():
            if args.copy:
                shutil.copy2(image, dest)
            else:
                try:
                    os.link(image, dest)
                except OSError:
                    shutil.copy2(image, dest)

        entries[split].append({"image": entry["image"], "annotations": entry["annotations"]})
        counts[split].update(a["label"] for a in entry["annotations"])

    for split in SPLITS:
        if entries[split]:
            (out / split / "annotations.json").write_text(json.dumps(entries[split], indent=1))

    labels = sorted(set().union(*counts.values()))
    print(f"Wrote Create ML folders to {out}  (skipped {skipped})\n")
    print(f"{'class':<18}" + "".join(f"{s:>12}" for s in SPLITS))
    for label in labels:
        print(f"{label:<18}" + "".join(f"{counts[s][label]:>12}" for s in SPLITS))
    print(f"{'images':<18}" + "".join(f"{len(entries[s]):>12}" for s in SPLITS))

    weakest = min(labels, key=lambda l: counts["train"][l]) if labels else None
    if weakest and counts["train"][weakest] < 300:
        print(f"\nTip: '{weakest}' has only {counts['train'][weakest]} training boxes. "
              "Aim for 300+ per class, generate more or raise its probability in Generator.swift.")


if __name__ == "__main__":
    main()
