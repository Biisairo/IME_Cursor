public enum LaunchMode: Equatable, Sendable {
  case badge
  case settings

  public static let settingsFlag = "--settings"

  public init(arguments: [String]) {
    self = arguments.dropFirst().contains(Self.settingsFlag) ? .settings : .badge
  }
}
