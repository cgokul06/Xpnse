#!/usr/bin/env bash
# Run priority number / amount formatting tests.
# Required before committing changes that touch formatting, transactions, or related UI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/src"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

echo "Running AmountFormatterTests + CompactNumberFormatterTests…"
echo "Destination: $DESTINATION"

xcodebuild test \
  -scheme SnapLedger-Debug \
  -destination "$DESTINATION" \
  -only-testing:XpnseTests/AmountFormatterTests \
  -only-testing:XpnseTests/CompactNumberFormatterTests \
  -quiet

echo "✅ Number formatting tests passed."
