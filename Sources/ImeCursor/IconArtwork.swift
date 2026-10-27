import AppKit

/// 앱 아이콘과 메뉴바 아이콘이 함께 쓰는 그림 정의(UI-2, UI-12). 좌표는 왼쪽 위 원점이다.
/// scripts/make_icon.sh가 이 파일을 함께 컴파일해서 AppIcon.icns를 만든다.
enum IconArtwork {
  /// 고전 화살표 커서의 외곽선. 12 × 18 단위.
  private static let arrowPoints: [CGPoint] = [
    CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 16), CGPoint(x: 3.9, y: 12.4),
    CGPoint(x: 6.3, y: 17.9), CGPoint(x: 8.5, y: 17), CGPoint(x: 6.2, y: 11.6),
    CGPoint(x: 11.4, y: 11.6),
  ]

  private static let badgeBlue = NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
  private static let label = "A"

  static func arrowPath(tip: CGPoint, unit: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for (index, point) in arrowPoints.enumerated() {
      let p = CGPoint(x: tip.x + point.x * unit, y: tip.y + point.y * unit)
      if index == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    path.lineJoinStyle = .round
    return path
  }

  /// 1024 × 1024 기준 앱 아이콘. 뒤집힌(flipped) 그래픽 컨텍스트에서 부른다.
  static func drawAppIcon() {
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    shadow(blur: 28, y: 12, alpha: 0.35).set()
    NSColor.black.setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(
      starting: NSColor(srgbRed: 0.20, green: 0.27, blue: 0.50, alpha: 1),
      ending: NSColor(srgbRed: 0.07, green: 0.10, blue: 0.22, alpha: 1)
    )?.draw(in: bodyPath, angle: 90)

    let arrow = arrowPath(tip: CGPoint(x: 235, y: 215), unit: 30)
    NSGraphicsContext.saveGraphicsState()
    shadow(blur: 18, y: 10, alpha: 0.4).set()
    NSColor.black.setStroke()
    arrow.lineWidth = 26
    arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.setFill()
    arrow.fill()

    let badge = NSRect(x: 525, y: 585, width: 290, height: 230)
    let badgePath = NSBezierPath(roundedRect: badge, xRadius: 56, yRadius: 56)
    NSGraphicsContext.saveGraphicsState()
    shadow(blur: 18, y: 10, alpha: 0.4).set()
    badgeBlue.setFill()
    badgePath.fill()
    NSGraphicsContext.restoreGraphicsState()
    drawCentered(label, in: badge, size: 170, color: .white)
  }

  /// 메뉴바용 단색 템플릿 이미지. 배지 안의 글자는 뚫어서 표현한다.
  static func menuBarImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      NSColor.black.setFill()
      arrowPath(tip: CGPoint(x: 1.5, y: 0.8), unit: 0.72).fill()
      let badge = NSRect(x: 8.2, y: 9, width: 9.3, height: 8.2)
      let badgePath = NSBezierPath(roundedRect: badge, xRadius: 2, yRadius: 2)
      context.setBlendMode(.destinationOut)
      badgePath.lineWidth = 2.4
      badgePath.stroke()
      context.setBlendMode(.normal)
      badgePath.fill()
      context.setBlendMode(.destinationOut)
      drawCentered(label, in: badge, size: 7.5, color: .black)
      context.setBlendMode(.normal)
      return true
    }
    image.isTemplate = true
    return image
  }

  private static func drawCentered(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor) {
    let string = NSAttributedString(
      string: text,
      attributes: [.font: NSFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: color])
    let bounds = string.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin])
    string.draw(
      at: NSPoint(x: rect.midX - bounds.width / 2, y: rect.midY - bounds.height / 2))
  }

  private static func shadow(blur: CGFloat, y: CGFloat, alpha: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -y)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    return shadow
  }
}
