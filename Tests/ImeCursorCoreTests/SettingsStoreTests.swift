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
    settings.updateDefaultStyle { $0.fontWeight = .bold }
    settings.sources["a"] = SourceSettings(label: "가", mode: .useDefault)
    settings.sources["b"] = SourceSettings(label: "", mode: .custom(.initial))
    store.save(settings)
    #expect(SettingsStore(storage: storage).load() == settings)
  }

  @Test func savedJSONContainsSchemaVersion() throws {
    let storage = MemoryStorage()
    SettingsStore(storage: storage).save(.initial)
    let data = try #require(storage.values[SettingsStore.key])
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["schemaVersion"] as? Int == AppSettings.currentSchemaVersion)
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
    var custom = BadgeStyle.initial
    custom.width = -3
    settings.sources["x"] = SourceSettings(label: "1234567890", mode: .custom(custom))
    let data = try! JSONEncoder().encode(settings)
    storage.values[SettingsStore.key] = data
    let loaded = SettingsStore(storage: storage).load()
    #expect(loaded.defaultStyle.fontSize == 72)
    #expect(loaded.sources["x"]?.label == "12345678")
    #expect(loaded.sources["x"]?.mode == .custom({ var s = custom; s.width = 4; return s }()))
  }
}
