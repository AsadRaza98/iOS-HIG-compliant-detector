#!/usr/bin/env bash
# Generate synthetic, auto-labelled screenshots on several iPhone simulators in parallel.
#
# Usage:  scripts/generate.sh [TOTAL=300] [START_SEED=0] [WORKERS=3]
# Env:    HIGSYNTH_OUTPUT (default ~/HIGSynthDataset), HIGSYNTH_MAX_DIM (default 1600)
#
# Safe to re-run: seeds that already have a label file are skipped.
set -euo pipefail

TOTAL="${1:-300}"
START_SEED="${2:-0}"
WORKERS="${3:-3}"
OUTPUT="${HIGSYNTH_OUTPUT:-$HOME/HIGSynthDataset}"
MAX_DIM="${HIGSYNTH_MAX_DIM:-1600}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build/DerivedData"
LOGS="$ROOT/build/logs"
mkdir -p "$OUTPUT" "$LOGS"

echo "==> Picking simulators"
DEVICE_LINES="$(xcrun simctl list devices available -j | python3 "$ROOT/scripts/pick_simulators.py" "$WORKERS")"
if [ -z "$DEVICE_LINES" ]; then
  echo "No iPhone simulators found. Add an iOS runtime in Xcode > Settings > Components." >&2
  exit 1
fi
printf '%s\n' "$DEVICE_LINES" | sed 's/^[^|]*|/    /'

echo "==> Building (once) for testing"
xcodebuild build-for-testing \
  -project "$ROOT/HIGSynth.xcodeproj" \
  -scheme HIGSynth \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" \
  -quiet

N=$(printf '%s\n' "$DEVICE_LINES" | grep -c '|')
PER=$(( (TOTAL + N - 1) / N ))
END=$(( START_SEED + TOTAL ))

PIDS=""
i=0
while IFS='|' read -r UDID NAME; do
  [ -z "$UDID" ] && continue
  START=$(( START_SEED + i * PER ))
  COUNT=$PER
  if [ $(( START + COUNT )) -gt "$END" ]; then COUNT=$(( END - START )); fi
  if [ "$COUNT" -le 0 ]; then break; fi

  echo "==> Worker $i on $NAME: seeds $START to $(( START + COUNT - 1 ))  (log: build/logs/worker-$i.log)"
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  rm -rf "$ROOT/build/results-$i.xcresult"

  TEST_RUNNER_HIGSYNTH_COUNT="$COUNT" \
  TEST_RUNNER_HIGSYNTH_START_SEED="$START" \
  TEST_RUNNER_HIGSYNTH_OUTPUT="$OUTPUT" \
  TEST_RUNNER_HIGSYNTH_MAX_DIM="$MAX_DIM" \
  xcodebuild test-without-building \
    -project "$ROOT/HIGSynth.xcodeproj" \
    -scheme HIGSynth \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -only-testing:HIGSynthUITests/DatasetGeneratorTests/testGenerateDataset \
    -resultBundlePath "$ROOT/build/results-$i.xcresult" \
    > "$LOGS/worker-$i.log" 2>&1 &
  PIDS="$PIDS $!"
  i=$(( i + 1 ))
done <<< "$DEVICE_LINES"

echo "==> Running $i worker(s). Roughly 2-4 seconds per screenshot per simulator."
FAILED=0
for pid in $PIDS; do
  wait "$pid" || FAILED=1
done

IMAGES=$(find "$OUTPUT/images" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
echo "==> Done. $IMAGES images in $OUTPUT/images"
if [ "$FAILED" -ne 0 ]; then
  echo "Some workers exited with errors. Check build/logs/ (search for 'HIGSynth:')." >&2
fi
echo "Next: python3 \"$ROOT/scripts/preview_boxes.py\" \"$OUTPUT\"   (check the boxes)"
echo "      python3 \"$ROOT/scripts/merge_annotations.py\" \"$OUTPUT\"   (build Create ML folders)"
