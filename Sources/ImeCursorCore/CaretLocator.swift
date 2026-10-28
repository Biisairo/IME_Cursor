import CoreGraphics

public struct TextSpan: Equatable, Hashable, Sendable {
  public var location: Int
  public var length: Int

  public init(location: Int, length: Int) {
    self.location = location
    self.length = length
  }
}

/// 포커스 요소에서 읽은 AX 값. 좌표는 AX 좌표(주 화면 왼쪽 위 원점, Y 아래쪽)이다(QA-4).
public protocol FocusedText {
  var hasEditableAncestor: Bool { get }
  var isSelectedRangeSettable: Bool { get }
  var frame: CGRect? { get }
  var characterCount: Int? { get }
  var selectedRange: TextSpan? { get }
  func bounds(for range: TextSpan) -> CGRect?
  /// 선택 마커 범위의 끝 마커 m에 대한 범위 (m, m)의 사각형.
  func collapsedMarkerBounds() -> CGRect?
  /// 끝 마커 m과 그 앞 마커 p에 대한 범위 (p, m)의 사각형.
  func markerBoundsBeforeEnd() -> CGRect?
}

public enum CaretLocator {
  static let lineHeightLimit: CGFloat = 40
  static let emptyCaretHeight: CGFloat = 20
  static let frameTolerance: CGFloat = 4

  /// FR-CARET-4.
  public static func isEditable(_ text: FocusedText) -> Bool {
    text.hasEditableAncestor || text.isSelectedRangeSettable
  }

  /// FR-CARET-5. 편집할 수 없는 요소이거나 캐럿을 얻지 못하면 nil이다.
  public static func caret(in text: FocusedText, screens: [CGRect]) -> CGRect? {
    guard isEditable(text) else { return nil }
    let valid = { (rect: CGRect?) in rect.flatMap { isValid($0, frame: text.frame, screens: screens) ? $0 : nil } }
    if let range = text.selectedRange {
      let end = range.location + range.length
      if let found = valid(text.bounds(for: TextSpan(location: end, length: 0))) {
        return found
      }
      if end > 0, let found = valid(text.bounds(for: TextSpan(location: end - 1, length: 1)).map(rightEdge)) {
        return found
      }
      if let found = valid(text.bounds(for: TextSpan(location: end, length: 1)).map(leftEdge)) {
        return found
      }
    }
    if let found = valid(text.collapsedMarkerBounds()) {
      return found
    }
    if let found = valid(text.markerBoundsBeforeEnd().map(rightEdge)) {
      return found
    }
    guard let frame = text.frame else { return nil }
    if frame.height <= lineHeightLimit && frame.width <= frame.height {
      return frame
    }
    if text.characterCount == 0 {
      return CGRect(x: frame.minX, y: frame.minY, width: 0, height: emptyCaretHeight)
    }
    return nil
  }

  /// FR-CARET-6.
  static func isValid(_ rect: CGRect, frame: CGRect?, screens: [CGRect]) -> Bool {
    guard rect.minX != 0, rect.width <= max(rect.height, 1) else { return false }
    guard screens.contains(where: { BadgePlacement.contains($0, rect.origin) }) else { return false }
    guard let frame else { return true }
    return BadgePlacement.contains(
      frame.insetBy(dx: -frameTolerance, dy: -frameTolerance), CGPoint(x: rect.minX, y: rect.midY))
  }

  static func rightEdge(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height)
  }

  static func leftEdge(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
  }
}

/// `AXEnhancedUserInterface`를 켤 Chromium 브라우저(FR-CARET-9).
public enum ChromiumBrowsers {
  static let bundleIDs: Set<String> = [
    "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
    "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
    "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
  ]

  public static func contains(bundleID: String?) -> Bool {
    bundleID.map(bundleIDs.contains) ?? false
  }
}
