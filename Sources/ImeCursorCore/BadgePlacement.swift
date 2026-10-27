import CoreGraphics

public enum BadgePlacement {
  /// AppKit 좌표계(원점 왼쪽 아래, Y 위쪽)에서 배지 창의 원점을 구한다. 오프셋의 Y는 아래쪽이 양수이다.
  public static func origin(
    pointer: CGPoint, size: CGSize, offset: CGVector, screens: [CGRect]
  ) -> CGPoint {
    let x = pointer.x + offset.dx
    let y = pointer.y - offset.dy - size.height
    guard let screen = screens.first(where: { contains($0, pointer) }) ?? screens.first else {
      return CGPoint(x: x, y: y)
    }
    return CGPoint(
      x: max(min(x, screen.maxX - size.width), screen.minX),
      y: max(min(y, screen.maxY - size.height), screen.minY))
  }

  private static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
    point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
  }
}
