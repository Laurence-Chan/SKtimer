#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SKtimer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/SKtimer.xcodeproj"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_DIR="$DIST_DIR/archives"
ARCHIVE_PATH="$ARCHIVE_DIR/$APP_NAME.xcarchive"
APP_STORE_EXPORT="$DIST_DIR/app-store"
DEVELOPER_EXPORT="$DIST_DIR/developer-id"
DEVELOPER_APP="$DEVELOPER_EXPORT/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.app.zip"
PKG_PATH="$DIST_DIR/$APP_NAME.pkg"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"
INSTALLER_IDENTITY="${DEVELOPER_ID_INSTALLER:-}"

rm -rf "$DIST_DIR"
mkdir -p "$ARCHIVE_DIR" "$APP_STORE_EXPORT" "$DEVELOPER_EXPORT"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$ROOT_DIR/Packaging/ExportOptions-AppStore.plist" \
  -exportPath "$APP_STORE_EXPORT"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$ROOT_DIR/Packaging/ExportOptions-DeveloperID.plist" \
  -exportPath "$DEVELOPER_EXPORT"

if [[ ! -d "$DEVELOPER_APP" ]]; then
  echo "Developer ID export did not produce $DEVELOPER_APP" >&2
  exit 1
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  TEMP_ZIP="$DIST_DIR/$APP_NAME.notary.zip"
  ditto -c -k --keepParent "$DEVELOPER_APP" "$TEMP_ZIP"
  xcrun notarytool submit "$TEMP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DEVELOPER_APP"
  rm -f "$TEMP_ZIP"
else
  echo "NOTARYTOOL_PROFILE is not set; skipping app notarization." >&2
fi

ditto -c -k --keepParent "$DEVELOPER_APP" "$ZIP_PATH"

if [[ -n "$INSTALLER_IDENTITY" ]]; then
  productbuild --component "$DEVELOPER_APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG_PATH"
else
  echo "DEVELOPER_ID_INSTALLER is not set; creating an unsigned pkg for local validation only." >&2
  productbuild --component "$DEVELOPER_APP" /Applications "$PKG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG_PATH"
fi

shasum -a 256 "$ZIP_PATH" "$PKG_PATH" > "$DIST_DIR/SHA256SUMS.txt"

cat <<EOF
Release artifacts are ready:
- $ARCHIVE_PATH
- $APP_STORE_EXPORT
- $ZIP_PATH
- $PKG_PATH
- $DIST_DIR/SHA256SUMS.txt
EOF
