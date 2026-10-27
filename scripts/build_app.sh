#!/bin/zsh
# release 빌드 후 build/ImeCursor.app 번들을 만들고 ad-hoc 서명한다.
set -e
cd "${0:A:h}/.."
swift build -c release
app=build/ImeCursor.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/ImeCursor "$app/Contents/MacOS/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
cp scripts/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
echo "$app"
