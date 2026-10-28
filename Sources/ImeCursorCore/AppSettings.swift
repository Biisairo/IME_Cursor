public enum BadgeKind: String, Codable, CaseIterable, Sendable {
  case cursor
  case caret
}

/// 캐럿 배지 표시 조건(FR-CARET-1).
public enum CaretCondition: String, Codable, CaseIterable, Sendable {
  case off
  case whenCursorHidden
  case always
}

/// 입력 소스별 설정. 표시 글자는 두 배지가 함께 쓴다. 덮어쓰기가 nil이면 초기값(FR-SRC-7)을 쓴다.
public struct SourceSettings: Codable, Equatable, Hashable, Sendable {
  public var label: String
  public var cursor: StyleOverride?
  public var caret: StyleOverride?

  public init(label: String, cursor: StyleOverride?, caret: StyleOverride?) {
    self.label = label
    self.cursor = cursor
    self.caret = caret
  }

  public subscript(kind: BadgeKind) -> StyleOverride? {
    get {
      switch kind {
      case .cursor: cursor
      case .caret: caret
      }
    }
    set {
      switch kind {
      case .cursor: cursor = newValue
      case .caret: caret = newValue
      }
    }
  }

  func sanitized() -> SourceSettings {
    SourceSettings(
      label: BadgeLabel.normalized(label), cursor: cursor?.clamped(), caret: caret?.clamped())
  }
}

/// 배지별 위치 기본값과 동작 설정.
public struct BadgeSettings: Codable, Equatable, Sendable {
  public var position: BadgePosition
  public var behavior: BehaviorSettings

  public init(position: BadgePosition, behavior: BehaviorSettings) {
    self.position = position
    self.behavior = behavior
  }
}

public struct AppSettings: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 4

  public static let initial = AppSettings(
    schemaVersion: currentSchemaVersion, badgeEnabled: true, cursorEnabled: true,
    caretCondition: .off, defaultStyle: .initial,
    cursor: BadgeSettings(position: .cursorInitial, behavior: .initial),
    caret: BadgeSettings(position: .caretInitial, behavior: .initial), sources: [:])

  public var schemaVersion: Int
  public var badgeEnabled: Bool
  public var cursorEnabled: Bool
  public var caretCondition: CaretCondition
  public var defaultStyle: BadgeStyle
  public var cursor: BadgeSettings
  public var caret: BadgeSettings
  public var sources: [String: SourceSettings]

  public init(
    schemaVersion: Int, badgeEnabled: Bool, cursorEnabled: Bool, caretCondition: CaretCondition,
    defaultStyle: BadgeStyle, cursor: BadgeSettings, caret: BadgeSettings,
    sources: [String: SourceSettings]
  ) {
    self.schemaVersion = schemaVersion
    self.badgeEnabled = badgeEnabled
    self.cursorEnabled = cursorEnabled
    self.caretCondition = caretCondition
    self.defaultStyle = defaultStyle
    self.cursor = cursor
    self.caret = caret
    self.sources = sources
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion, badgeEnabled, cursorEnabled, caretCondition, defaultStyle, cursor, caret
    case sources
  }

  /// 스키마 버전 3 이하는 FR-STORE-8에 따라 바꿔 읽는다.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let version = try c.decode(Int.self, forKey: .schemaVersion)
    guard version >= 4 else {
      self = try LegacySettings(from: decoder).migrated()
      return
    }
    schemaVersion = version
    badgeEnabled = try c.decode(Bool.self, forKey: .badgeEnabled)
    cursorEnabled = try c.decode(Bool.self, forKey: .cursorEnabled)
    caretCondition = try c.decode(CaretCondition.self, forKey: .caretCondition)
    defaultStyle = try c.decode(BadgeStyle.self, forKey: .defaultStyle)
    cursor = try c.decode(BadgeSettings.self, forKey: .cursor)
    caret = try c.decode(BadgeSettings.self, forKey: .caret)
    sources = try c.decode([String: SourceSettings].self, forKey: .sources)
  }

  public subscript(kind: BadgeKind) -> BadgeSettings {
    get {
      switch kind {
      case .cursor: cursor
      case .caret: caret
      }
    }
    set {
      switch kind {
      case .cursor: cursor = newValue
      case .caret: caret = newValue
      }
    }
  }

  public func sanitized() -> AppSettings {
    var s = self
    s.schemaVersion = Self.currentSchemaVersion
    s.defaultStyle = defaultStyle.clamped()
    for kind in BadgeKind.allCases {
      s[kind].position = self[kind].position.clamped()
      s[kind].behavior = Self.behavior(self[kind].behavior, for: kind)
    }
    s.sources = sources.mapValues { $0.sanitized() }
    return s
  }

  /// 캐럿 배지에는 "멈추면 흐리게"가 없다(FR-MODE-1).
  private static func behavior(_ behavior: BehaviorSettings, for kind: BadgeKind)
    -> BehaviorSettings
  {
    var b = behavior.clamped()
    if kind == .caret && b.displayMode == .dimWhenIdle {
      b.displayMode = .always
    }
    return b
  }

  public mutating func updateDefaultStyle(_ transform: (inout BadgeStyle) -> Void) {
    transform(&defaultStyle)
    defaultStyle = defaultStyle.clamped()
  }

  public mutating func updatePosition(_ kind: BadgeKind, _ transform: (inout BadgePosition) -> Void) {
    transform(&self[kind].position)
    self[kind].position = self[kind].position.clamped()
  }

  public mutating func updateBehavior(
    _ kind: BadgeKind, _ transform: (inout BehaviorSettings) -> Void
  ) {
    transform(&self[kind].behavior)
    self[kind].behavior = Self.behavior(self[kind].behavior, for: kind)
  }

  /// 기본 스타일과 두 위치 기본값을 초기값으로 되돌린다(FR-SRC-9).
  public mutating func resetDefaultStyle() {
    defaultStyle = .initial
    cursor.position = .cursorInitial
    caret.position = .caretInitial
  }

  public mutating func updateSource(
    _ info: InputSourceInfo, _ transform: (inout SourceSettings) -> Void
  ) {
    var s = StyleResolver.sourceSettings(for: info, in: self)
    transform(&s)
    sources[info.id] = s.sanitized()
  }

  /// 처음 덮어쓰면 초기 덮어쓰기(FR-SRC-7)에서 시작한다.
  public mutating func updateOverride(
    _ kind: BadgeKind, for info: InputSourceInfo, _ transform: (inout StyleOverride) -> Void
  ) {
    var o = StyleResolver.override(kind, for: info, in: self)
    transform(&o)
    updateSource(info) { $0[kind] = o }
  }

  public mutating func resetOverride(_ kind: BadgeKind, for info: InputSourceInfo) {
    updateSource(info) { $0[kind] = nil }
  }
}
