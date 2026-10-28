#!/bin/zsh
# 앱을 빌드해서 zip으로 묶고, 현재 커밋에 GitHub 릴리즈를 만든다(FR-REL).
set -e
cd "${0:A:h}/.."
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" scripts/Info.plist)
tag="v$version"
notes="docs/releases/$tag.md"
zip="build/ImeCursor-$version.zip"

fail() {
  echo "중단: $1" >&2
  exit 1
}

[[ -z $(git status --porcelain) ]] || fail "커밋하지 않은 변경이 있다"
git fetch --quiet origin main --tags
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || fail "현재 커밋이 origin/main과 다르다"
[[ -z $(git ls-remote --tags origin "refs/tags/$tag") ]] || fail "원격에 $tag 태그가 이미 있다"
[[ -f $notes ]] || fail "릴리즈 노트 $notes 가 없다"
./scripts/test.sh > /dev/null || fail "테스트가 실패했다"

./scripts/build_app.sh
rm -f "$zip"
ditto -c -k --keepParent build/ImeCursor.app "$zip"
gh release create "$tag" "$zip" --target "$(git rev-parse HEAD)" --title "ImeCursor $version" --notes-file "$notes"
