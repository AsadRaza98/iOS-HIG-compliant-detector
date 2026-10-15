# VINS approach: code

This approach trains a YOLO detector on the public [VINS dataset](https://github.com/sbunian/VINS): about 1,200 real, hand-labelled iOS screenshots. An iPhone app then uses the detector to check screenshots against Apple's Human Interface Guidelines.

## Folders

| Path | What it is |
|---|---|
| `OddessyCH1/` | The iPhone app (Xcode project) |
| `OddessyCH1/OddessyCH1/HIGElementDetector.mlpackage` | The trained detector (YOLO11s, exported to Core ML) |
| `scripts/vins_to_createml.py` | Converts VINS Pascal VOC XML labels to Create ML JSON and splits them into train, val and test sets |
| `scripts/createml_to_yolo.py` | Packages those splits as a YOLO dataset zip for training |
| `../HIG_YOLO_Training-2.ipynb` | Colab notebook that trains the model and exports it to Core ML |

## Detected classes

The detector finds 10 classes: `Text`, `Icon`, `Image`, `TextButton`, `EditText`, `Switch`, `UpperTaskBar`, `PageIndicator`, `CheckedTextView` and `BackgroundImage`.

## HIG checks in the app

- **Safe areas:** controls must not sit under the status bar or Dynamic Island, or on the home indicator.
- **Tap targets:** at least 44 × 44 pt.
- **Text size:** at least 11 pt.
- **Text contrast:** at least 4.5:1, or 3:1 for large text.

## Reproducing

1. Download the iPhone part of VINS into `iphone/`, with an `Annotations/` folder and a `JPEGImages/` folder.
2. Convert the labels and build the YOLO zip:
   ```
   python3 scripts/vins_to_createml.py --src iphone --out VINS_CreateML
   python3 scripts/createml_to_yolo.py --src VINS_CreateML --out VINS_YOLO.zip
   ```
3. Upload `VINS_YOLO.zip` to Google Drive and run the notebook.
4. Open `OddessyCH1/OddessyCH1.xcodeproj` and run the app.

The dataset itself isn't included in this repo. Download it from the VINS repository.
