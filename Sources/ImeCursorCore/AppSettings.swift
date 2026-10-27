public enum StyleMode: Codable, Equatable, Hashable, Sendable {
  case useDefault
  case custom(BadgeStyle)
}

public struct SourceSettings: Codable, Equatable, Hashable, Sendable {
  public var label: String
  public var mode: StyleMode

  public init(label: String, mode: StyleMode) {
    self.label = label
    self.mode = mode
  }

  func sanitized() -> SourceSettings {
    var s = self
    s.label = BadgeLabel.normalized(label)
    if case .custom(let style) = mode {
      s.mode = .custom(style.clamped())
    }
    return s
  }
}

public struct AppSettings: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 3

  public static let initial = AppSettings(
    schemaVersion: currentSchemaVersion, badgeEnabled: true, defaultStyle: .initial, sources: [:])

  public var schemaVersion: Int
  public var badgeEnabled: Bool
  public var behavior: BehaviorSettings
  public var defaultStyle: BadgeStyle
  public var sources: [String: SourceSettings]

  public init(
    schemaVersion: Int, badgeEnabled: Bool, defaultStyle: BadgeStyle,
    sources: [String: SourceSettings], behavior: BehaviorSettings = .initial
  ) {
    self.schemaVersion = schemaVersion
    self.badgeEnabled = badgeEnabled
    self.behavior = behavior
    self.defaultStyle = defaultStyle
    self.sources = sources
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion, badgeEnabled, behavior, defaultStyle, sources
  }

  /// 스키마 버전 1, 2에는 동작 설정이 없으므로 초기값으로 채운다(FR-STORE-7).
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
    badgeEnabled = try c.decode(Bool.self, forKey: .badgeEnabled)
    behavior = try c.decodeIfPresent(BehaviorSettings.self, forKey: .behavior) ?? .initial
    defaultStyle = try c.decode(BadgeStyle.self, forKey: .defaultStyle)
    sources = try c.decode([String: SourceSettings].self, forKey: .sources)
  }

  public func sanitized() -> AppSettings {
    var s = self
    s.schemaVersion = Self.currentSchemaVersion
    s.behavior = behavior.clamped()
    s.defaultStyle = defaultStyle.clamped()
    s.sources = sources.mapValues { $0.sanitized() }
    return s
  }

  public mutating func updateDefaultStyle(_ transform: (inout BadgeStyle) -> Void) {
    transform(&defaultStyle)
    defaultStyle = defaultStyle.clamped()
  }

  public mutating func updateBehavior(_ transform: (inout BehaviorSettings) -> Void) {
    transform(&behavior)
    behavior = behavior.clamped()
  }

  public mutating func resetDefaultStyle() {
    defaultStyle = .initial
  }

  public mutating func updateSource(
    _ info: InputSourceInfo, _ transform: (inout SourceSettings) -> Void
  ) {
    var s = StyleResolver.sourceSettings(for: info, in: self)
    transform(&s)
    sources[info.id] = s.sanitized()
  }

  public mutating func setUsesDefaultStyle(_ usesDefault: Bool, for info: InputSourceInfo) {
    let style = defaultStyle
    updateSource(info) { $0.mode = usesDefault ? .useDefault : .custom(style) }
  }

  public mutating func resetSource(_ info: InputSourceInfo) {
    sources[info.id] = nil
  }
}
