public enum BadgeLabel {
  public static let maxLength = 8
  public static let unknown = "?"
  public static let capsLockSymbol = "⇪"

  private static let languageLabels = ["ko": "한", "en": "A", "ja": "あ", "zh": "中"]

  public static func normalized(_ label: String) -> String {
    String(label.prefix(maxLength))
  }

  /// Caps Lock 표시는 그릴 때만 붙인다(FR-CAPS-2, 3).
  public static func display(_ label: String, capsLock: Bool) -> String {
    capsLock ? capsLockSymbol + label : label
  }

  public static func automatic(for info: InputSourceInfo) -> String {
    if let language = info.primaryLanguage {
      return languageLabels[language] ?? String(language.prefix(2)).uppercased()
    }
    if let first = info.localizedName?.first {
      return String(first)
    }
    return unknown
  }
}
