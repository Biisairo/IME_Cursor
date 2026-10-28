import Carbon
import Combine
import Foundation
import ImeCursorCore

@MainActor
final class AppModel: NSObject, ObservableObject {
  @Published private(set) var settings: AppSettings
  @Published private(set) var sources: [InputSourceInfo] = []
  @Published private(set) var current: InputSourceInfo?

  private let store: SettingsStore
  private let provider: InputSourceProvider
  private let pid = String(ProcessInfo.processInfo.processIdentifier)

  static let settingsChanged = Notification.Name("com.dykim.ImeCursor.settingsChanged")

  init(store: SettingsStore, provider: InputSourceProvider) {
    self.store = store
    self.provider = provider
    settings = store.load()
    super.init()
    refreshCurrent()
    refreshSources()
    observe(kTISNotifySelectedKeyboardInputSourceChanged, #selector(selectedSourceChanged))
    observe(kTISNotifyEnabledKeyboardInputSourcesChanged, #selector(enabledSourcesChanged))
    DistributedNotificationCenter.default().addObserver(
      self, selector: #selector(settingsChangedElsewhere(_:)), name: Self.settingsChanged,
      object: nil, suspensionBehavior: .deliverImmediately)
  }

  func update(_ transform: (inout AppSettings) -> Void) {
    transform(&settings)
    store.save(settings)
    DistributedNotificationCenter.default().postNotificationName(
      Self.settingsChanged, object: pid, userInfo: nil, deliverImmediately: true)
  }

  private func refreshCurrent() {
    current = provider.current()
  }

  private func refreshSources() {
    sources = provider.enabled()
  }

  private func observe(_ name: CFString, _ selector: Selector) {
    // NSApplication이 비활성 상태일 때도 알림을 바로 받아야 한다.
    DistributedNotificationCenter.default().addObserver(
      self, selector: selector, name: Notification.Name(name as String), object: nil,
      suspensionBehavior: .deliverImmediately)
  }

  @objc private func selectedSourceChanged() {
    refreshCurrent()
  }

  @objc private func settingsChangedElsewhere(_ notification: Notification) {
    guard notification.object as? String != pid else { return }
    settings = store.load()
  }

  @objc private func enabledSourcesChanged() {
    refreshSources()
    refreshCurrent()
  }
}
