import Testing
import ImeCursorCore

@Suite struct StyleResolverTests {
  let korean = InputSourceInfo(
    id: "com.apple.inputmethod.Korean.2SetKorean", localizedName: "2-Set Korean", language: "ko")
  let abc = InputSourceInfo(id: "com.apple.keylayout.ABC", localizedName: "ABC", language: "en")

  @Test func unknownCurrentSourceUsesDefaultStyleAndQuestionMark() {
    var settings = AppSettings.initial
    settings.defaultStyle.fontSize = 20
    let r = StyleResolver.resolve(current: nil, settings: settings)
    #expect(r.label == "?")
    #expect(r.style == settings.defaultStyle)
    #expect(r.isVisible)
  }

  @Test func unstoredKoreanSourceStartsAsBlueCustomStyle() {
    let s = StyleResolver.sourceSettings(for: korean, in: .initial)
    var expected = BadgeStyle.initial
    expected.backgroundColor = RGBA(red: 0, green: 0.48, blue: 1, alpha: 0.85)
    #expect(s.label == "한")
    #expect(s.mode == .custom(expected))
  }

  @Test func unstoredKoreanCustomStyleCopiesCurrentDefaultStyle() {
    var settings = AppSettings.initial
    settings.defaultStyle.fontSize = 30
    let s = StyleResolver.sourceSettings(for: korean, in: settings)
    guard case .custom(let style) = s.mode else {
      Issue.record("expected custom mode")
      return
    }
    #expect(style.fontSize == 30)
  }

  @Test func unstoredNonKoreanSourceUsesDefaultStyle() {
    let s = StyleResolver.sourceSettings(for: abc, in: .initial)
    #expect(s.label == "A")
    #expect(s.mode == .useDefault)
  }

  @Test func sourceUsingDefaultFollowsDefaultStyleChanges() {
    var settings = AppSettings.initial
    settings.defaultStyle.width = 40
    let r = StyleResolver.resolve(current: abc, settings: settings)
    #expect(r.style.width == 40)
    #expect(r.label == "A")
  }

  @Test func storedSettingsWinOverInitialSettings() {
    var settings = AppSettings.initial
    var custom = BadgeStyle.initial
    custom.height = 30
    settings.sources[abc.id] = SourceSettings(label: "EN", mode: .custom(custom))
    let r = StyleResolver.resolve(current: abc, settings: settings)
    #expect(r.label == "EN")
    #expect(r.style.height == 30)
  }

  @Test func switchingToCustomCopiesDefaultStyle() {
    var settings = AppSettings.initial
    settings.defaultStyle.fontSize = 18
    settings.setUsesDefaultStyle(false, for: abc)
    #expect(settings.sources[abc.id]?.mode == .custom(settings.defaultStyle))
    #expect(settings.sources[abc.id]?.label == "A")
  }

  @Test func switchingToDefaultDropsCustomStyle() {
    var settings = AppSettings.initial
    settings.setUsesDefaultStyle(true, for: korean)
    #expect(settings.sources[korean.id] == SourceSettings(label: "한", mode: .useDefault))
  }

  @Test func updateSourceStoresNormalizedLabelAndClampedStyle() {
    var settings = AppSettings.initial
    settings.updateSource(korean) { s in
      s.label = "123456789"
      if case .custom(var style) = s.mode {
        style.fontSize = 500
        s.mode = .custom(style)
      }
    }
    let stored = settings.sources[korean.id]
    #expect(stored?.label == "12345678")
    guard case .custom(let style)? = stored?.mode else {
      Issue.record("expected custom mode")
      return
    }
    #expect(style.fontSize == 72)
  }

  @Test func updateDefaultStyleClamps() {
    var settings = AppSettings.initial
    settings.updateDefaultStyle { $0.offsetX = -1000 }
    #expect(settings.defaultStyle.offsetX == -200)
  }

  @Test func resetSourceRemovesStoredSettings() {
    var settings = AppSettings.initial
    settings.updateSource(abc) { $0.label = "X" }
    settings.resetSource(abc)
    #expect(settings.sources[abc.id] == nil)
    #expect(StyleResolver.resolve(current: abc, settings: settings).label == "A")
  }

  @Test func resetDefaultStyleRestoresInitial() {
    var settings = AppSettings.initial
    settings.updateDefaultStyle { $0.fontSize = 40 }
    settings.resetDefaultStyle()
    #expect(settings.defaultStyle == .initial)
  }

  @Test func storedSettingsForDisabledSourceAreKept() {
    var settings = AppSettings.initial
    settings.updateSource(abc) { $0.label = "Z" }
    let enabledNow = [korean]
    #expect(!enabledNow.contains(abc))
    #expect(StyleResolver.resolve(current: abc, settings: settings).label == "Z")
  }

  @Test func hiddenWhenStyleIsInvisible() {
    var settings = AppSettings.initial
    settings.updateDefaultStyle { $0.isVisible = false }
    #expect(!StyleResolver.resolve(current: abc, settings: settings).isVisible)
  }

  @Test func hiddenWhenBadgeIsGloballyDisabled() {
    var settings = AppSettings.initial
    settings.badgeEnabled = false
    #expect(!StyleResolver.resolve(current: korean, settings: settings).isVisible)
    #expect(!StyleResolver.resolve(current: nil, settings: settings).isVisible)
  }
}
