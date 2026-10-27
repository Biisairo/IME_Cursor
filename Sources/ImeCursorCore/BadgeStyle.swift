import Foundation

public struct RGBA: Codable, Equatable, Hashable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double
  public var alpha: Double

  public init(red: Double, green: Double, blue: Double, alpha: Double) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  public func clamped() -> RGBA {
    let unit: ClosedRange<Double> = 0...1
    return RGBA(
      red: red.clamped(to: unit), green: green.clamped(to: unit),
      blue: blue.clamped(to: unit), alpha: alpha.clamped(to: unit))
  }
}

public enum FontWeight: String, Codable, CaseIterable, Sendable {
  case regular, medium, semibold, bold
}

public struct BadgeStyle: Codable, Equatable, Hashable, Sendable {
  public enum Limits {
    public static let fontSize: ClosedRange<Double> = 6...72
    public static let size: ClosedRange<Double> = 4...200
    public static let cornerRadius: ClosedRange<Double> = 0...100
    public static let offset: ClosedRange<Double> = -200...200
    public static let backgroundBorder: ClosedRange<Double> = 0...20
    public static let textBorder: ClosedRange<Double> = 0...10
  }

  static let transparent = RGBA(red: 0, green: 0, blue: 0, alpha: 0)

  public static let initial = BadgeStyle(
    isVisible: true,
    fontSize: 12,
    fontWeight: .semibold,
    textColor: RGBA(red: 1, green: 1, blue: 1, alpha: 1),
    backgroundColor: RGBA(red: 0.45, green: 0.45, blue: 0.45, alpha: 0.85),
    width: 22,
    height: 18,
    cornerRadius: 5,
    offsetX: 16,
    offsetY: 16,
    backgroundBorderWidth: 1,
    backgroundBorderColor: transparent,
    textBorderWidth: 1,
    textBorderColor: transparent)

  public var isVisible: Bool
  public var fontSize: Double
  public var fontWeight: FontWeight
  public var textColor: RGBA
  public var backgroundColor: RGBA
  public var width: Double
  public var height: Double
  public var cornerRadius: Double
  public var offsetX: Double
  public var offsetY: Double
  public var backgroundBorderWidth: Double
  public var backgroundBorderColor: RGBA
  public var textBorderWidth: Double
  public var textBorderColor: RGBA

  public init(
    isVisible: Bool, fontSize: Double, fontWeight: FontWeight, textColor: RGBA,
    backgroundColor: RGBA, width: Double, height: Double, cornerRadius: Double,
    offsetX: Double, offsetY: Double, backgroundBorderWidth: Double,
    backgroundBorderColor: RGBA, textBorderWidth: Double, textBorderColor: RGBA
  ) {
    self.isVisible = isVisible
    self.fontSize = fontSize
    self.fontWeight = fontWeight
    self.textColor = textColor
    self.backgroundColor = backgroundColor
    self.width = width
    self.height = height
    self.cornerRadius = cornerRadius
    self.offsetX = offsetX
    self.offsetY = offsetY
    self.backgroundBorderWidth = backgroundBorderWidth
    self.backgroundBorderColor = backgroundBorderColor
    self.textBorderWidth = textBorderWidth
    self.textBorderColor = textBorderColor
  }

  private enum CodingKeys: String, CodingKey {
    case isVisible, fontSize, fontWeight, textColor, backgroundColor, width, height
    case cornerRadius, offsetX, offsetY
    case backgroundBorderWidth, backgroundBorderColor, textBorderWidth, textBorderColor
  }

  /// 스키마 버전 1에는 테두리 항목이 없으므로 초기값으로 채운다(FR-STORE-6).
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let initial = BadgeStyle.initial
    isVisible = try c.decode(Bool.self, forKey: .isVisible)
    fontSize = try c.decode(Double.self, forKey: .fontSize)
    fontWeight = try c.decode(FontWeight.self, forKey: .fontWeight)
    textColor = try c.decode(RGBA.self, forKey: .textColor)
    backgroundColor = try c.decode(RGBA.self, forKey: .backgroundColor)
    width = try c.decode(Double.self, forKey: .width)
    height = try c.decode(Double.self, forKey: .height)
    cornerRadius = try c.decode(Double.self, forKey: .cornerRadius)
    offsetX = try c.decode(Double.self, forKey: .offsetX)
    offsetY = try c.decode(Double.self, forKey: .offsetY)
    backgroundBorderWidth =
      try c.decodeIfPresent(Double.self, forKey: .backgroundBorderWidth)
      ?? initial.backgroundBorderWidth
    backgroundBorderColor =
      try c.decodeIfPresent(RGBA.self, forKey: .backgroundBorderColor)
      ?? initial.backgroundBorderColor
    textBorderWidth =
      try c.decodeIfPresent(Double.self, forKey: .textBorderWidth) ?? initial.textBorderWidth
    textBorderColor =
      try c.decodeIfPresent(RGBA.self, forKey: .textBorderColor) ?? initial.textBorderColor
  }

  public var effectiveCornerRadius: Double {
    min(cornerRadius, width / 2, height / 2)
  }

  public var outerWidth: Double { width + 2 * backgroundBorderWidth }
  public var outerHeight: Double { height + 2 * backgroundBorderWidth }
  public var outerOffsetX: Double { offsetX - backgroundBorderWidth }
  public var outerOffsetY: Double { offsetY - backgroundBorderWidth }

  public var outerCornerRadius: Double {
    effectiveCornerRadius > 0 ? effectiveCornerRadius + backgroundBorderWidth : 0
  }

  /// 획 가운데에 그려지는 윤곽선을 글자 아래에 두 배 두께로 그려서, 바깥쪽 두께만 보이게 한다(FR-STYLE-6).
  /// `NSAttributedString.Key.strokeWidth`는 글자 크기 대비 백분율이다.
  public var textOutlineStrokePercent: Double {
    2 * textBorderWidth / fontSize * 100
  }

  public func clamped() -> BadgeStyle {
    var s = self
    s.fontSize = fontSize.clamped(to: Limits.fontSize)
    s.textColor = textColor.clamped()
    s.backgroundColor = backgroundColor.clamped()
    s.width = width.clamped(to: Limits.size)
    s.height = height.clamped(to: Limits.size)
    s.cornerRadius = cornerRadius.clamped(to: Limits.cornerRadius)
    s.offsetX = offsetX.clamped(to: Limits.offset)
    s.offsetY = offsetY.clamped(to: Limits.offset)
    s.backgroundBorderWidth = backgroundBorderWidth.clamped(to: Limits.backgroundBorder)
    s.backgroundBorderColor = backgroundBorderColor.clamped()
    s.textBorderWidth = textBorderWidth.clamped(to: Limits.textBorder)
    s.textBorderColor = textBorderColor.clamped()
    return s
  }
}

extension Double {
  func clamped(to range: ClosedRange<Double>) -> Double {
    if isNaN { return range.lowerBound }
    return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
  }
}
