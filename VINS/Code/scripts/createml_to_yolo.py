#!/usr/bin/env python3
"""Package a Create ML object-detection dataset (train/val/test folders, each with
annotations.json) as a YOLO dataset zip for Ultralytics / Google Colab.

Zip layout:
    VINS_YOLO/data.yaml
    VINS_YOLO/images/{train,val,test}/*.jpg
    VINS_YOLO/labels/{train,val,test}/*.txt   (class cx cy w h, normalised 0-1)

Usage:
    python3 scripts/createml_to_yolo.py --src VINS_CreateML --out VINS_YOLO.zip
"""
import argparse, json, zipfile
from pathlib import Path
from PIL import Image

SPLITS = ["train", "val", "test"]

ap = argparse.ArgumentParser()
ap.add_argument("--src", default="VINS_CreateML")
ap.add_argument("--out", default="VINS_YOLO.zip")
args = ap.parse_args()
src, out = Path(args.src), Path(args.out)
if out.exists():
    raise SystemExit(f"{out} already exists; choose another --out")

data = {s: json.load(open(src / s / "annotations.json")) for s in SPLITS}
classes = sorted({a["label"] for s in SPLITS for e in data[s] for a in e["annotations"]})
cid = {c: i for i, c in enumerate(classes)}

yaml = "path: VINS_YOLO\n" + "".join(f"{s}: images/{s}\n" for s in SPLITS)
yaml += "names:\n" + "".join(f"  {i}: {c}\n" for i, c in enumerate(classes))

n_img = n_box = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as z:   # JPEGs don't compress; store = fast
    z.writestr("VINS_YOLO/data.yaml", yaml)
    for s in SPLITS:
        for e in data[s]:
            img = src / s / e["image"]
            W, H = Image.open(img).size
            lines = []
            for a in e["annotations"]:
                c = a["coordinates"]
                lines.append(f'{cid[a["label"]]} {c["x"]/W:.6f} {c["y"]/H:.6f} {c["width"]/W:.6f} {c["height"]/H:.6f}')
            z.write(img, f"VINS_YOLO/images/{s}/{img.name}")
            z.writestr(f"VINS_YOLO/labels/{s}/{img.stem}.txt", "\n".join(lines) + "\n")
            n_img += 1; n_box += len(lines)

print(yaml)
print(f"Wrote {out}: {n_img} images, {n_box} boxes")
