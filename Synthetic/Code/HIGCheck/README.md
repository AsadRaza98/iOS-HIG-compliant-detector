# HIG Check

HIG Check is an iPhone app. You pick a screenshot of any iOS app, it finds the **buttons, list rows, switches and tab bar**, and it checks each one against Apple's Human Interface Guidelines. All processing happens on the device.

## Setup (one time)

1. In Google Drive, download **`HIGSynth/HIGDetector.mlpackage.zip`** and unzip it.
2. Move **`HIGDetector.mlpackage`** into the inner **`HIGCheck`** folder, next to the `.swift` files. Xcode picks it up automatically.
3. Open `HIGCheck.xcodeproj`, choose an iPhone simulator or your iPhone, and press **Run**.
   - To run on a real iPhone, select your Apple ID under *Signing & Capabilities → Team*.

## Using it

Tap **Choose Screenshot** and pick a screenshot. The app then shows:

- a summary of failed, warning and passed checks;
- the screenshot with a coloured box on each element (red = failed, orange = warning, green = passed). Tap a box to see its checks;
- the issues, each with a link to the matching HIG page.

## Checks

| Element | Check | Rule |
|---|---|---|
| Button | Tap target | Visible size is at least 44 × 44 pt |
| Button | Label contrast | At least 4.5:1 (fails below 3:1) |
| Button | Spacing | At least 8 pt between neighbouring buttons |
| Row | Height | At least 44 pt |
| Row | Margins | Leading and trailing margins within 6 pt of each other |
| Switch | Size | Matches the system switch (not scaled or redrawn) |
| Switch | Alignment | At the trailing edge of its row |
| Switch | Label | Text next to it says what it controls |
| Tab bar | Position | At the bottom of the screen |
| Tab bar | Tab count | No more than 5 tabs; notes when tabs have no titles |

## Limits

- Measurements come from pixels, so they describe what's *visible*. A small visible button may still have a 44 pt tap area in code.
- The detector only shows elements it found with at least 60% confidence, and at most one tab bar per screen.
- iPhone screenshots only. The pixel-to-point scale is estimated from the image width: 828 px or less is @2x, anything wider is @3x.
- Thresholds are constants at the top of `HIGRules.swift`, so they're easy to adjust.
