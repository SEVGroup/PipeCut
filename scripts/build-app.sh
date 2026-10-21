#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swift test --disable-sandbox
swift build --disable-sandbox -c release
APP="$PWD/dist/PipeCut.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PipeCut "$APP/Contents/MacOS/PipeCut"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>PipeCut</string><key>CFBundleIdentifier</key><string>group.sev.pipecut</string><key>CFBundleName</key><string>PipeCut</string><key>CFBundleShortVersionString</key><string>0.1</string><key>CFBundleVersion</key><string>1</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" dist/PipeCut-0.1-macOS.zip
