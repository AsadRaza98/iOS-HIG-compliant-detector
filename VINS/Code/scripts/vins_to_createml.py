#!/usr/bin/env python3
"""Convert VINS (Pascal VOC XML) annotations to Create ML object-detection format.

Output layout (each folder can be dropped straight into Create ML):
    <out>/train/annotations.json + images
    <out>/val/annotations.json   + images
    <out>/test/annotations.json  + images

Create ML format: [{"image": "x.jpg", "annotations": [{"label": "Icon",
    "coordinates": {"x": cx, "y": cy, "width": w, "height": h}}]}]  (pixels, box centre)

Usage:
    python3 scripts/vins_to_createml.py --src iphone --out VINS_CreateML
"""
import argparse, json, random, shutil, sys
from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET

try:
    from PIL import Image
except ImportError:
    Image = None

# Fix inconsistent / near-duplicate labels in VINS.
LABEL_MAP = {
    "CheckBox": "CheckedTextView",
    "Checkbox": "CheckedTextView",
    "Remember": "CheckedTextView",   # "remember me" checkboxes
}


def parse(xml_path, img_dir, stats):
    root = ET.parse(xml_path).getroot()
    # Match by file stem: the <filename> tag in VINS XMLs is often stale/wrong.
    img_path = img_dir / (xml_path.stem + ".jpg")
    if not img_path.is_file():
        stats["missing_image"] += 1
        return None

    W = int(float(root.findtext("size/width") or 0))
    H = int(float(root.findtext("size/height") or 0))
    if Image is not None:                           # trust the real image size
        with Image.open(img_path) as im:
            rw, rh = im.size
        if (W, H) != (rw, rh):
            stats["size_mismatch"] += 1
        W, H = rw, rh

    anns = []
    for obj in root.iter("object"):
        label = (obj.findtext("name") or "").strip()
        label = LABEL_MAP.get(label, label)
        bb = obj.find("bndbox")
        if not label or bb is None:
            stats["bad_object"] += 1
            continue
        x1, y1, x2, y2 = (float(bb.findtext(k)) for k in ("xmin", "ymin", "xmax", "ymax"))
        # clip to image bounds
        x1, x2 = max(0, min(x1, x2)), min(W, max(x1, x2))
        y1, y2 = max(0, min(y1, y2)), min(H, max(y1, y2))
        w, h = x2 - x1, y2 - y1
        if w < 2 or h < 2:
            stats["degenerate_box"] += 1
            continue
        anns.append({"label": label, "coordinates": {
            "x": round(x1 + w / 2, 1), "y": round(y1 + h / 2, 1),
            "width": round(w, 1), "height": round(h, 1)}})

    if not anns:
        stats["no_annotations"] += 1
        return None
    return img_path, anns


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="iphone", help="folder with Annotations/ and JPEGImages/")
    ap.add_argument("--out", default="VINS_CreateML")
    ap.add_argument("--split", default="0.8,0.1,0.1", help="train,val,test fractions")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--drop", default="", help="comma-separated labels to exclude, e.g. Drawer,Modal")
    args = ap.parse_args()

    src, out = Path(args.src), Path(args.out)
    ann_dir, img_dir = src / "Annotations", src / "JPEGImages"
    drop = {s.strip() for s in args.drop.split(",") if s.strip()}
    if out.exists() and any(out.iterdir()):
        sys.exit(f"Output folder {out} is not empty; choose another --out.")

    stats = Counter()
    items = []
    for xml in sorted(ann_dir.glob("*.xml")):
        r = parse(xml, img_dir, stats)
        if r is None:
            continue
        img, anns = r
        if drop:
            stats["dropped_boxes"] += sum(a["label"] in drop for a in anns)
            anns = [a for a in anns if a["label"] not in drop]
            if not anns:
                stats["no_annotations"] += 1
                continue
        items.append((img, anns))

    fr = [float(f) for f in args.split.split(",")]
    random.Random(args.seed).shuffle(items)
    n = len(items)
    n_train, n_val = int(n * fr[0]), int(n * fr[1])
    splits = {"train": items[:n_train],
              "val": items[n_train:n_train + n_val],
              "test": items[n_train + n_val:]}

    labels = sorted({a["label"] for _, anns in items for a in anns})
    print(f"Images kept: {n}")
    print("Skipped / fixed:", dict(stats) or "none")
    header = f"{'class':<18}" + "".join(f"{s:>8}" for s in splits)
    print("\nBoxes per class\n" + header)
    counts = {s: Counter(a["label"] for _, anns in v for a in anns) for s, v in splits.items()}
    for lab in labels:
        print(f"{lab:<18}" + "".join(f"{counts[s][lab]:>8}" for s in splits))
    print(f"{'images':<18}" + "".join(f"{len(v):>8}" for v in splits.values()))

    for name, subset in splits.items():
        d = out / name
        d.mkdir(parents=True, exist_ok=True)
        for img, _ in subset:
            shutil.copy2(img, d / img.name)
        with open(d / "annotations.json", "w") as f:
            json.dump([{"image": img.name, "annotations": anns} for img, anns in subset], f)
    print(f"\nWrote {out}/{{train,val,test}}")


if __name__ == "__main__":
    main()
