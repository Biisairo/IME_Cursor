public struct ResolvedBadge: Equatable, Sendable {
  public var style: BadgeStyle
  public var position: BadgePosition
  public var label: String
  public var isVisible: Bool

  public init(style: BadgeStyle, position: BadgePosition, label: String, isVisible: Bool) {
    self.style = style
    self.position = position
    self.label = label
    self.isVisible = isVisible
  }
}

public enum StyleResolver {
  static let koreanBackground = RGBA(red: 0, green: 0.48, blue: 1, alpha: 0.85)

  /// 저장된 덮어쓰기가 없을 때의 값(FR-SRC-7).
  public static func initialOverride(for info: InputSourceInfo) -> StyleOverride {
    var o = StyleOverride()
    if info.primaryLanguage == "ko" {
      o.backgroundColor = koreanBackground
    }
    return o
  }

  public static func sourceSettings(
    for info: InputSourceInfo, in settings: AppSettings
  ) -> SourceSettings {
    settings.sources[info.id]
      ?? SourceSettings(label: BadgeLabel.automatic(for: info), cursor: nil, caret: nil)
  }

  public static func override(
    _ kind: BadgeKind, for info: InputSourceInfo, in settings: AppSettings
  ) -> StyleOverride {
    sourceSettings(for: info, in: settings)[kind] ?? initialOverride(for: info)
  }

  public static func resolve(
    _ kind: BadgeKind, current: InputSourceInfo?, settings: AppSettings
  ) -> ResolvedBadge {
    let override = current.map { self.override(kind, for: $0, in: settings) } ?? StyleOverride()
    let style = override.style(over: settings.defaultStyle)
    let label = current.map { sourceSettings(for: $0, in: settings).label } ?? BadgeLabel.unknown
    let enabled =
      switch kind {
      case .cursor: settings.cursorEnabled
      case .caret: settings.caretCondition != .off
      }
    return ResolvedBadge(
      style: style, position: override.position(over: settings[kind].position), label: label,
      isVisible: settings.badgeEnabled && enabled && style.isVisible)
  }
}
