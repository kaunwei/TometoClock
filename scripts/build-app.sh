#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
swift build -c release
binary=$(swift build -c release --show-bin-path)
app="$root/.build/TometoClock.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary/TometoClock" "$app/Contents/MacOS/TometoClock"
cp "$root/Assets/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TometoClock</string>
<key>CFBundleIdentifier</key><string>local.tometoclock</string>
<key>CFBundleName</key><string>TometoClock</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
printf '%s\n' "$app"
