import Foundation
import Testing
import ImeCursorCore

final class MemoryStorage: KeyValueStorage {
  var values: [String: Data] = [:]

  func data(forKey key: String) -> Data? { values[key] }

  func setData(_ data: Data, forKey key: String) { values[key] = data }
}

@Suite struct SettingsStoreTests {
  @Test func missingDataLoadsInitialSettings() {
    let store = SettingsStore(storage: MemoryStorage())
    #expect(store.load() == .initial)
  }

  @Test func savedSettingsRoundTrip() {
    let storage = MemoryStorage()
    let store = SettingsStore(storage: storage)
    var settings = AppSettings.initial
    settings.badgeEnabled = false
    settings.cursorEnabled = false
    settings.caretCondition = .whenCursorHidden
    settings.updateDefaultStyle { $0.fontWeight = .bold }
    settings.updatePosition(.caret) { $0.anchor = .topLeft }
    settings.updateBehavior(.caret) { $0.displayMode = .afterSwitch }
    settings.sources["a"] = SourceSettings(label: "가", cursor: StyleOverride(), caret: nil)
    var o = StyleOverride()
    o.anchor = .bottom
    o.width = 30
    settings.sources["b"] = SourceSettings(label: "", cursor: nil, caret: o)
    store.save(settings)
    #expect(SettingsStore(storage: storage).load() == settings)
  }

  @Test func savedJSONContainsSchemaVersion() throws {
    let storage = MemoryStorage()
    SettingsStore(storage: storage).save(.initial)
    let data = try #require(storage.values[SettingsStore.key])
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["schemaVersion"] as? Int == 4)
    #expect(AppSettings.currentSchemaVersion == 4)
  }

  @Test func overrideStoresOnlySetFields() throws {
    var o = StyleOverride()
    o.width = 30
    let object = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(o)) as? [String: Any])
    #expect(object.keys.sorted() == ["width"])
  }

  @Test func corruptedDataLoadsInitialAndBacksUpOriginal() {
    let storage = MemoryStorage()
    let garbage = Data("{not json".utf8)
    storage.values[SettingsStore.key] = garbage
    #expect(SettingsStore(storage: storage).load() == .initial)
    #expect(storage.values[SettingsStore.backupKey] == garbage)
  }

  @Test func outOfRangeStoredValuesAreClampedOnLoad() {
    let storage = MemoryStorage()
    var settings = AppSettings.initial
    settings.defaultStyle.fontSize = 999
    settings.caret.position.offsetX = 999
    settings.cursor.behavior.emphasisScale = 9
    var o = StyleOverride()
    o.width = -3
    settings.sources["x"] = SourceSettings(label: "1234567890", cursor: o, caret: nil)
    storage.values[SettingsStore.key] = try! JSONEncoder().encode(settings)
    let loaded = SettingsStore(storage: storage).load()
    #expect(loaded.defaultStyle.fontSize == 72)
    #expect(loaded.caret.position.offsetX == 200)
    #expect(loaded.cursor.behavior.emphasisScale == 3)
    #expect(loaded.sources["x"]?.label == "12345678")
    #expect(loaded.sources["x"]?.cursor?.width == 4)
  }

  @Test func caretDisplayModeCannotDimWhenIdle() {
    var settings = AppSettings.initial
    settings.updateBehavior(.caret) { $0.displayMode = .dimWhenIdle }
    #expect(settings.caret.behavior.displayMode == .always)
    settings.updateBehavior(.cursor) { $0.displayMode = .dimWhenIdle }
    #expect(settings.cursor.behavior.displayMode == .dimWhenIdle)
  }
}

/// 스키마 버전 3 이하 저장값의 변환(FR-STORE-6, 7, 8).
@Suite struct LegacyMigrationTests {
  let blue = RGBA(red: 0, green: 0.48, blue: 1, alpha: 0.85)

  private func color(_ c: RGBA) -> [String: Any] {
    ["red": c.red, "green": c.green, "blue": c.blue, "alpha": c.alpha]
  }

  private func style(
    _ s: BadgeStyle = .initial, offset: (Double, Double) = (16, 16), borders: Bool = true
  ) -> [String: Any] {
    var object: [String: Any] = [
      "isVisible": s.isVisible, "fontSize": s.fontSize, "fontWeight": s.fontWeight.rawValue,
      "textColor": color(s.textColor), "backgroundColor": color(s.backgroundColor),
      "width": s.width, "height": s.height, "cornerRadius": s.cornerRadius,
      "offsetX": offset.0, "offsetY": offset.1,
    ]
    if borders {
      object["backgroundBorderWidth"] = s.backgroundBorderWidth
      object["backgroundBorderColor"] = color(s.backgroundBorderColor)
      object["textBorderWidth"] = s.textBorderWidth
      object["textBorderColor"] = color(s.textBorderColor)
    }
    return object
  }

  private func behavior() -> [String: Any] {
    [
      "emphasisEnabled": true, "emphasisScale": 2.0, "emphasisDuration": 0.5,
      "displayMode": "dimWhenIdle", "delay": 3.0, "dimOpacity": 0.4,
    ]
  }

  private func load(_ object: [String: Any]) throws -> (AppSettings, MemoryStorage) {
    let storage = MemoryStorage()
    storage.values[SettingsStore.key] = try JSONSerialization.data(withJSONObject: object)
    return (SettingsStore(storage: storage).load(), storage)
  }

  private func version3(sources: [String: Any], defaultOffset: (Double, Double) = (16, 16)) -> [String: Any] {
    [
      "schemaVersion": 3, "badgeEnabled": false, "behavior": behavior(),
      "defaultStyle": style(offset: defaultOffset), "sources": sources,
    ]
  }

  @Test func behaviorBecomesCursorBehaviorAndCaretStartsInitial() throws {
    let (s, storage) = try load(version3(sources: [:]))
    #expect(storage.values[SettingsStore.backupKey] == nil)
    #expect(s.schemaVersion == 4)
    #expect(s.badgeEnabled == false)
    #expect(s.cursorEnabled)
    #expect(s.caretCondition == .off)
    #expect(s.cursor.behavior.emphasisEnabled)
    #expect(s.cursor.behavior.displayMode == .dimWhenIdle)
    #expect(s.cursor.behavior.delay == 3)
    #expect(s.caret.behavior == .initial)
    #expect(s.defaultStyle == .initial)
  }

  @Test func defaultOffsetBecomesCursorPositionWithBottomRight() throws {
    let (s, _) = try load(version3(sources: [:], defaultOffset: (-8, 30)))
    #expect(s.cursor.position == BadgePosition(anchor: .bottomRight, offsetX: -8, offsetY: 30))
    #expect(s.caret.position == .caretInitial)
  }

  @Test func customStyleKeepsOnlyDifferencesAsCursorOverride() throws {
    var custom = BadgeStyle.initial
    custom.backgroundColor = blue
    custom.fontSize = 14
    let source: [String: Any] = ["label": "가", "mode": ["custom": ["_0": style(custom, offset: (16, 20))]]]
    let (s, _) = try load(version3(sources: ["ko": source]))
    var expected = StyleOverride()
    expected.backgroundColor = blue
    expected.fontSize = 14
    expected.offsetY = 20
    #expect(s.sources["ko"]?.label == "가")
    #expect(s.sources["ko"]?.cursor == expected)
    #expect(s.sources["ko"]?.cursor?.anchor == nil)
  }

  @Test func useDefaultBecomesEmptyCursorOverride() throws {
    let source: [String: Any] = ["label": "한", "mode": ["useDefault": [String: Any]()]]
    let (s, _) = try load(version3(sources: ["ko": source]))
    #expect(s.sources["ko"]?.cursor == StyleOverride())
  }

  @Test func caretOverrideOfMigratedSourceIsInitial() throws {
    let source: [String: Any] = ["label": "한", "mode": ["useDefault": [String: Any]()]]
    let (s, _) = try load(version3(sources: ["com.apple.inputmethod.Korean.2SetKorean": source]))
    let korean = InputSourceInfo(
      id: "com.apple.inputmethod.Korean.2SetKorean", localizedName: nil, language: "ko")
    #expect(s.sources[korean.id]?.caret == nil)
    #expect(StyleResolver.resolve(.caret, current: korean, settings: s).style.backgroundColor == blue)
    #expect(StyleResolver.resolve(.cursor, current: korean, settings: s).style.backgroundColor == BadgeStyle.initial.backgroundColor)
  }

  @Test func versionTwoWithoutBehaviorUsesInitialBehavior() throws {
    var object = version3(sources: [:])
    object["schemaVersion"] = 2
    object["behavior"] = nil
    let (s, storage) = try load(object)
    #expect(storage.values[SettingsStore.backupKey] == nil)
    #expect(s.cursor.behavior == .initial)
  }

  @Test func versionOneWithoutBordersUsesInitialBorders() throws {
    var custom = BadgeStyle.initial
    custom.height = 25
    var object = version3(sources: ["x": ["label": "X", "mode": ["custom": ["_0": style(custom, borders: false)]]]])
    object["schemaVersion"] = 1
    object["behavior"] = nil
    object["defaultStyle"] = style(borders: false)
    let (s, storage) = try load(object)
    #expect(storage.values[SettingsStore.backupKey] == nil)
    #expect(s.defaultStyle == .initial)
    var expected = StyleOverride()
    expected.height = 25
    #expect(s.sources["x"]?.cursor == expected)
  }
}
