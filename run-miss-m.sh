#!/bin/bash
# ♛ Miss M — Build & Run
# Double-click this or run: ./run-miss-m.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_DEST="$HOME/Applications/Miss M.app"
DESKTOP_DEST="$HOME/Desktop/Miss M.app"

echo "♛ Building Miss M..."

xcodebuild -project MissM.xcodeproj \
    -scheme MissM \
    -configuration Debug \
    -derivedDataPath build \
    build 2>&1 | tail -3

BUILD_APP="build/Build/Products/Debug/MissM.app"

if [ -d "$BUILD_APP" ]; then
    # Kill existing
    pkill -f "Miss M.app/Contents/MacOS/MissM" 2>/dev/null || true
    pkill -f "MissM.app/Contents/MacOS/MissM" 2>/dev/null || true
    sleep 1

    # Deploy to fixed locations (preserves macOS permission grants)
    rm -rf "$APP_DEST" "$DESKTOP_DEST"
    cp -R "$BUILD_APP" "$APP_DEST"
    cp -R "$BUILD_APP" "$DESKTOP_DEST"

    echo ""
    echo "♛ Launching Miss M..."
    open "$APP_DEST"
else
    echo "Build failed."
    exit 1
fi
