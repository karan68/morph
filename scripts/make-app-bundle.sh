#!/bin/bash
# Assembles, signs (ad-hoc, inside-out, hardened runtime) and packages Morph.app into a DMG (spec §8.2).
# usage: make-app-bundle.sh <swift-build-bin-dir> <vendor-out> <version> <build-number> <dist-dir>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN=$1; VENDOR=$2; VERSION=$3; BUILD=$4; DIST=$5
APP="$DIST/Morph.app"
rm -rf "$DIST"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Frameworks" "$APP/Contents/Resources"

sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
cp "$BIN/MorphApp" "$APP/Contents/MacOS/Morph"
cp "$VENDOR"/Helpers/* "$APP/Contents/Helpers/"
cp "$VENDOR"/Frameworks/*.dylib "$APP/Contents/Frameworks/"
cp -R "$ROOT/Resources/icons" "$APP/Contents/Resources/icons"
cp "$ROOT/Resources/logo-menubar.png" "$ROOT/Resources/logo.png" "$APP/Contents/Resources/"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/FFmpeg"
cp "$VENDOR/CONFIGURE.txt" "$APP/Contents/Resources/FFmpeg/CONFIGURE.txt"
# Real license files, copied from the pinned source tarballs (not retyped).
python3 - "$VENDOR/sources" "$APP/Contents/Resources/Licenses" <<'EOF'
import os, re, sys, tarfile
src, out = sys.argv[1], sys.argv[2]
pat = re.compile(r"^[^/]+/(COPYING[^/]*|LICENSE[^/]*|LICENCE[^/]*|COPYRIGHT[^/]*)$", re.I)
for name in sorted(os.listdir(src)):
    with tarfile.open(os.path.join(src, name)) as t:
        for m in t.getmembers():
            if m.isfile() and pat.match(m.name):
                d = os.path.join(out, name.split(".tar")[0]); os.makedirs(d, exist_ok=True)
                open(os.path.join(d, os.path.basename(m.name)), "wb").write(t.extractfile(m).read())
print("licenses:", sorted(os.listdir(out)))
EOF
iconutil -c icns "$ROOT/Resources/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

# The app binary must find nothing outside the bundle and the OS.
if otool -L "$APP/Contents/MacOS/Morph" | awk 'NR>1{print $1}' | grep -v -E "^(/usr/lib/|/System/)"; then
  echo "ERROR: app links non-system libraries" >&2; exit 1
fi

# Sign inside-out: dylibs → helpers → app (spec §8.2 note).
SIGN=(codesign --force --sign - --timestamp=none)
"${SIGN[@]}" "$APP"/Contents/Frameworks/*.dylib
"${SIGN[@]}" --options runtime --entitlements "$ROOT/Resources/Helper.entitlements" "$APP"/Contents/Helpers/*
"${SIGN[@]}" --options runtime --entitlements "$ROOT/Resources/Morph.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "apple-events" || { echo "ERROR: entitlements missing" >&2; exit 1; }

# DMG with an Applications shortcut and install notes.
STAGE="$DIST/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/INSTALL.md" "$STAGE/READ ME FIRST.md"
hdiutil create -volname "Morph $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DIST/Morph-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"
( cd "$DIST" && shasum -a 256 "Morph-$VERSION.dmg" > "Morph-$VERSION.dmg.sha256" )
du -sh "$APP" "$DIST/Morph-$VERSION.dmg"
cat "$DIST/Morph-$VERSION.dmg.sha256"
