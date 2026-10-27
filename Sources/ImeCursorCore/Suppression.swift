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
