import CoreGraphics

/// 대상 사각형의 9개 점. 배지를 대상의 어느 쪽에 놓을지 정한다(FR-STYLE-8).
public enum BadgeAnchor: String, Codable, CaseIterable, Sendable {
  case topLeft, top, topRight
  case left, center, right
  case bottomLeft, bottom, bottomRight

  public var opposite: BadgeAnchor {
    switch self {
    case .topLeft: .bottomRight
    case .top: .bottom
    case .topRight: .bottomLeft
    case .left: .right
    case .center: .center
    case .right: .left
    case .bottomLeft: .topRight
    case .bottom: .top
    case .bottomRight: .topLeft
    }
  }

  /// 사각형 안의 위치 비율. Y는 아래쪽이 양수이다.
  var fraction: CGPoint {
    switch self {
    case .topLeft: CGPoint(x: 0, y: 0)
    case .top: CGPoint(x: 0.5, y: 0)
    case .topRight: CGPoint(x: 1, y: 0)
    case .left: CGPoint(x: 0, y: 0.5)
    case .center: CGPoint(x: 0.5, y: 0.5)
    case .right: CGPoint(x: 1, y: 0.5)
    case .bottomLeft: CGPoint(x: 0, y: 1)
    case .bottom: CGPoint(x: 0.5, y: 1)
    case .bottomRight: CGPoint(x: 1, y: 1)
    }
  }
}

/// 배지 위치: 기준 방향과 오프셋(FR-STYLE-7).
public struct BadgePosition: Codable, Equatable, Hashable, Sendable {
  public static let cursorInitial = BadgePosition(anchor: .bottomRight, offsetX: 16, offsetY: 16)
  public static let caretInitial = BadgePosition(anchor: .right, offsetX: 2, offsetY: 0)

  public var anchor: BadgeAnchor
  public var offsetX: Double
  public var offsetY: Double

  public init(anchor: BadgeAnchor, offsetX: Double, offsetY: Double) {
    self.anchor = anchor
    self.offsetX = offsetX
    self.offsetY = offsetY
  }

  public func clamped() -> BadgePosition {
    var p = self
    p.offsetX = offsetX.clamped(to: BadgeStyle.Limits.offset)
    p.offsetY = offsetY.clamped(to: BadgeStyle.Limits.offset)
    return p
  }
}

public enum BadgePlacement {
  /// Y 아래쪽 좌표계에서 배경 영역(테두리 제외)을 구한다(FR-STYLE-8 (1) ~ (4)).
  public static func backgroundRect(target: CGRect, size: CGSize, position: BadgePosition)
    -> CGRect
  {
    let anchor = position.anchor.fraction
    let alignment = position.anchor.opposite.fraction
    let point = CGPoint(
      x: target.minX + target.width * anchor.x, y: target.minY + target.height * anchor.y)
    return CGRect(
      x: point.x - size.width * alignment.x + position.offsetX,
      y: point.y - size.height * alignment.y + position.offsetY,
      width: size.width, height: size.height)
  }

  /// AppKit 좌표계(원점 왼쪽 아래, Y 위쪽)에서 배지 창(테두리 포함)의 원점을 구한다.
  /// 화면 경계 보정의 기준 화면은 대상의 왼쪽 위 점이 있는 화면이다(FR-BADGE-3, FR-CARET-8).
  public static func origin(
    target: CGRect, style: BadgeStyle, position: BadgePosition, screens: [CGRect]
  ) -> CGPoint {
    let flippedTarget = CGRect(
      x: target.minX, y: -target.maxY, width: target.width, height: target.height)
    let background = backgroundRect(
      target: flippedTarget, size: CGSize(width: style.width, height: style.height),
      position: position)
    let border = style.backgroundBorderWidth
    let x = background.minX - border
    let y = -background.maxY - border
    let size = CGSize(width: style.outerWidth, height: style.outerHeight)
    let reference = CGPoint(x: target.minX, y: target.maxY)
    guard let screen = screens.first(where: { contains($0, reference) }) ?? screens.first else {
      return CGPoint(x: x, y: y)
    }
    return CGPoint(
      x: max(min(x, screen.maxX - size.width), screen.minX),
      y: max(min(y, screen.maxY - size.height), screen.minY))
  }

  static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
    point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
  }
}

public enum ScreenGeometry {
  /// AX 좌표(주 화면 왼쪽 위 원점)와 AppKit 좌표(주 화면 왼쪽 아래 원점)를 서로 바꾼다.
  public static func flipped(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }
}
