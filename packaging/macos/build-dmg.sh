#!/bin/sh
# Builds a drag-to-Applications DMG around resources/macos-app.
# usage: build-dmg.sh <darwin-amd64-binary> <darwin-arm64-binary> <out.dmg>
# Set VERSION to stamp the bundle (e.g. VERSION=1.2.0).
set -eu

amd64=$1
arm64=$2
out=$3
repo=$(cd "$(dirname "$0")/../.." && pwd)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
app="$stage/Pass Picker.app"

cp -R "$repo/resources/macos-app" "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
rm -f "$app/Contents/MacOS/.gitkeep"
lipo -create -output "$app/Contents/MacOS/passpicker" "$amd64" "$arm64"
chmod +x "$app/Contents/MacOS/passpicker"

if [ -n "${VERSION:-}" ]; then
	plutil -replace CFBundleShortVersionString -string "$VERSION" "$app/Contents/Info.plist"
fi

# Compile native macmenu helper
macmenu_amd64=$(mktemp)
macmenu_arm64=$(mktemp)
swiftc -O -target x86_64-apple-macos11.0 "$repo/cmd/macmenu/main.swift" -o "$macmenu_amd64"
swiftc -O -target arm64-apple-macos11.0 "$repo/cmd/macmenu/main.swift" -o "$macmenu_arm64"
lipo -create -output "$app/Contents/Resources/macmenu" "$macmenu_amd64" "$macmenu_arm64"
rm -f "$macmenu_amd64" "$macmenu_arm64"
chmod +x "$app/Contents/Resources/macmenu"

# lipo output carries no signature and macOS refuses unsigned arm64 binaries.
codesign --force --sign - "$app/Contents/Resources/macmenu"
codesign --force --sign - "$app/Contents/MacOS/passpicker"
codesign --force --sign - "$app"

ln -s /Applications "$stage/Applications"

# makehybrid, unlike `create -srcfolder`, needs no privilege to attach the image.
raw="$stage.raw.dmg"
rm -f "$raw" "$out"
hdiutil makehybrid -hfs -hfs-volume-name "Pass Picker" -o "$raw" "$stage" -quiet
hdiutil convert "$raw" -format UDZO -o "$out" -quiet
rm -f "$raw"
echo "$out"
