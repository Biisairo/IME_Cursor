# ImeCursor

[English](README.md) | [한국어](README.ko.md)

ImeCursor is a macOS menu bar app. It shows the current keyboard input source as a small badge next to the mouse pointer. If you turn it on, it also shows a badge next to the text caret where you type.

When you switch between input sources (for example, 2-Set Korean and ABC), the badge changes immediately. You can see the input language before you type, without looking at the menu bar.

## Features

- **Badge for every input source.** ImeCursor reads all enabled input sources from the system. You can set a different badge for each one: Korean, English, Japanese, and others.
- **Caret badge (optional).** ImeCursor can show a second badge next to the text caret. While you type, the system hides the mouse cursor, and you look at the caret. With the caret badge, you can see the input source while you type. The display condition is "off", "when the cursor is hidden", or "always when there is a caret". This feature needs Accessibility permission.
- **Full style control per input source and per badge.** You can change the label text, font size and weight, text color, background size and color, corner radius, and position. You can also add a border to the background and an outline to the text. An input source page stores only the items that you change. All other items follow the default style.
- **Position by direction and offset.** Select a direction in a 3 × 3 grid. The badge then attaches outside the pointer or caret on that side. Then use the X and Y offsets to adjust the position. By default, the caret badge is directly to the right of the caret.
- **Live preview.** The settings window shows the badge next to a real system cursor (arrow or I-beam) or a caret at actual size.
- **Caps Lock indicator.** When Caps Lock is on, the badge shows `⇪` before the label.
- **Switch emphasis (optional).** When the input source or Caps Lock changes, the badge grows and then returns to its normal size.
- **Display modes.** You set them separately for the cursor badge and the caret badge.
  - Always show
  - Show for a few seconds after a switch
  - Dim when the mouse stops (cursor badge only)
- **Stays out of the way.**
  - The cursor badge hides when the system hides the cursor, for example while you type.
  - The badge hides while you take a screenshot (Cmd+Shift+4 or Cmd+Shift+5).
  - The badge does not slide with the screen when you switch Spaces.
  - Clicks pass through the badge.
- **Only the permission it needs.** ImeCursor asks for Accessibility permission only when you turn on the caret badge. When the caret badge is off, ImeCursor asks for no permissions. It never asks for Input Monitoring or Screen Recording permission.
- **Light on resources.** Idle CPU use is about 0.1–0.2%, and memory use is about 17 MB (measured on the development machine).

## Install

Download `ImeCursor-<version>.zip` from the [Releases](https://github.com/Biisairo/IME_Cursor/releases) page and unzip it. Then move `ImeCursor.app` to `/Applications`.

The app has only an ad-hoc signature and is not notarized. If macOS blocks the first launch, do one of these:

- In System Settings → Privacy & Security, click **Open Anyway**.
- In Terminal, run `xattr -dr com.apple.quarantine /Applications/ImeCursor.app`, then open the app again.

To build the app yourself, see "Build and run" below.

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

### Make a release

```sh
./scripts/release.sh
```

This script reads the version from `scripts/Info.plist`. It creates the `v<version>` tag and a GitHub release, and attaches `build/ImeCursor-<version>.zip`. The release text comes from `docs/releases/v<version>.md`. Before you run it, make sure that:

- You increased the version and created the release notes file.
- You committed all changes and pushed them to `origin/main`.
- `gh` is logged in with an account that has write access to the repository.

If a condition is not true or a test fails, the script stops and uploads nothing.

### Diagnose the caret position

```sh
./scripts/caret_probe.sh [interval in seconds] [--enhanced]
```

Use this tool when the caret badge does not work in an app. It prints the role of the focused element, the method that found the caret, and the editability signals. It draws a red frame around a found caret, an orange frame around an estimated caret, and a yellow frame around the input element. With `--enhanced`, it turns on `AXEnhancedUserInterface` for the frontmost app. That value stays on until the app quits. The terminal app that runs the tool must have Accessibility permission.

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
| 배지 표시 (Show badge) | Turns the cursor badge and the caret badge on or off together |
| 설정… (Settings…) | Opens the settings window |
| 종료 (Quit) | Quits ImeCursor |

The list on the left of the settings window has these items, in this order:

- **동작 (Behavior):** Launch at login, cursor badge on or off, caret badge display condition, Accessibility permission status, and switch emphasis and display mode for each badge
- **기본 스타일 (Default style):** The style that both badges share. The position defaults (direction, X, Y) are separate for the cursor badge and the caret badge.
- **커서 배지 (Cursor badge), 캐럿 배지 (Caret badge):** Each section lists the enabled input sources. When you change an item on an input source page, ImeCursor overrides only that item. Each overridden item shows a dot and a revert button. "초기화" (Reset) removes all overrides of that badge. Both badges use the same label.

Settings are saved automatically. Changes apply to the badge immediately.

On first launch, ImeCursor moves settings from earlier versions automatically. The cursor badge position and the per-source styles stay the same.

### Turn on the caret badge

1. On the **동작 (Behavior)** page of the settings window, select a display condition for the caret badge.
2. When macOS asks for Accessibility permission, allow ImeCursor in System Settings.
3. When the permission status on the **동작 (Behavior)** page changes to "허용됨" (Allowed), the caret badge starts to work.

After you rebuild the app, you must allow Accessibility permission again. The ad-hoc signature changes with each build, and the permission is tied to the signature.

On first launch, Korean input sources get a blue badge (`한`). This badge overrides only the background color, so it follows other changes to the default style. Other input sources use the gray default style. The default label comes from the input source language: `A` for English, `あ` for Japanese, `中` for Chinese, and the language code for other languages.

## How it works

| Topic | Implementation |
|---|---|
| Input source detection | Text Input Sources API (`TISCopyCurrentKeyboardInputSource`) and the `kTISNotifySelectedKeyboardInputSourceChanged` distributed notification |
| Badge | A borderless, click-through panel that follows global mouse-move events |
| Cursor visibility | `CGCursorIsVisible`, checked at each polling interval. This function is deprecated, so ImeCursor loads it at runtime with `dlsym`. If the function is not available, the badge always shows. |
| Screenshot detection | The on-screen window list (owner and layer only, no window titles), checked every 300 ms |
| Caps Lock | `NSEvent.modifierFlags`, checked at each polling interval. Key event monitors need Input Monitoring permission, so ImeCursor does not use them. |
| Caret position | The Accessibility API gives the focused element. Only for editable elements, ImeCursor uses the end of the selection as the caret and asks for its screen position. If the app gives no position, ImeCursor estimates it from the shape of the element. If that also fails, the caret badge hides. |
| Chrome-based browsers | Chrome gives the caret position in text fields only when `AXEnhancedUserInterface` is on. ImeCursor turns this value on for Chromium browsers only while the caret badge is on. It turns the value off again when you turn off the caret badge or quit ImeCursor. |
| Polling interval | ImeCursor uses one timer. The interval is usually 100 ms. When the caret badge is on, the interval is 16 ms for 1 second after a key press or a focus change. |
| Spaces | The badge window belongs to the current Space only (`moveToActiveSpace`). After a Space switch, the badge moves to the new Space. |
| Settings | The settings window runs in a separate process (`--settings`), so the badge keeps up with the pointer while you edit settings. The two processes share `UserDefaults` and send change notifications to each other. |

## Known limitations

- The caret badge works only in apps that give the caret position through the Accessibility API. In apps that do not (for example, Java apps and games), the caret badge does not appear.
- In Chrome, the caret badge follows the caret with a small delay, because Chrome updates its accessibility data late. For 2–3 seconds after you turn on the caret badge, the caret badge may not appear in Chrome.
- There are reports that window manager apps (for example, Rectangle) move windows more slowly while `AXEnhancedUserInterface` is on in a Chrome-based browser.
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
scripts/           Build, test, release, icon, and caret diagnosis scripts; Info.plist
Resources/         App icon
docs/SRS.md        Software requirements specification (Korean, ISO/IEC/IEEE 29148)
docs/releases/     Release notes
```

## License

ImeCursor is available under the [MIT License](LICENSE).
