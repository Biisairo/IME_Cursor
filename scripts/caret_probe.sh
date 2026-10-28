#!/bin/zsh
# 앱별 캐럿 좌표 측정 프로브를 빌드하고 실행한다. 종료는 Ctrl+C.
set -e
cd "${0:A:h}/.."
mkdir -p build/caret_probe
swiftc -O scripts/caret_probe/main.swift -o build/caret_probe/caret_probe
exec build/caret_probe/caret_probe "$@"
