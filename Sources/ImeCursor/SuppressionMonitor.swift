import AppKit
import ImeCursorCore

@MainActor
final class SuppressionMonitor {
  static let interval: TimeInterval = 0.1
  /// 창 목록 조회는 비싸서 커서 확인 세 번에 한 번만 한다(FR-HIDE-1).
  static let captureCheckEvery = 3

  private(set) var cursorVisible = true
  private(set) var capturing = false
  /// 키 이벤트 모니터는 권한이 필요해서 수정 키 상태를 주기마다 읽는다(FR-CAPS-1).
  private(set) var capsLock = NSEvent.modifierFlags.contains(.capsLock)
  var onChange: (() -> Void)?
  /// 표시 모드 불투명도를 다시 계산하도록 주기마다 부른다(FR-MODE-8).
  var onTick: (() -> Void)?

  private var timer: Timer?
  private var tick = 0
  private let screenSaverLevel = Int(CGWindowLevelForKey(.screenSaverWindow))

  func start() {
    let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.poll() }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
    poll()
  }

  func refreshCursor() {
    update(cursorVisible: CursorVisibility.isVisible, capturing: capturing, capsLock: capsLock)
  }

  private func poll() {
    defer { tick = (tick + 1) % Self.captureCheckEvery }
    let capturing =
      tick == 0
      ? CaptureDetector.isCapturing(windows: Self.windows(), screenSaverLevel: screenSaverLevel)
      : self.capturing
    update(
      cursorVisible: CursorVisibility.isVisible, capturing: capturing,
      capsLock: NSEvent.modifierFlags.contains(.capsLock))
    onTick?()
  }

  private func update(cursorVisible: Bool, capturing: Bool, capsLock: Bool) {
    guard
      cursorVisible != self.cursorVisible || capturing != self.capturing
        || capsLock != self.capsLock
    else { return }
    self.cursorVisible = cursorVisible
    self.capturing = capturing
    self.capsLock = capsLock
    onChange?()
  }

  private static func windows() -> [SystemWindow] {
    let infos =
      CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    return infos.compactMap { info in
      guard let owner = info[kCGWindowOwnerName as String] as? String,
        let layer = info[kCGWindowLayer as String] as? Int
      else { return nil }
      return SystemWindow(ownerName: owner, layer: layer)
    }
  }
}

/// `CGCursorIsVisible`은 Swift에서 막혀 있어서 실행 시간에 찾는다(SI-6).
@MainActor
enum CursorVisibility {
  private typealias Function = @convention(c) () -> UInt32

  private static let function: Function? = {
    guard
      let handle = dlopen(
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
      let symbol = dlsym(handle, "CGCursorIsVisible")
    else { return nil }
    return unsafeBitCast(symbol, to: Function.self)
  }()

  static var isVisible: Bool {
    function.map { $0() != 0 } ?? true
  }
}
