public struct SystemWindow: Equatable, Sendable {
  public var ownerName: String
  public var layer: Int

  public init(ownerName: String, layer: Int) {
    self.ownerName = ownerName
    self.layer = layer
  }
}

public enum CaptureDetector {
  static let screencaptureOwner = "screencapture"
  static let screenshotOwner = "Screenshot"

  /// 창 이름은 화면 기록 권한이 없으면 읽지 못할 수 있으므로 소유 프로세스와 레이어로 판별한다.
  public static func isCapturing(windows: [SystemWindow], screenSaverLevel: Int) -> Bool {
    windows.contains { window in
      window.ownerName == screencaptureOwner
        || (window.ownerName == screenshotOwner && window.layer > screenSaverLevel)
    }
  }
}

public enum BadgeVisibility {
  public static func shouldShow(badge: ResolvedBadge, cursorVisible: Bool, capturing: Bool) -> Bool {
    badge.isVisible && cursorVisible && !capturing
  }
}

public enum CaretVisibility {
  /// FR-CARET-3. `badge.isVisible`에는 전체 스위치, 표시 조건 끄기, 스타일의 표시 여부가 들어 있다.
  public static func shouldShow(
    badge: ResolvedBadge, condition: CaretCondition, cursorVisible: Bool, hasCaret: Bool,
    capturing: Bool
  ) -> Bool {
    guard badge.isVisible, hasCaret, !capturing else { return false }
    switch condition {
    case .off: return false
    case .whenCursorHidden: return !cursorVisible
    case .always: return true
    }
  }
}

/// 폴링 타이머 주기(PR-3).
public enum PollingPolicy {
  public static let normal: Double = 0.1
  public static let fast: Double = 0.016
  public static let burst: Double = 1

  public static func interval(caretActive: Bool, sinceKey: Double, sinceFocusChange: Double)
    -> Double
  {
    caretActive && min(sinceKey, sinceFocusChange) < burst ? fast : normal
  }
}
