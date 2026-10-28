import CoreGraphics
import Testing
import ImeCursorCore

/// 가짜 포커스 요소. 좌표는 AX 좌표(주 화면 왼쪽 위 원점, Y 아래쪽)이다.
struct FakeText: FocusedText {
  var hasEditableAncestor = false
  var isSelectedRangeSettable = true
  var frame: CGRect? = CGRect(x: 100, y: 100, width: 400, height: 200)
  var characterCount: Int? = 10
  var selectedRange: TextSpan? = TextSpan(location: 4, length: 0)
  var rangeBounds: [TextSpan: CGRect] = [:]
  var collapsedMarker: CGRect?
  var markerBeforeEnd: CGRect?

  func bounds(for range: TextSpan) -> CGRect? { rangeBounds[range] }
  func collapsedMarkerBounds() -> CGRect? { collapsedMarker }
  func markerBoundsBeforeEnd() -> CGRect? { markerBeforeEnd }
}

@Suite struct CaretLocatorTests {
  let screens = [CGRect(x: 0, y: 0, width: 2000, height: 1200)]

  private func caret(_ text: FakeText) -> CGRect? {
    CaretLocator.caret(in: text, screens: screens)
  }

  @Test func editableWhenEditableAncestorExists() {
    #expect(CaretLocator.isEditable(FakeText(hasEditableAncestor: true, isSelectedRangeSettable: false)))
  }

  @Test func editableWhenSelectedRangeIsSettable() {
    #expect(CaretLocator.isEditable(FakeText(hasEditableAncestor: false, isSelectedRangeSettable: true)))
  }

  @Test func notEditableWithoutEitherSignal() {
    let text = FakeText(
      hasEditableAncestor: false, isSelectedRangeSettable: false,
      collapsedMarker: CGRect(x: 120, y: 150, width: 0, height: 20))
    #expect(!CaretLocator.isEditable(text))
    #expect(caret(text) == nil)
  }

  @Test func collapsedRangeAtSelectionEndComesFirst() {
    var text = FakeText(selectedRange: TextSpan(location: 2, length: 3))
    text.rangeBounds[TextSpan(location: 5, length: 0)] = CGRect(x: 150, y: 150, width: 0, height: 20)
    text.rangeBounds[TextSpan(location: 4, length: 1)] = CGRect(x: 140, y: 150, width: 8, height: 20)
    #expect(caret(text) == CGRect(x: 150, y: 150, width: 0, height: 20))
  }

  @Test func previousCharacterRightEdgeIsSecond() {
    var text = FakeText()
    text.rangeBounds[TextSpan(location: 3, length: 1)] = CGRect(x: 140, y: 150, width: 8, height: 20)
    text.rangeBounds[TextSpan(location: 4, length: 1)] = CGRect(x: 148, y: 150, width: 8, height: 20)
    #expect(caret(text) == CGRect(x: 148, y: 150, width: 0, height: 20))
  }

  @Test func nextCharacterLeftEdgeIsThird() {
    var text = FakeText(selectedRange: TextSpan(location: 0, length: 0))
    text.rangeBounds[TextSpan(location: 0, length: 1)] = CGRect(x: 110, y: 150, width: 8, height: 20)
    #expect(caret(text) == CGRect(x: 110, y: 150, width: 0, height: 20))
  }

  @Test func noPreviousCharacterQueryAtStart() {
    var text = FakeText(selectedRange: TextSpan(location: 0, length: 0))
    text.rangeBounds[TextSpan(location: -1, length: 1)] = CGRect(x: 110, y: 150, width: 8, height: 20)
    #expect(caret(text) == nil)
  }

  @Test func markerIsUsedWhenRangeFails() {
    var text = FakeText()
    text.collapsedMarker = CGRect(x: 160, y: 150, width: 0, height: 19)
    #expect(caret(text) == CGRect(x: 160, y: 150, width: 0, height: 19))
  }

  @Test func markerBeforeEndUsesRightEdge() {
    var text = FakeText()
    text.markerBeforeEnd = CGRect(x: 160, y: 150, width: 9, height: 19)
    #expect(caret(text) == CGRect(x: 169, y: 150, width: 0, height: 19))
  }

  @Test func zeroXIsInvalid() {
    var text = FakeText()
    text.collapsedMarker = CGRect(x: 0, y: 150, width: 0, height: 0)
    #expect(caret(text) == nil)
  }

  @Test func pointOutsideScreensIsInvalid() {
    var text = FakeText(frame: nil)
    text.collapsedMarker = CGRect(x: 2500, y: 150, width: 0, height: 20)
    #expect(caret(text) == nil)
  }

  @Test func wideRectIsInvalid() {
    var text = FakeText()
    text.collapsedMarker = CGRect(x: 100, y: 100, width: 400, height: 22)
    #expect(caret(text) == nil)
  }

  @Test func pointOutsideFocusedElementIsInvalid() {
    var text = FakeText()
    text.collapsedMarker = CGRect(x: 1000, y: 150, width: 0, height: 0)
    #expect(caret(text) == nil)
  }

  @Test func pointNearFocusedElementEdgeIsValid() {
    var text = FakeText()
    text.collapsedMarker = CGRect(x: 503, y: 150, width: 0, height: 20)
    #expect(caret(text) == CGRect(x: 503, y: 150, width: 0, height: 20))
  }

  @Test func zeroSizeRectIsValid() {
    var text = FakeText()
    text.collapsedMarker = CGRect(x: 160, y: 150, width: 0, height: 0)
    #expect(caret(text) == CGRect(x: 160, y: 150, width: 0, height: 0))
  }

  @Test func withoutFrameOnlyScreenCheckApplies() {
    var text = FakeText(frame: nil)
    text.collapsedMarker = CGRect(x: 1500, y: 150, width: 0, height: 20)
    #expect(caret(text) == CGRect(x: 1500, y: 150, width: 0, height: 20))
  }

  @Test func singleCellElementIsUsedAsCaret() {
    let text = FakeText(frame: CGRect(x: 154, y: 270, width: 9, height: 19), characterCount: 0)
    #expect(caret(text) == CGRect(x: 154, y: 270, width: 9, height: 19))
  }

  @Test func singleLineInputIsNotUsedAsCaret() {
    let text = FakeText(frame: CGRect(x: 100, y: 100, width: 522, height: 22), characterCount: 5)
    #expect(caret(text) == nil)
  }

  @Test func tallNarrowElementIsNotUsedAsCaret() {
    let text = FakeText(frame: CGRect(x: 100, y: 100, width: 20, height: 41), characterCount: 5)
    #expect(caret(text) == nil)
  }

  @Test func emptyElementUsesTopLeftStart() {
    let text = FakeText(frame: CGRect(x: 100, y: 100, width: 400, height: 50), characterCount: 0)
    #expect(caret(text) == CGRect(x: 100, y: 100, width: 0, height: 20))
  }

  @Test func nothingFoundMeansNoCaret() {
    #expect(caret(FakeText()) == nil)
    #expect(caret(FakeText(frame: nil, characterCount: 0)) == nil)
  }
}

@Suite struct CaretVisibilityTests {
  private func badge(_ visible: Bool = true) -> ResolvedBadge {
    ResolvedBadge(style: .initial, position: .caretInitial, label: "A", isVisible: visible)
  }

  @Test func alwaysShowsWhenCaretExists() {
    #expect(CaretVisibility.shouldShow(badge: badge(), condition: .always, cursorVisible: true, hasCaret: true, capturing: false))
  }

  @Test func whenCursorHiddenNeedsHiddenCursor() {
    #expect(!CaretVisibility.shouldShow(badge: badge(), condition: .whenCursorHidden, cursorVisible: true, hasCaret: true, capturing: false))
    #expect(CaretVisibility.shouldShow(badge: badge(), condition: .whenCursorHidden, cursorVisible: false, hasCaret: true, capturing: false))
  }

  @Test func offNeverShows() {
    #expect(!CaretVisibility.shouldShow(badge: badge(), condition: .off, cursorVisible: false, hasCaret: true, capturing: false))
  }

  @Test func hiddenWithoutCaret() {
    #expect(!CaretVisibility.shouldShow(badge: badge(), condition: .always, cursorVisible: true, hasCaret: false, capturing: false))
  }

  @Test func hiddenWhileCapturing() {
    #expect(!CaretVisibility.shouldShow(badge: badge(), condition: .always, cursorVisible: true, hasCaret: true, capturing: true))
  }

  @Test func hiddenWhenBadgeIsNotVisible() {
    #expect(!CaretVisibility.shouldShow(badge: badge(false), condition: .always, cursorVisible: true, hasCaret: true, capturing: false))
  }
}

@Suite struct PollingPolicyTests {
  @Test func normalIntervalWhenCaretBadgeIsOff() {
    #expect(PollingPolicy.interval(caretActive: false, sinceKey: 0, sinceFocusChange: 0) == 0.1)
  }

  @Test func fastIntervalRightAfterTypingOrFocusChange() {
    #expect(PollingPolicy.interval(caretActive: true, sinceKey: 0.5, sinceFocusChange: 10) == 0.016)
    #expect(PollingPolicy.interval(caretActive: true, sinceKey: 10, sinceFocusChange: 0.99) == 0.016)
  }

  @Test func normalIntervalAfterOneSecondOfQuiet() {
    #expect(PollingPolicy.interval(caretActive: true, sinceKey: 1, sinceFocusChange: 1) == 0.1)
  }
}

@Suite struct ChromiumBrowsersTests {
  @Test(arguments: [
    "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
    "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser",
    "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
  ])
  func listedBundlesAreChromium(id: String) {
    #expect(ChromiumBrowsers.contains(bundleID: id))
  }

  @Test func otherBundlesAreNot() {
    #expect(!ChromiumBrowsers.contains(bundleID: "com.apple.Safari"))
    #expect(!ChromiumBrowsers.contains(bundleID: "com.microsoft.VSCode"))
    #expect(!ChromiumBrowsers.contains(bundleID: nil))
  }
}
