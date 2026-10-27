# ImeCursor

[English](README.md) | [한국어](README.ko.md)

ImeCursor is a macOS menu bar app. It shows the current keyboard input source as a small badge next to the mouse pointer.

When you switch between input sources (for example, 2-Set Korean and ABC), the badge changes immediately. You can see the input language before you type, without looking at the menu bar.

## Features

- **Badge for every input source.** ImeCursor reads all enabled input sources from the system. You can set a different badge for each one: Korean, English, Japanese, and others.
- **Full style control per input source.** You can change the label text, font size and weight, text color, background size and color, corner radius, and offset from the pointer. You can also add a border to the background and an outline to the text.
- **Live preview.** The settings window shows the badge next to a real system cursor (arrow or I-beam) at actual size.
- **Caps Lock indicator.** When Caps Lock is on, the badge shows `⇪` before the label.
- **Switch emphasis (optional).** When the input source or Caps Lock changes, the badge grows and then returns to its normal size.
- **Display modes.**
  - Always show
  - Show for a few seconds after a switch
  - Dim when the mouse stops
- **Stays out of the way.**
  - The badge hides when the system hides the cursor, for example while you type.
  - The badge hides while you take a screenshot (Cmd+Shift+4 or Cmd+Shift+5).
  - The badge does not slide with the screen when you switch Spaces.
  - Clicks pass through the badge.
- **No permission prompts.** ImeCursor does not ask for Accessibility, Input Monitoring, or Screen Recording permission.
- **Light on resources.** Idle CPU use is about 0.1–0.2%, and memory use is about 17 MB (measured on the development machine).

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 toolchain: Xcode, or Xcode Command Line Tools (`xcode-select --install`)

## Build and run

```sh
git clone https://github.com/Biisairo/IME_Cursor.git
cd IME_Cursor
./scripts/build_app.sh
open build/ImeCursor.app
```

`scripts/build_app.sh` does these steps:

1. Builds the release binary with `swift build -c release`. The binary goes to `.build/release/`.
2. Creates `build/ImeCursor.app` with the binary, `Info.plist`, and the app icon.
3. Signs the app with an ad-hoc signature.

To install, copy `build/ImeCursor.app` to `/Applications`.

The app has an ad-hoc signature only. It is not notarized. If you copy the app to another Mac, Gatekeeper can block it. In that case, right-click the app in Finder and select **Open**.

### Run the tests

```sh
./scripts/test.sh
```

With Command Line Tools only, SwiftPM cannot find the Swift Testing macro plugin. `scripts/test.sh` adds the plugin path for the Command Line Tools location. If you have Xcode, you can run `swift test` directly.

### Rebuild the app icon

The icon artwork is code in `Sources/ImeCursor/IconArtwork.swift`. After you change it, run:

```sh
./scripts/make_icon.sh
```

This script writes `Resources/AppIcon.icns`. It also writes preview PNG files to `build/icon-preview/`.

## Usage

After launch, ImeCursor shows an icon in the menu bar. It does not show a Dock icon.

The app UI is in Korean. The tables below show the Korean names with English translations.

| Menu item | Action |
|---|---|
| 배지 표시 (Show badge) | Turns the badge on or off |
| 설정… (Settings…) | Opens the settings window |
| 종료 (Quit) | Quits ImeCursor |

The settings window has three kinds of pages:

- **동작 (Behavior):** Switch emphasis, display mode, and launch at login
- **기본 스타일 (Default style):** The style for input sources that do not have their own style
- **입력 소스 (Input sources):** One page for each enabled input source. You can set the label, and you can select "기본 스타일 사용" (use default style) or set a custom style.

Settings are saved automatically. Changes apply to the badge immediately.

On first launch, Korean input sources get a blue badge (`한`). Other input sources use the gray default style. The default label comes from the input source language: `A` for English, `あ` for Japanese, `中` for Chinese, and the language code for other languages.

## How it works

| Topic | Implementation |
|---|---|
| Input source detection | Text Input Sources API (`TISCopyCurrentKeyboardInputSource`) and the `kTISNotifySelectedKeyboardInputSourceChanged` distributed notification |
| Badge | A borderless, click-through panel that follows global mouse-move events |
| Cursor visibility | `CGCursorIsVisible`, checked every 100 ms. This function is deprecated, so ImeCursor loads it at runtime with `dlsym`. If the function is not available, the badge always shows. |
| Screenshot detection | The on-screen window list (owner and layer only, no window titles), checked every 300 ms |
| Caps Lock | `NSEvent.modifierFlags`, checked every 100 ms. Key event monitors need permission, so ImeCursor does not use them. |
| Spaces | The badge window belongs to the current Space only (`moveToActiveSpace`). After a Space switch, the badge moves to the new Space. |
| Settings | The settings window runs in a separate process (`--settings`), so the badge keeps up with the pointer while you edit settings. The two processes share `UserDefaults` and send change notifications to each other. |

## Known limitations

- The badge follows the mouse pointer, not the text caret.
- During a Space switch animation, the system sends no mouse events. The badge is not visible during the animation and appears again after the switch.
- After you start a screenshot, the badge can take up to 0.3 seconds to hide.
- A Caps Lock change can take up to 0.1 seconds to appear on the badge.
- If the label is too wide for the badge, the label is clipped. The `⇪` symbol also adds width, so increase the badge width if necessary.

## Project structure

```
Sources/
  ImeCursorCore/   Pure logic without UI: styles, label rules, placement, settings storage
  ImeCursor/       The app: AppKit and SwiftUI, TIS access, badge window, settings window
Tests/
  ImeCursorCoreTests/   Tests for ImeCursorCore (Swift Testing)
scripts/           Build, test, and icon scripts; Info.plist
Resources/         App icon
docs/SRS.md        Software requirements specification (Korean, ISO/IEC/IEEE 29148)
```

## License

ImeCursor is available under the [MIT License](LICENSE).
