import Testing
import ImeCursorCore

@Suite struct LaunchModeTests {
  @Test func noArgumentsMeansBadge() {
    #expect(LaunchMode(arguments: ["/path/ImeCursor"]) == .badge)
  }

  @Test func settingsFlagMeansSettings() {
    #expect(LaunchMode(arguments: ["/path/ImeCursor", "--settings"]) == .settings)
    #expect(LaunchMode(arguments: ["/path/ImeCursor", "-NSDocumentRevisionsDebugMode", "YES", "--settings"]) == .settings)
  }

  @Test func otherArgumentsMeanBadge() {
    #expect(LaunchMode(arguments: ["/path/ImeCursor", "--setting", "settings"]) == .badge)
    #expect(LaunchMode(arguments: []) == .badge)
  }
}

@Suite struct CaptureDetectorTests {
  let screenSaverLevel = 1000

  private func capturing(_ windows: [SystemWindow]) -> Bool {
    CaptureDetector.isCapturing(windows: windows, screenSaverLevel: screenSaverLevel)
  }

  @Test func noWindowsMeansNotCapturing() {
    #expect(!capturing([]))
  }

  @Test(arguments: [0, 1000, 1498])
  func anyScreencaptureWindowMeansCapturing(layer: Int) {
    #expect(capturing([SystemWindow(ownerName: "screencapture", layer: layer)]))
  }

  @Test func screenshotWindowAboveScreenSaverLevelMeansCapturing() {
    #expect(capturing([SystemWindow(ownerName: "Screenshot", layer: 24), SystemWindow(ownerName: "Screenshot", layer: 1499)]))
  }

  @Test(arguments: [24, 1000])
  func screenshotWindowAtOrBelowScreenSaverLevelIsIgnored(layer: Int) {
    #expect(!capturing([SystemWindow(ownerName: "Screenshot", layer: layer)]))
  }

  @Test func otherOwnersAreIgnored() {
    let windows = [
      SystemWindow(ownerName: "Dock", layer: 1000), SystemWindow(ownerName: "Window Server", layer: 2147483630),
      SystemWindow(ownerName: "Screen Capture", layer: 1498),
    ]
    #expect(!capturing(windows))
  }
}

@Suite struct BadgeVisibilityTests {
  private func badge(visible: Bool) -> ResolvedBadge {
    ResolvedBadge(style: .initial, label: "A", isVisible: visible)
  }

  @Test func showsWhenEverythingAllows() {
    #expect(BadgeVisibility.shouldShow(badge: badge(visible: true), cursorVisible: true, capturing: false))
  }

  @Test func hiddenWhenBadgeIsNotVisible() {
    #expect(!BadgeVisibility.shouldShow(badge: badge(visible: false), cursorVisible: true, capturing: false))
  }

  @Test func hiddenWhenCursorIsHidden() {
    #expect(!BadgeVisibility.shouldShow(badge: badge(visible: true), cursorVisible: false, capturing: false))
  }

  @Test func hiddenWhileCapturing() {
    #expect(!BadgeVisibility.shouldShow(badge: badge(visible: true), cursorVisible: true, capturing: true))
  }
}
