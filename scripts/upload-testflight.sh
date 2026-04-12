#!/usr/bin/env bash
#
# upload-testflight.sh — Archive + upload the iOS app to App Store Connect.
#
# Uses Xcode's stored Apple ID session for signing and uploading.
# Make sure you're signed into an Apple Developer account in
# Xcode → Settings → Accounts before running.
#
# Usage:
#   ./scripts/upload-testflight.sh          # archive + upload
#   ./scripts/upload-testflight.sh --dry    # archive only, skip upload
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SCHEME="WeShouldCatchUp"
PROJECT="WeShouldCatchUp.xcodeproj"
CONFIG="Release"
BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$REPO_ROOT/scripts/ExportOptions.plist"

DRY_RUN=0
EXPORT_ONLY_PLIST=""
if [[ "${1:-}" == "--dry" ]]; then
    DRY_RUN=1
    EXPORT_ONLY_PLIST=$(mktemp)
    # For dry-run, override destination to export (no upload)
    sed 's|<string>upload</string>|<string>export</string>|' "$EXPORT_OPTIONS" > "$EXPORT_ONLY_PLIST"
fi

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "📦 Archiving $SCHEME ($CONFIG)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive

echo "📤 Exporting and uploading…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "${EXPORT_ONLY_PLIST:-$EXPORT_OPTIONS}" \
    -allowProvisioningUpdates

if [[ $DRY_RUN -eq 1 ]]; then
    rm -f "$EXPORT_ONLY_PLIST"
    echo "✅ Archive + export done (--dry, skipped upload)."
    echo "   IPA: $(find "$EXPORT_PATH" -name '*.ipa' | head -1)"
else
    echo "✅ Upload complete. Check TestFlight in ~5–15 min."
fi
