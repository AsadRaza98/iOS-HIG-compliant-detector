# HIGSynth: synthetic, auto-labelled iOS screenshots

HIGSynth builds random but realistic iOS screens out of native SwiftUI components. A UI test captures each screen and reads every element's position from the accessibility tree, so each screenshot comes with exact bounding boxes and nobody has to label anything by hand.

The output is in **Create ML Object Detection** format.

## Classes (v1)

`navBar` · `tabBar` · `button` · `textField` · `toggle` · `listRow` · `segmentedControl` · `searchField`

## Requirements

- Xcode 16 or newer (the project uses folder-synced groups)
- At least one iPhone simulator runtime installed
- Python 3, which comes with Xcode's command line tools
- Pillow, only for the preview script: `python3 -m pip install pillow`

## 1. Look at what it generates

Open `HIGSynth.xcodeproj`, pick an iPhone simulator and press **Run**. Every launch shows a new random screen. The seed is printed in the console.

Some tips:

- To reproduce a screen, add `-seed 42` under *Edit Scheme > Run > Arguments*.
- Press **⌘U** to run the generator test from Xcode. It makes 50 screenshots in `~/HIGSynthDataset`.

## 2. Generate a dataset (Terminal)

```bash
cd ~/Documents/HIGSynth
chmod +x scripts/generate.sh
scripts/generate.sh 300            # quick test run: 300 screenshots on 3 simulators
scripts/generate.sh 3000 0 4       # MVP-sized: 3000 screenshots on 4 simulators
```

The script picks iPhone simulators with different screen sizes and builds the project once. It then runs the simulators in parallel, with each one working through its own range of seeds.

Re-running is safe because seeds that are already done are skipped. To add more images later, start from a new seed, for example `scripts/generate.sh 2000 3000`.

Output:

```
~/HIGSynthDataset/
  images/synth_00000042.png
  labels/synth_00000042.json   # Create ML entry + metadata (seed, device, text size…)
```

## 3. Check the labels

```bash
python3 scripts/preview_boxes.py          # draws boxes on 12 random images and opens the folder
```

Always do this after you change the generator. Wrong boxes produce a bad model.

## 4. Build Create ML folders

```bash
python3 scripts/merge_annotations.py      # → ~/HIGSynthDataset/createml/{train,validation,test}
```

It also prints how many boxes each class has. Aim for **300+ training boxes per class**.

Then open **Create ML**, choose **Object Detection**, set *Training Data* to `train`, *Validation* to `validation` and *Testing* to `test`, and click **Train**.

## Variety built in

| Variable | How |
|---|---|
| Layout | 4 archetypes: settings form, content list, scroll content, sign-in |
| Light / dark | 45% dark |
| Tint & custom colors | 15-color palette, custom-styled buttons and fields |
| Dynamic Type | S → Accessibility M, weighted toward Large |
| Right-to-left | 8% of screens |
| Device | different simulators per worker |
| Bars | large/inline titles, search bars, 2–5 tab bars, bottom action buttons |

## Customizing

- **More variety:** add words and symbols in `Words.swift`, and change probabilities in `Generator.swift`.
- **New element class:**
  1. Add the component to `SynthViews.swift`.
  2. Map its accessibility element type in `collect(...)` inside `DatasetGeneratorTests.swift`.
  3. Add a color in `preview_boxes.py`.
- **Image size:** images are downscaled so the long side is at most 1600 px. Set `HIGSYNTH_MAX_DIM=0` to keep full resolution.

## Known limits

- iPhone portrait only. iPad layouts are different enough to need their own pass.
- Synthetic screens are "too clean". Mix in a few hundred hand-labelled real screenshots, in the same Create ML JSON format, before training a production model.
- Buttons placed in navigation bars and toolbars aren't generated yet, so the model won't learn them as `button`.
