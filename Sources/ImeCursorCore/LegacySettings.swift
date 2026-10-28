/// 스키마 버전 3 이하의 저장값. 읽은 뒤 바로 현재 형식으로 바꾼다(FR-STORE-6, 7, 8).
struct LegacySettings: Decodable {
  struct Offset: Decodable {
    var offsetX: Double
    var offsetY: Double
  }

  /// 오프셋이 스타일 안에 있던 형식. 테두리 항목이 없으면 `BadgeStyle`이 초기값으로 채운다.
  struct Style: Decodable {
    var style: BadgeStyle
    var offset: Offset

    init(from decoder: Decoder) throws {
      style = try BadgeStyle(from: decoder)
      offset = try Offset(from: decoder)
    }
  }

  enum Mode: Decodable {
    case useDefault
    case custom(Style)
  }

  struct Source: Decodable {
    var label: String
    var mode: Mode
  }

  var badgeEnabled: Bool
  var behavior: BehaviorSettings?
  var defaultStyle: Style
  var sources: [String: Source]

  func migrated() -> AppSettings {
    let base = defaultStyle
    var settings = AppSettings.initial
    settings.badgeEnabled = badgeEnabled
    settings.defaultStyle = base.style
    settings.cursor = BadgeSettings(
      position: BadgePosition(
        anchor: .bottomRight, offsetX: base.offset.offsetX, offsetY: base.offset.offsetY),
      behavior: behavior ?? .initial)
    settings.sources = sources.mapValues { source in
      var cursor = StyleOverride()
      if case .custom(let custom) = source.mode {
        cursor = StyleOverride.difference(from: base.style, to: custom.style)
        if custom.offset.offsetX != base.offset.offsetX {
          cursor.offsetX = custom.offset.offsetX
        }
        if custom.offset.offsetY != base.offset.offsetY {
          cursor.offsetY = custom.offset.offsetY
        }
      }
      return SourceSettings(label: source.label, cursor: cursor, caret: nil)
    }
    return settings
  }
}
