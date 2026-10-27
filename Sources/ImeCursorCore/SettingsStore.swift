import Foundation

public protocol KeyValueStorage {
  func data(forKey key: String) -> Data?
  func setData(_ data: Data, forKey key: String)
}

extension UserDefaults: KeyValueStorage {
  public func setData(_ data: Data, forKey key: String) {
    set(data, forKey: key)
  }
}

public struct SettingsStore {
  public static let key = "settings"
  public static let backupKey = "settings.corruptBackup"

  private let storage: KeyValueStorage

  public init(storage: KeyValueStorage) {
    self.storage = storage
  }

  public func load() -> AppSettings {
    guard let data = storage.data(forKey: Self.key) else { return .initial }
    guard let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
      storage.setData(data, forKey: Self.backupKey)
      return .initial
    }
    return settings.sanitized()
  }

  public func save(_ settings: AppSettings) {
    guard let data = try? JSONEncoder().encode(settings) else { return }
    storage.setData(data, forKey: Self.key)
  }
}
