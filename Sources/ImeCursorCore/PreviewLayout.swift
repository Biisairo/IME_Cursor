import CoreGraphics

/// 설정 미리보기에서 커서(또는 캐럿)와 배지를 놓을 위치. 좌표는 왼쪽 위 원점, Y 아래쪽이다(UI-6, UI-10, UI-13).
public struct PreviewLayout: Equatable, Sendable {
  public static let padding: CGFloat = 12
  public static let caretSize = CGSize(width: 2, height: 18)

  public var canvasSize: CGSize
  public var imageOrigin: CGPoint
  public var badgeOrigin: CGPoint
  public var badgeSize: CGSize

  /// 커서는 핫스폿에 놓인 크기 0의 사각형이 대상이다.
  public static func make(
    cursorSize: CGSize, hotSpot: CGPoint, style: BadgeStyle, position: BadgePosition
  ) -> PreviewLayout {
    make(
      image: CGRect(origin: CGPoint(x: -hotSpot.x, y: -hotSpot.y), size: cursorSize),
      target: .zero, style: style, position: position)
  }

  public static func make(caretSize: CGSize, style: BadgeStyle, position: BadgePosition)
    -> PreviewLayout
  {
    let caret = CGRect(origin: .zero, size: caretSize)
    return make(image: caret, target: caret, style: style, position: position)
  }

  static func make(image: CGRect, target: CGRect, style: BadgeStyle, position: BadgePosition)
    -> PreviewLayout
  {
    let border = style.backgroundBorderWidth
    let badge = BadgePlacement.backgroundRect(
      target: target, size: CGSize(width: style.width, height: style.height), position: position
    ).insetBy(dx: -border, dy: -border)
    let bounds = image.union(badge)
    let shift = CGVector(dx: padding - bounds.minX, dy: padding - bounds.minY)
    return PreviewLayout(
      canvasSize: CGSize(width: bounds.width + 2 * padding, height: bounds.height + 2 * padding),
      imageOrigin: CGPoint(x: image.minX + shift.dx, y: image.minY + shift.dy),
      badgeOrigin: CGPoint(x: badge.minX + shift.dx, y: badge.minY + shift.dy),
      badgeSize: badge.size)
  }
}
