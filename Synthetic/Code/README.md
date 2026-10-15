# Synthetic approach: code

VINS screenshots are from 2021 and predate the current iOS design. This approach therefore generates its own training data: a SwiftUI app builds random but realistic iOS screens, and a UI test labels every element automatically from the accessibility tree.

## Folders

| Path | What it is |
|---|---|
| `HIGSynth/` | Dataset generator: Xcode app + UI test + scripts (see its README) |
| `HIGSynth/scripts/generate.sh` | Generates labelled screenshots on several simulators in parallel |
| `HIGSynth/scripts/preview_boxes.py` | Draws the labels on sample screenshots so you can check them |
| `HIGSynth/scripts/merge_annotations.py` | Builds Create ML train, validation and test folders |
| `HIGSynth/scripts/make_yolo_dataset.py` | Converts those folders to a YOLO dataset zip |
| `../HIGSynth_YOLO_Training.ipynb` | Colab notebook that trains YOLO11s and exports it to Core ML |
| `HIGCheck/` | The iPhone app that checks screenshots against the HIG |
| `HIGCheck/HIGCheck/HIGDetector.mlpackage` | The trained detector |

## Detected classes

The generator labels 8 classes: `navBar`, `tabBar`, `button`, `textField`, `toggle`, `listRow`, `segmentedControl` and `searchField`.

The app currently uses the four classes that work best on real screenshots: buttons, list rows, switches and the tab bar.

## HIG checks in the app

| Element | Checks |
|---|---|
| Buttons | Tap target of at least 44 × 44 pt; label contrast of at least 4.5:1; at least 8 pt between neighbouring buttons |
| List rows | At least 44 pt tall; same margin on both sides |
| Switches | Standard system size; at the trailing edge of the row; has a text label |
| Tab bar | At the bottom of the screen; no more than 5 tabs |

## Results

- **Synthetic test set:** 99.5% mAP50 on 310 held-out screens.
- **Real screenshots:** list rows, switches, tab bars and buttons are detected reliably. Bottom search bars, segmented controls in the nav bar and round icon buttons are still missed, because the generator doesn't produce them yet.

## Reproducing

1. Generate the dataset (about 1 hour on 4 simulators):
   ```
   cd HIGSynth
   scripts/generate.sh 3000 0 4
   python3 scripts/merge_annotations.py
   python3 scripts/make_yolo_dataset.py
   ```
2. Upload `~/HIGSynthDataset/higsynth_yolo.zip` to Google Drive and run the notebook.
3. Open `HIGCheck/HIGCheck.xcodeproj` and run the app.
