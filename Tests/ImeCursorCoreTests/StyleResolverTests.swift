import Testing
import ImeCursorCore

@Suite struct StyleOverrideTests {
  @Test func emptyOverrideKeepsBase() {
    let o = StyleOverride()
    #expect(o.isEmpty)
    #expect(o.style(over: .initial) == .initial)
    #expect(o.position(over: .caretInitial) == .caretInitial)
  }

  @Test func onlySetFieldsReplaceBase() {
    var o = StyleOverride()
    o.fontSize = 20
    o.anchor = .top
    var base = BadgeStyle.initial
    base.width = 40
    let style = o.style(over: base)
    #expect(style.fontSize == 20)
    #expect(style.width == 40)
    let position = o.position(over: .caretInitial)
    #expect(position == BadgePosition(anchor: .top, offsetX: 0, offsetY: -2))
    #expect(!o.isEmpty)
  }

  @Test func everyFieldCanBeOverridden() {
    var o = StyleOverride()
    o.isVisible = false
    o.fontSize = 13
    o.fontWeight = .bold
    o.textColor = RGBA(red: 1, green: 0, blue: 0, alpha: 1)
    o.backgroundColor = RGBA(red: 0, green: 1, blue: 0, alpha: 1)
    o.width = 30
    o.height = 25
    o.cornerRadius = 2
    o.backgroundBorderWidth = 3
    o.backgroundBorderColor = RGBA(red: 0, green: 0, blue: 1, alpha: 1)
    o.textBorderWidth = 4
    o.textBorderColor = RGBA(red: 1, green: 1, blue: 0, alpha: 1)
    o.offsetX = -5
    o.offsetY = 7
    let s = o.style(over: .initial)
    #expect(!s.isVisible)
    #expect(s.fontSize == 13)
    #expect(s.fontWeight == .bold)
    #expect(s.textColor == RGBA(red: 1, green: 0, blue: 0, alpha: 1))
    #expect(s.backgroundColor == RGBA(red: 0, green: 1, blue: 0, alpha: 1))
    #expect(s.width == 30)
    #expect(s.height == 25)
    #expect(s.cornerRadius == 2)
    #expect(s.backgroundBorderWidth == 3)
    #expect(s.backgroundBorderColor == RGBA(red: 0, green: 0, blue: 1, alpha: 1))
    #expect(s.textBorderWidth == 4)
    #expect(s.textBorderColor == RGBA(red: 1, green: 1, blue: 0, alpha: 1))
    let p = o.position(over: .cursorInitial)
    #expect(p == BadgePosition(anchor: .bottomRight, offsetX: -5, offsetY: 7))
  }

  @Test func clampedOnlyTouchesSetValues() {
    var o = StyleOverride()
    o.fontSize = 500
    o.offsetX = -999
    let c = o.clamped()
    #expect(c.fontSize == 72)
    #expect(c.offsetX == -200)
    #expect(c.width == nil)
  }

  @Test func differenceKeepsOnlyChangedFields() {
    var target = BadgeStyle.initial
    target.backgroundColor = RGBA(red: 0, green: 0.48, blue: 1, alpha: 0.85)
    target.height = 30
    let d = StyleOverride.difference(from: .initial, to: target)
    var expected = StyleOverride()
    expected.backgroundColor = target.backgroundColor
    expected.height = 30
    #expect(d == expected)
    #expect(StyleOverride.difference(from: .initial, to: .initial).isEmpty)
  }
}

@Suite struct StyleResolverTests {
  let korean = InputSourceInfo(
    id: "com.apple.inputmethod.Korean.2SetKorean", localizedName: "2-Set Korean", language: "ko")
  let abc = InputSourceInfo(id: "com.apple.keylayout.ABC", localizedName: "ABC", language: "en")
  let blue = RGBA(red: 0, green: 0.48, blue: 1, alpha: 0.85)

  @Test func unknownCurrentSourceUsesDefaultStyleAndQuestionMark() {
    var settings = AppSettings.initial
    settings.defaultStyle.fontSize = 20
    let r = StyleResolver.resolve(.cursor, current: nil, settings: settings)
    #expect(r.label == "?")
    #expect(r.style == settings.defaultStyle)
    #expect(r.position == .cursorInitial)
    #expect(r.isVisible)
  }

  @Test(arguments: BadgeKind.allCases)
  func unstoredKoreanSourceOverridesOnlyBackground(kind: BadgeKind) {
    var expected = StyleOverride()
    expected.backgroundColor = blue
    #expect(StyleResolver.override(kind, for: korean, in: .initial) == expected)
    #expect(StyleResolver.sourceSettings(for: korean, in: .initial).label == "한")
  }

  @Test func unstoredKoreanSourceFollowsDefaultStyleChanges() {
    var settings = AppSettings.initial
    settings.updateDefaultStyle { $0.fontSize = 30 }
    let r = StyleResolver.resolve(.cursor, current: korean, settings: settings)
    #expect(r.style.fontSize == 30)
    #expect(r.style.backgroundColor == blue)
  }

  @Test func unstoredNonKoreanSourceHasNoOverride() {
    #expect(StyleResolver.override(.caret, for: abc, in: .initial).isEmpty)
    #expect(StyleResolver.sourceSettings(for: abc, in: .initial).label == "A")
  }

  @Test func overriddenFieldStaysWhenDefaultChanges() {
    var settings = AppSettings.initial
    settings.updateOverride(.cursor, for: abc) { $0.width = 40 }
    settings.updateDefaultStyle {
      $0.width = 50
      $0.height = 33
    }
    let r = StyleResolver.resolve(.cursor, current: abc, settings: settings)
    #expect(r.style.width == 40)
    #expect(r.style.height == 33)
  }

  @Test func overrideKeepsValueEqualToDefault() {
    var settings = AppSettings.initial
    settings.updateOverride(.cursor, for: abc) { $0.width = BadgeStyle.initial.width }
    settings.updateDefaultStyle { $0.width = 50 }
    #expect(StyleResolver.resolve(.cursor, current: abc, settings: settings).style.width == BadgeStyle.initial.width)
  }

  @Test func badgesHaveIndependentOverrides() {
    var settings = AppSettings.initial
    settings.updateOverride(.caret, for: abc) { $0.fontSize = 20 }
    #expect(StyleResolver.resolve(.caret, current: abc, settings: settings).style.fontSize == 20)
    #expect(StyleResolver.resolve(.cursor, current: abc, settings: settings).style.fontSize == 12)
  }

  @Test func firstOverrideOfKoreanStartsFromInitialOverride() {
    var settings = AppSettings.initial
    settings.updateOverride(.caret, for: korean) { $0.fontSize = 20 }
    let r = StyleResolver.resolve(.caret, current: korean, settings: settings)
    #expect(r.style.fontSize == 20)
    #expect(r.style.backgroundColor == blue)
  }

  @Test func positionComesFromBadgeDefaultUnlessOverridden() {
    var settings = AppSettings.initial
    settings.updatePosition(.caret) { $0.anchor = .top }
    #expect(StyleResolver.resolve(.caret, current: abc, settings: settings).position.anchor == .top)
    #expect(StyleResolver.resolve(.cursor, current: abc, settings: settings).position == .cursorInitial)
    settings.updateOverride(.caret, for: abc) { $0.offsetY = -4 }
    #expect(
      StyleResolver.resolve(.caret, current: abc, settings: settings).position
        == BadgePosition(anchor: .top, offsetX: 0, offsetY: -4))
  }

  @Test func labelIsSharedByBothBadges() {
    var settings = AppSettings.initial
    settings.updateSource(abc) { $0.label = "EN" }
    #expect(StyleResolver.resolve(.cursor, current: abc, settings: settings).label == "EN")
    #expect(StyleResolver.resolve(.caret, current: abc, settings: settings).label == "EN")
  }

  @Test func updateSourceNormalizesLabelAndClampsOverrides() {
    var settings = AppSettings.initial
    settings.updateSource(korean) { $0.label = "123456789" }
    settings.updateOverride(.cursor, for: korean) { $0.fontSize = 500 }
    #expect(settings.sources[korean.id]?.label == "12345678")
    #expect(settings.sources[korean.id]?.cursor?.fontSize == 72)
  }

  @Test func updatePositionClamps() {
    var settings = AppSettings.initial
    settings.updatePosition(.cursor) { $0.offsetX = -1000 }
    #expect(settings.cursor.position.offsetX == -200)
  }

  @Test func clearingOneFieldFallsBackToDefault() {
    var settings = AppSettings.initial
    settings.updateOverride(.cursor, for: abc) {
      $0.width = 40
      $0.height = 30
    }
    settings.updateOverride(.cursor, for: abc) { $0.width = nil }
    let r = StyleResolver.resolve(.cursor, current: abc, settings: settings)
    #expect(r.style.width == BadgeStyle.initial.width)
    #expect(r.style.height == 30)
  }

  @Test func resetOverrideRestoresInitialOverrideOfThatBadgeOnly() {
    var settings = AppSettings.initial
    settings.updateSource(korean) { $0.label = "K" }
    settings.updateOverride(.cursor, for: korean) { $0.backgroundColor = nil }
    settings.updateOverride(.caret, for: korean) { $0.fontSize = 20 }
    settings.resetOverride(.cursor, for: korean)
    #expect(StyleResolver.resolve(.cursor, current: korean, settings: settings).style.backgroundColor == blue)
    #expect(StyleResolver.resolve(.caret, current: korean, settings: settings).style.fontSize == 20)
    #expect(StyleResolver.resolve(.cursor, current: korean, settings: settings).label == "K")
  }

  @Test func resetDefaultStyleRestoresStyleAndBothPositions() {
    var settings = AppSettings.initial
    settings.updateDefaultStyle { $0.fontSize = 40 }
    settings.updatePosition(.cursor) { $0.anchor = .top }
    settings.updatePosition(.caret) { $0.offsetX = 9 }
    settings.resetDefaultStyle()
    #expect(settings.defaultStyle == .initial)
    #expect(settings.cursor.position == .cursorInitial)
    #expect(settings.caret.position == .caretInitial)
  }

  @Test func storedSettingsForDisabledSourceAreKept() {
    var settings = AppSettings.initial
    settings.updateSource(abc) { $0.label = "Z" }
    let enabledNow = [korean]
    #expect(!enabledNow.contains(abc))
    #expect(StyleResolver.resolve(.cursor, current: abc, settings: settings).label == "Z")
  }

  @Test func hiddenWhenStyleIsInvisible() {
    var settings = AppSettings.initial
    settings.updateDefaultStyle { $0.isVisible = false }
    #expect(!StyleResolver.resolve(.cursor, current: abc, settings: settings).isVisible)
  }

  @Test func hiddenWhenBadgeIsGloballyDisabled() {
    var settings = AppSettings.initial
    settings.badgeEnabled = false
    settings.caretCondition = .always
    #expect(!StyleResolver.resolve(.cursor, current: korean, settings: settings).isVisible)
    #expect(!StyleResolver.resolve(.caret, current: korean, settings: settings).isVisible)
    #expect(!StyleResolver.resolve(.cursor, current: nil, settings: settings).isVisible)
  }

  @Test func cursorBadgeCanBeTurnedOffAlone() {
    var settings = AppSettings.initial
    settings.cursorEnabled = false
    settings.caretCondition = .always
    #expect(!StyleResolver.resolve(.cursor, current: abc, settings: settings).isVisible)
    #expect(StyleResolver.resolve(.caret, current: abc, settings: settings).isVisible)
  }

  @Test func caretBadgeIsHiddenWhenConditionIsOff() {
    #expect(AppSettings.initial.caretCondition == .off)
    #expect(!StyleResolver.resolve(.caret, current: abc, settings: .initial).isVisible)
  }
}
