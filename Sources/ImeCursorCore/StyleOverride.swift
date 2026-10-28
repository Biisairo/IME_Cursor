/// 한 입력 소스의 한 배지에서 기본값과 다르게 정한 항목. 값이 없는 항목은 기본값을 따른다(FR-SRC-2, 3).
public struct StyleOverride: Codable, Equatable, Hashable, Sendable {
  public var isVisible: Bool?
  public var fontSize: Double?
  public var fontWeight: FontWeight?
  public var textColor: RGBA?
  public var backgroundColor: RGBA?
  public var width: Double?
  public var height: Double?
  public var cornerRadius: Double?
  public var backgroundBorderWidth: Double?
  public var backgroundBorderColor: RGBA?
  public var textBorderWidth: Double?
  public var textBorderColor: RGBA?
  public var anchor: BadgeAnchor?
  public var offsetX: Double?
  public var offsetY: Double?

  public init() {}

  public var isEmpty: Bool { self == StyleOverride() }

  public func style(over base: BadgeStyle) -> BadgeStyle {
    var s = base
    s.isVisible = isVisible ?? base.isVisible
    s.fontSize = fontSize ?? base.fontSize
    s.fontWeight = fontWeight ?? base.fontWeight
    s.textColor = textColor ?? base.textColor
    s.backgroundColor = backgroundColor ?? base.backgroundColor
    s.width = width ?? base.width
    s.height = height ?? base.height
    s.cornerRadius = cornerRadius ?? base.cornerRadius
    s.backgroundBorderWidth = backgroundBorderWidth ?? base.backgroundBorderWidth
    s.backgroundBorderColor = backgroundBorderColor ?? base.backgroundBorderColor
    s.textBorderWidth = textBorderWidth ?? base.textBorderWidth
    s.textBorderColor = textBorderColor ?? base.textBorderColor
    return s
  }

  public func position(over base: BadgePosition) -> BadgePosition {
    BadgePosition(
      anchor: anchor ?? base.anchor, offsetX: offsetX ?? base.offsetX,
      offsetY: offsetY ?? base.offsetY)
  }

  public func clamped() -> StyleOverride {
    var o = self
    o.fontSize = fontSize?.clamped(to: BadgeStyle.Limits.fontSize)
    o.textColor = textColor?.clamped()
    o.backgroundColor = backgroundColor?.clamped()
    o.width = width?.clamped(to: BadgeStyle.Limits.size)
    o.height = height?.clamped(to: BadgeStyle.Limits.size)
    o.cornerRadius = cornerRadius?.clamped(to: BadgeStyle.Limits.cornerRadius)
    o.backgroundBorderWidth = backgroundBorderWidth?.clamped(to: BadgeStyle.Limits.backgroundBorder)
    o.backgroundBorderColor = backgroundBorderColor?.clamped()
    o.textBorderWidth = textBorderWidth?.clamped(to: BadgeStyle.Limits.textBorder)
    o.textBorderColor = textBorderColor?.clamped()
    o.offsetX = offsetX?.clamped(to: BadgeStyle.Limits.offset)
    o.offsetY = offsetY?.clamped(to: BadgeStyle.Limits.offset)
    return o
  }

  /// `target`에서 `base`와 값이 다른 스타일 항목만 남긴다(FR-STORE-8 (3)).
  public static func difference(from base: BadgeStyle, to target: BadgeStyle) -> StyleOverride {
    func changed<T: Equatable>(_ path: KeyPath<BadgeStyle, T>) -> T? {
      base[keyPath: path] == target[keyPath: path] ? nil : target[keyPath: path]
    }
    var o = StyleOverride()
    o.isVisible = changed(\.isVisible)
    o.fontSize = changed(\.fontSize)
    o.fontWeight = changed(\.fontWeight)
    o.textColor = changed(\.textColor)
    o.backgroundColor = changed(\.backgroundColor)
    o.width = changed(\.width)
    o.height = changed(\.height)
    o.cornerRadius = changed(\.cornerRadius)
    o.backgroundBorderWidth = changed(\.backgroundBorderWidth)
    o.backgroundBorderColor = changed(\.backgroundBorderColor)
    o.textBorderWidth = changed(\.textBorderWidth)
    o.textBorderColor = changed(\.textBorderColor)
    return o
  }
}
