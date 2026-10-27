import AppKit
import ImeCursorCore

let delegate: NSApplicationDelegate =
  switch LaunchMode(arguments: CommandLine.arguments) {
  case .badge: BadgeAppDelegate()
  case .settings: SettingsAppDelegate()
  }
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
