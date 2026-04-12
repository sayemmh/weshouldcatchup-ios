#!/usr/bin/env bash
#
# upload-testflight.sh — Archive + upload the iOS app to App Store Connect.
#
# Requires:
#   ~/.appstoreconnect/credentials.env     (exports ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)
#   ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
#
# Usage:
#   ./scripts/upload-testflight.sh          # archive + export + upload
#   ./scripts/upload-testflight.sh --dry    # archive + export, skip upload
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
IPA_PATH="$EXPORT_PATH/$SCHEME.ipa"

DRY_RUN=0
if [[ "${1:-}" == "--dry" ]]; then
    DRY_RUN=1
fi

# --- Load credentials ---
CREDS="$HOME/.appstoreconnect/credentials.env"
if [[ ! -f "$CREDS" ]]; then
    echo "❌ Missing $CREDS" >&2
    echo "   Create it with:" >&2
    echo "     export ASC_KEY_ID=\"<key id>\"" >&2
    echo "     export ASC_ISSUER_ID=\"<issuer uuid>\"" >&2
    echo "     export ASC_KEY_PATH=\"\$HOME/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8\"" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CREDS"

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
    if [[ -z "${!var:-}" ]]; then
        echo "❌ $var not set in $CREDS" >&2
        exit 1
    fi
done

if [[ ! -f "$ASC_KEY_PATH" ]]; then
    echo "❌ API key not found at $ASC_KEY_PATH" >&2
    exit 1
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
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    clean archive | xcbeautify 2>/dev/null || xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    clean archive

echo "📤 Exporting IPA…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"

if [[ ! -f "$IPA_PATH" ]]; then
    # Some Xcode versions name it differently; find it
    IPA_PATH="$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -1)"
fi

if [[ ! -f "$IPA_PATH" ]]; then
    echo "❌ IPA not produced" >&2
    exit 1
fi

echo "✅ IPA ready: $IPA_PATH"

if [[ $DRY_RUN -eq 1 ]]; then
    echo "(--dry passed; skipping upload)"
    exit 0
fi

echo "☁️  Uploading to App Store Connect…"
xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo "✅ Upload complete. Check TestFlight in ~5–15 min for the processed build."
