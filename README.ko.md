# ImeCursor

[English](README.md) | [한국어](README.ko.md)

ImeCursor는 macOS 메뉴바 앱입니다. 현재 키보드 입력 소스를 마우스 포인터 옆에 작은 배지로 보여 줍니다.

두벌식과 ABC처럼 입력 소스를 바꾸면 배지도 바로 바뀝니다. 그래서 메뉴바를 보지 않고도, 타이핑하기 전에 지금 어떤 언어로 입력될지 알 수 있습니다.

## 기능

- **모든 입력 소스 지원.** 시스템에 켜져 있는 입력 소스를 모두 읽어 옵니다. 한국어, 영어, 일본어 등 입력 소스마다 다른 배지를 설정할 수 있습니다.
- **입력 소스별 스타일 설정.** 표시 글자, 글자 크기와 굵기, 글자 색, 배경 크기와 색, 모서리 둥글기, 포인터 기준 위치를 바꿀 수 있습니다. 배경 테두리와 글자 테두리도 넣을 수 있습니다.
- **실시간 미리보기.** 설정 창에서 실제 시스템 커서(화살표 또는 I-beam)와 배지를 실제 크기로 함께 보여 줍니다.
- **Caps Lock 표시.** Caps Lock이 켜지면 배지 글자 앞에 `⇪`가 붙습니다.
- **전환 강조 (선택).** 입력 소스나 Caps Lock이 바뀌면 배지가 커졌다가 원래 크기로 돌아옵니다.
- **표시 모드.**
  - 항상 표시
  - 전환 후 잠시 표시
  - 마우스가 멈추면 흐리게
- **작업을 방해하지 않음.**
  - 타이핑할 때처럼 시스템이 커서를 숨기면 배지도 숨깁니다.
  - 화면을 캡처하는 동안(Cmd+Shift+4 또는 Cmd+Shift+5)에는 배지를 숨깁니다.
  - Space를 전환할 때 배지가 화면과 함께 미끄러지지 않습니다.
  - 배지를 클릭하면 클릭이 배지 아래의 창으로 전달됩니다.
- **권한 요청 없음.** 접근성, 입력 모니터링, 화면 기록 권한을 요청하지 않습니다.
- **가벼운 동작.** 유휴 상태의 CPU 사용률은 약 0.1~0.2%, 메모리 사용량은 약 17 MB입니다(개발 환경에서 측정).

## 요구 사항

- macOS 14 (Sonoma) 이상
- Swift 6 도구 모음: Xcode 또는 Xcode Command Line Tools (`xcode-select --install`)

## 빌드와 실행

```sh
git clone https://github.com/Biisairo/IME_Cursor.git
cd IME_Cursor
./scripts/build_app.sh
open build/ImeCursor.app
```

`scripts/build_app.sh`는 다음 순서로 동작합니다.

1. `swift build -c release`로 release 실행 파일을 빌드합니다. 실행 파일은 `.build/release/`에 생깁니다.
2. 실행 파일, `Info.plist`, 앱 아이콘을 넣어 `build/ImeCursor.app`을 만듭니다.
3. 앱에 ad-hoc 서명을 합니다.

설치하려면 `build/ImeCursor.app`을 `/Applications`로 복사하면 됩니다.

이 앱에는 ad-hoc 서명만 있고, 공증(notarization)은 받지 않았습니다. 다른 Mac으로 앱을 옮기면 Gatekeeper가 실행을 막을 수 있습니다. 이때는 Finder에서 앱을 오른쪽 클릭한 뒤 **열기**를 선택하세요.

### 테스트 실행

```sh
./scripts/test.sh
```

Command Line Tools만 설치된 환경에서는 SwiftPM이 Swift Testing 매크로 플러그인을 찾지 못합니다. 그래서 `scripts/test.sh`가 Command Line Tools 위치의 플러그인 경로를 지정해 줍니다. Xcode가 설치되어 있으면 `swift test`를 바로 실행해도 됩니다.

### 앱 아이콘 다시 만들기

아이콘 그림은 `Sources/ImeCursor/IconArtwork.swift`에 코드로 정의되어 있습니다. 이 파일을 고친 뒤에는 다음 명령을 실행하세요.

```sh
./scripts/make_icon.sh
```

이 스크립트는 `Resources/AppIcon.icns`를 만듭니다. 미리보기 PNG 파일은 `build/icon-preview/`에 저장합니다.

## 사용 방법

ImeCursor를 실행하면 메뉴바에 아이콘이 나타납니다. Dock에는 아이콘이 나타나지 않습니다.

| 메뉴 항목 | 동작 |
|---|---|
| 배지 표시 | 배지를 켜거나 끕니다 |
| 설정… | 설정 창을 엽니다 |
| 종료 | ImeCursor를 종료합니다 |

설정 창에는 세 종류의 화면이 있습니다.

- **동작:** 전환 강조, 표시 모드, 로그인 시 자동 실행
- **기본 스타일:** 개별 스타일이 없는 입력 소스에 적용하는 스타일
- **입력 소스:** 켜져 있는 입력 소스마다 화면이 하나씩 있습니다. 표시 글자를 정하고, "기본 스타일 사용"과 개별 스타일 가운데 하나를 고릅니다.

설정은 자동으로 저장되고, 바꾼 값은 배지에 바로 반영됩니다.

처음 실행하면 한국어 입력 소스는 파란 배지(`한`)로 시작합니다. 다른 입력 소스는 회색 기본 스타일을 씁니다. 기본 표시 글자는 입력 소스의 언어에 따라 정해집니다. 영어는 `A`, 일본어는 `あ`, 중국어는 `中`이고, 그 밖의 언어는 언어 코드를 씁니다.

## 동작 원리

| 항목 | 구현 |
|---|---|
| 입력 소스 감지 | Text Input Sources API(`TISCopyCurrentKeyboardInputSource`)와 분산 알림 `kTISNotifySelectedKeyboardInputSourceChanged` |
| 배지 | 테두리 없는 패널입니다. 클릭을 통과시키고, 전역 마우스 이동 이벤트를 받아 포인터를 따라갑니다 |
| 커서 표시 상태 | 100 ms마다 `CGCursorIsVisible`로 확인합니다. 이 함수는 지원이 중단되어서, 실행 시간에 `dlsym`으로 불러옵니다. 함수를 찾지 못하면 배지를 항상 표시합니다 |
| 화면 캡처 감지 | 300 ms마다 화면 위 창 목록을 확인합니다. 창 제목은 읽지 않고, 소유 프로세스와 레이어만 봅니다 |
| Caps Lock | 100 ms마다 `NSEvent.modifierFlags`로 확인합니다. 키 이벤트 모니터는 권한이 필요해서 쓰지 않습니다 |
| Space | 배지 창은 현재 Space에만 속합니다(`moveToActiveSpace`). Space 전환이 끝나면 배지를 새 Space로 옮깁니다 |
| 설정 | 설정 창은 별도 프로세스(`--settings`)로 실행합니다. 그래서 설정을 편집하는 동안에도 배지가 포인터를 늦지 않게 따라갑니다. 두 프로세스는 `UserDefaults`를 공유하고, 변경 알림을 서로 주고받습니다 |

## 알려진 제한 사항

- 배지는 텍스트 캐럿이 아니라 마우스 포인터를 따라갑니다.
- Space 전환 애니메이션 중에는 시스템이 마우스 이벤트를 보내지 않습니다. 그동안 배지는 보이지 않다가, 전환이 끝나면 다시 나타납니다.
- 화면 캡처를 시작한 뒤 배지가 사라지기까지 최대 0.3초가 걸릴 수 있습니다.
- Caps Lock 변경이 배지에 반영되기까지 최대 0.1초가 걸릴 수 있습니다.
- 글자가 배지 폭보다 넓으면 글자가 잘립니다. `⇪`도 폭을 차지하므로, 필요하면 배지 폭을 늘리세요.

## 프로젝트 구조

```
Sources/
  ImeCursorCore/   UI가 없는 순수 로직: 스타일, 글자 규칙, 배치 계산, 설정 저장
  ImeCursor/       앱: AppKit과 SwiftUI, TIS 접근, 배지 창, 설정 창
Tests/
  ImeCursorCoreTests/   ImeCursorCore 테스트 (Swift Testing)
scripts/           빌드, 테스트, 아이콘 스크립트와 Info.plist
Resources/         앱 아이콘
docs/SRS.md        소프트웨어 요구사항 명세서 (한국어, ISO/IEC/IEEE 29148)
```

## 라이선스

ImeCursor는 [MIT 라이선스](LICENSE)로 배포합니다.
