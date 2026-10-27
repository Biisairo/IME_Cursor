#!/bin/zsh
# CLT 환경에서는 Swift Testing 매크로 플러그인 경로를 직접 지정해야 한다.
set -e
cd "${0:A:h}/.."
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing "$@"
