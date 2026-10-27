#!/bin/zsh
# IconArtwork.swift로 Resources/AppIcon.icns를 만든다. 미리보기 PNG는 build/icon-preview에 둔다.
set -e
cd "${0:A:h}/.."
work=build/icon
rm -rf "$work"
mkdir -p "$work" Resources
swiftc -O Sources/ImeCursor/IconArtwork.swift scripts/make_icon/main.swift -o "$work/make_icon"
"$work/make_icon" "$work/AppIcon.iconset" build/icon-preview
iconutil -c icns "$work/AppIcon.iconset" -o Resources/AppIcon.icns
echo Resources/AppIcon.icns
