import AppKit
import ImeCursorCore
import SwiftUI

@MainActor
private func makeModel() -> AppModel {
  AppModel(store: SettingsStore(storage: UserDefaults.standard), provider: TISInputSourceProvider())
}

@MainActor
final class BadgeAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let model = makeModel()
  private var badge: BadgeController?
  private var statusItem: NSStatusItem?
  private var settingsApp: NSRunningApplication?
  private let toggleItem = NSMenuItem(
    title: "배지 표시", action: #selector(toggleBadge), keyEquivalent: "")

  func applicationDidFinishLaunching(_ notification: Notification) {
    badge = BadgeController(model: model)
    statusItem = makeStatusItem()
  }

  private func makeStatusItem() -> NSStatusItem {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = IconArtwork.menuBarImage()
    item.button?.image?.accessibilityDescription = "ImeCursor"
    let menu = NSMenu()
    menu.delegate = self
    toggleItem.target = self
    menu.addItem(toggleItem)
    menu.addItem(.separator())
    let settings = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)
    menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    item.menu = menu
    return item
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    toggleItem.state = model.settings.badgeEnabled ? .on : .off
  }

  @objc private func toggleBadge() {
    model.update { $0.badgeEnabled.toggle() }
  }

  @objc private func openSettings() {
    if let settingsApp, !settingsApp.isTerminated {
      settingsApp.activate()
      return
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.arguments = [LaunchMode.settingsFlag]
    NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) {
      app, _ in
      Task { @MainActor in
        self.settingsApp = app
        app?.activate()
      }
    }
  }
}

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
  private let model = makeModel()
  private var window: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = makeMainMenu()
    let window = NSWindow(
      contentViewController: NSHostingController(
        rootView: SettingsView().environmentObject(model)))
    window.title = "ImeCursor 설정"
    window.styleMask.insert(.fullSizeContentView)
    window.center()
    self.window = window
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  /// 메뉴바 앱에는 기본 메뉴가 없어서, 설정 창의 텍스트 편집 단축키를 위해 편집 메뉴를 둔다.
  private func makeMainMenu() -> NSMenu {
    let main = NSMenu()
    let appItem = NSMenuItem()
    appItem.submenu = NSMenu()
    appItem.submenu?.addItem(
      NSMenuItem(title: "창 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
    main.addItem(appItem)
    let editItem = NSMenuItem()
    let edit = NSMenu(title: "편집")
    edit.addItem(NSMenuItem(title: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z"))
    edit.addItem(NSMenuItem(title: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    edit.addItem(NSMenuItem(title: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    edit.addItem(NSMenuItem(title: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    edit.addItem(NSMenuItem(title: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
    editItem.submenu = edit
    main.addItem(editItem)
    return main
  }
}
