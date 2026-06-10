#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$ROOT_DIR/CodexQuotaBar"
BUILD_DIR="$ROOT_DIR/work/build/CodexQuotaBar"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/CodexQuotaBar.app"
EXECUTABLE_NAME="CodexQuotaBar"
MIN_MACOS_VERSION="13.0"

DEVELOPER_DIR_PATH="$(xcode-select -p)"
if [[ "$DEVELOPER_DIR_PATH" == "/Library/Developer/CommandLineTools" ]]; then
    cat >&2 <<'EOF'
SwiftUI MenuBarExtra builds require full Xcode on this machine.
The Command Line Tools swiftc hangs while compiling even a minimal SwiftUI menu bar app.

Install Xcode, then run:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
EOF
    exit 1
fi

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SOURCE_FILES=("$PROJECT_DIR"/Sources/CodexQuotaBar/*.swift)

build_arch() {
    local arch="$1"
    local arch_dir="$BUILD_DIR/$arch"
    mkdir -p "$arch_dir"

    xcrun swiftc \
        -Onone \
        -parse-as-library \
        -target "$arch-apple-macos$MIN_MACOS_VERSION" \
        -sdk "$SDK_PATH" \
        "${SOURCE_FILES[@]}" \
        -o "$arch_dir/$EXECUTABLE_NAME"
}

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

build_arch arm64
build_arch x86_64

lipo -create \
    "$BUILD_DIR/arm64/$EXECUTABLE_NAME" \
    "$BUILD_DIR/x86_64/$EXECUTABLE_NAME" \
    -output "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
for resource in "$PROJECT_DIR"/Resources/*; do
    [[ "$(basename "$resource")" == "Info.plist" ]] && continue
    [[ "$(basename "$resource")" == "AppIcon.png" ]] && continue
    cp "$resource" "$APP_DIR/Contents/Resources/"
done
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
