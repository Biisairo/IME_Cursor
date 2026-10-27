import CoreGraphics

/// 설정 미리보기에서 커서와 배지를 놓을 위치. 좌표는 왼쪽 위 원점, Y 아래쪽이다(UI-6, UI-10).
public struct PreviewLayout: Equatable, Sendable {
  public static let padding: CGFloat = 12

  public var canvasSize: CGSize
  public var cursorOrigin: CGPoint
  public var badgeOrigin: CGPoint
  public var badgeSize: CGSize

  public static func make(cursorSize: CGSize, hotSpot: CGPoint, style: BadgeStyle) -> PreviewLayout {
    let cursor = CGRect(origin: CGPoint(x: -hotSpot.x, y: -hotSpot.y), size: cursorSize)
    let badge = CGRect(
      x: style.outerOffsetX, y: style.outerOffsetY, width: style.outerWidth,
      height: style.outerHeight)
    let bounds = cursor.union(badge)
    let shift = CGVector(dx: padding - bounds.minX, dy: padding - bounds.minY)
    return PreviewLayout(
      canvasSize: CGSize(width: bounds.width + 2 * padding, height: bounds.height + 2 * padding),
      cursorOrigin: CGPoint(x: cursor.minX + shift.dx, y: cursor.minY + shift.dy),
      badgeOrigin: CGPoint(x: badge.minX + shift.dx, y: badge.minY + shift.dy),
      badgeSize: badge.size)
  }
}
