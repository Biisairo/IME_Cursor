import Testing
import ImeCursorCore

@Suite struct BadgeLabelTests {
  private func info(_ language: String?, name: String? = "Name") -> InputSourceInfo {
    InputSourceInfo(id: "test.id", localizedName: name, language: language)
  }

  @Test(arguments: [
    ("ko", "한"), ("en", "A"), ("ja", "あ"), ("zh-Hans", "中"), ("zh-Hant", "中"),
    ("de", "DE"), ("fr", "FR"), ("ko-KR", "한"), ("en_US", "A"), ("haw", "HA"),
  ])
  func automaticLabelFromLanguage(language: String, expected: String) {
    #expect(BadgeLabel.automatic(for: info(language)) == expected)
  }

  @Test func automaticLabelFallsBackToFirstCharacterOfName() {
    #expect(BadgeLabel.automatic(for: info(nil, name: "Dvorak")) == "D")
    #expect(BadgeLabel.automatic(for: info("", name: "Colemak")) == "C")
  }

  @Test func automaticLabelIsQuestionMarkWithoutLanguageAndName() {
    #expect(BadgeLabel.automatic(for: info(nil, name: nil)) == "?")
    #expect(BadgeLabel.automatic(for: info(nil, name: "")) == "?")
  }

  @Test func normalizedKeepsUpToEightCharacters() {
    #expect(BadgeLabel.normalized("") == "")
    #expect(BadgeLabel.normalized("12345678") == "12345678")
    #expect(BadgeLabel.normalized("123456789") == "12345678")
  }

  @Test func normalizedCountsGraphemesNotScalars() {
    let decomposed = "\u{1100}\u{1161}\u{11A8}"
    let label = String(repeating: decomposed, count: 9)
    #expect(BadgeLabel.normalized(label).count == 8)
    let family = "👨‍👩‍👧"
    #expect(BadgeLabel.normalized(String(repeating: family, count: 10)) == String(repeating: family, count: 8))
  }
}
