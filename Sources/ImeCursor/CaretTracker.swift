import AppKit
import ApplicationServices
import ImeCursorCore

/// 포커스 요소의 캐럿 사각형을 AppKit 좌표로 구한다(FR-CARET-2, 4 ~ 6, 9, 11, 12).
@MainActor
final class CaretTracker {
  /// AX 요청의 응답 대기 시간(SI-12).
  static let messagingTimeout: Float = 0.05

  private let systemWide = AXUIElementCreateSystemWide()
  private var prepared = Set<pid_t>()
  private var enhanced: [pid_t: AXUIElement] = [:]
  private var focused: AXUIElement?
  private var observers: [NSObjectProtocol] = []
  private(set) var caret: CGRect?
  private(set) var lastFocusChange = ProcessInfo.processInfo.systemUptime
  private(set) var isActive = false

  init() {
    AXUIElementSetMessagingTimeout(systemWide, Self.messagingTimeout)
    let center = NSWorkspace.shared.notificationCenter
    observers.append(
      center.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
      ) { [weak self] notification in
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        MainActor.assumeIsolated { app.map { self?.prepare($0) } }
      })
    observers.append(
      center.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
      ) { [weak self] notification in
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        MainActor.assumeIsolated {
          guard let pid = app?.processIdentifier else { return }
          self?.prepared.remove(pid)
          self?.enhanced[pid] = nil
        }
      })
  }

  /// 표시 조건과 권한에 따라 추적을 켜고 끈다. 끌 때는 켰던 `AXEnhancedUserInterface`를 되돌린다.
  /// 주기마다 불러서 권한이 생겼는지 다시 확인한다(FR-CARET-2).
  func setActive(_ active: Bool) {
    guard active != isActive, !active || AXIsProcessTrusted() else { return }
    isActive = active
    if active {
      NSWorkspace.shared.frontmostApplication.map(prepare)
    } else {
      restore()
      caret = nil
    }
  }

  /// 폴링 주기마다 부른다. 캐럿이 바뀌었으면 true를 돌려준다.
  func refresh() -> Bool {
    let previous = caret
    caret = isActive ? locate() : nil
    return caret != previous
  }

  func restore() {
    for app in enhanced.values {
      AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
    }
    enhanced.removeAll()
    prepared.removeAll()
  }

  private func prepare(_ app: NSRunningApplication) {
    guard isActive, prepared.insert(app.processIdentifier).inserted else { return }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    // Chrome은 이 값에만 반응한다. 효과가 있어도 오류 코드를 돌려주므로 반환값은 보지 않는다(A-10).
    if ChromiumBrowsers.contains(bundleID: app.bundleIdentifier) {
      AXUIElementSetAttributeValue(element, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
      enhanced[app.processIdentifier] = element
    }
  }

  private func locate() -> CGRect? {
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID()
    else {
      focused = nil
      return nil
    }
    let element = value as! AXUIElement
    if focused.map({ !CFEqual($0, element) }) ?? true {
      focused = element
      lastFocusChange = ProcessInfo.processInfo.systemUptime
    }
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    let screens = NSScreen.screens.map {
      ScreenGeometry.flipped($0.frame, primaryHeight: primaryHeight)
    }
    return CaretLocator.caret(in: AXFocusedText(element: element), screens: screens).map {
      ScreenGeometry.flipped($0, primaryHeight: primaryHeight)
    }
  }
}
