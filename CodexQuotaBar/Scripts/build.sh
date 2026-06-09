#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$ROOT_DIR/CodexQuotaBar"
BUILD_DIR="$ROOT_DIR/work/build/CodexQuotaBar"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/CodexQuotaBar.app"
EXECUTABLE_NAME="CodexQuotaBar"
MIN_MACOS_VERSION="13.0"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SOURCE_FILES=("$PROJECT_DIR"/Sources/CodexQuotaBar/*.m)

build_arch() {
    local arch="$1"
    local arch_dir="$BUILD_DIR/$arch"
    mkdir -p "$arch_dir"

    xcrun clang \
        -fobjc-arc \
        -fblocks \
        -mmacosx-version-min="$MIN_MACOS_VERSION" \
        -isysroot "$SDK_PATH" \
        -arch "$arch" \
        "${SOURCE_FILES[@]}" \
        -framework Cocoa \
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
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

codesign --force --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
