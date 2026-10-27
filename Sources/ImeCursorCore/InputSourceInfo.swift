public struct InputSourceInfo: Equatable, Hashable, Sendable, Identifiable {
  public var id: String
  public var localizedName: String?
  public var language: String?

  public init(id: String, localizedName: String?, language: String?) {
    self.id = id
    self.localizedName = localizedName
    self.language = language
  }

  var primaryLanguage: String? {
    guard let language, !language.isEmpty else { return nil }
    let subtag = language.split(whereSeparator: { $0 == "-" || $0 == "_" }).first
    return subtag.map { $0.lowercased() }
  }
}

public protocol InputSourceProvider {
  func current() -> InputSourceInfo?
  func enabled() -> [InputSourceInfo]
}
