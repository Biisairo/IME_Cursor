public struct ResolvedBadge: Equatable, Sendable {
  public var style: BadgeStyle
  public var label: String
  public var isVisible: Bool

  public init(style: BadgeStyle, label: String, isVisible: Bool) {
    self.style = style
    self.label = label
    self.isVisible = isVisible
  }
}

public enum StyleResolver {
  static let koreanBackground = RGBA(red: 0, green: 0.48, blue: 1, alpha: 0.85)

  public static func initialSettings(
    for info: InputSourceInfo, defaultStyle: BadgeStyle
  ) -> SourceSettings {
    let label = BadgeLabel.automatic(for: info)
    guard info.primaryLanguage == "ko" else {
      return SourceSettings(label: label, mode: .useDefault)
    }
    var style = defaultStyle
    style.backgroundColor = koreanBackground
    return SourceSettings(label: label, mode: .custom(style))
  }

  public static func sourceSettings(
    for info: InputSourceInfo, in settings: AppSettings
  ) -> SourceSettings {
    settings.sources[info.id]
      ?? initialSettings(for: info, defaultStyle: settings.defaultStyle)
  }

  public static func style(for source: SourceSettings, in settings: AppSettings) -> BadgeStyle {
    switch source.mode {
    case .useDefault: settings.defaultStyle
    case .custom(let style): style
    }
  }

  public static func resolve(current: InputSourceInfo?, settings: AppSettings) -> ResolvedBadge {
    guard let current else {
      let style = settings.defaultStyle
      return ResolvedBadge(
        style: style, label: BadgeLabel.unknown,
        isVisible: settings.badgeEnabled && style.isVisible)
    }
    let source = sourceSettings(for: current, in: settings)
    let style = style(for: source, in: settings)
    return ResolvedBadge(
      style: style, label: source.label, isVisible: settings.badgeEnabled && style.isVisible)
  }
}
