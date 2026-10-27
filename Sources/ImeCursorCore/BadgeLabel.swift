public enum BadgeLabel {
  public static let maxLength = 8
  public static let unknown = "?"

  private static let languageLabels = ["ko": "한", "en": "A", "ja": "あ", "zh": "中"]

  public static func normalized(_ label: String) -> String {
    String(label.prefix(maxLength))
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
