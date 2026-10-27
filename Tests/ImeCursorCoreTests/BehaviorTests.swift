import CoreGraphics
import Foundation
import Testing
import ImeCursorCore

@Suite struct CapsLockLabelTests {
  @Test func capsLockOffKeepsLabel() {
    #expect(BadgeLabel.display("A", capsLock: false) == "A")
    #expect(BadgeLabel.display("", capsLock: false) == "")
  }

  @Test func capsLockOnPrefixesSymbol() {
    #expect(BadgeLabel.display("A", capsLock: true) == "⇪A")
    #expect(BadgeLabel.display("한", capsLock: true) == "⇪한")
  }

  @Test func capsLockOnWithEmptyLabelShowsSymbolOnly() {
    #expect(BadgeLabel.display("", capsLock: true) == "⇪")
  }

  @Test func symbolIsNotCountedInStoredLengthLimit() {
    let full = "12345678"
    #expect(BadgeLabel.normalized(full) == full)
    #expect(BadgeLabel.display(full, capsLock: true) == "⇪12345678")
  }
}

@Suite struct BehaviorSettingsTests {
  @Test func initialValuesMatchSpec() {
    let b = BehaviorSettings.initial
    #expect(!b.emphasisEnabled)
    #expect(b.emphasisScale == 1.6)
    #expect(b.emphasisDuration == 0.35)
    #expect(b.displayMode == .always)
    #expect(b.delay == 2)
    #expect(b.dimOpacity == 0.3)
  }

  @Test func valuesClampToRange() {
    var b = BehaviorSettings.initial
    b.emphasisScale = 0.5
    b.emphasisDuration = 0
    b.delay = 0
    b.dimOpacity = -1
    var c = b.clamped()
    #expect(c.emphasisScale == 1)
    #expect(c.emphasisDuration == 0.1)
    #expect(c.delay == 0.5)
    #expect(c.dimOpacity == 0)
    b.emphasisScale = 5
    b.emphasisDuration = 2
    b.delay = 11
    b.dimOpacity = 2
    c = b.clamped()
    #expect(c.emphasisScale == 3)
    #expect(c.emphasisDuration == 1)
    #expect(c.delay == 10)
    #expect(c.dimOpacity == 1)
  }

  @Test func updateBehaviorClamps() {
    var settings = AppSettings.initial
    settings.updateBehavior { $0.delay = 100 }
    #expect(settings.behavior.delay == 10)
  }

  @Test func roundTripKeepsBehavior() {
    let storage = MemoryStorage()
    var settings = AppSettings.initial
    settings.updateBehavior {
      $0.emphasisEnabled = true
      $0.displayMode = .dimWhenIdle
      $0.dimOpacity = 0.5
    }
    SettingsStore(storage: storage).save(settings)
    #expect(SettingsStore(storage: storage).load() == settings)
  }

  @Test func versionTwoSettingsLoadWithBehaviorDefaults() throws {
    var old = AppSettings.initial
    old.badgeEnabled = false
    var object = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
    object["schemaVersion"] = 2
    object["behavior"] = nil
    let storage = MemoryStorage()
    storage.values[SettingsStore.key] = try JSONSerialization.data(withJSONObject: object)
    let loaded = SettingsStore(storage: storage).load()
    #expect(storage.values[SettingsStore.backupKey] == nil)
    #expect(loaded.badgeEnabled == false)
    #expect(loaded.behavior == .initial)
    #expect(loaded.schemaVersion == AppSettings.currentSchemaVersion)
  }

  @Test func outOfRangeStoredBehaviorIsClampedOnLoad() {
    var settings = AppSettings.initial
    settings.behavior.emphasisScale = 9
    let storage = MemoryStorage()
    storage.values[SettingsStore.key] = try! JSONEncoder().encode(settings)
    #expect(SettingsStore(storage: storage).load().behavior.emphasisScale == 3)
  }
}

@Suite struct DisplayPolicyTests {
  private func behavior(_ mode: DisplayMode) -> BehaviorSettings {
    var b = BehaviorSettings.initial
    b.displayMode = mode
    b.delay = 2
    b.dimOpacity = 0.3
    return b
  }

  private func opacity(_ mode: DisplayMode, now: TimeInterval, change: TimeInterval = 0, move: TimeInterval = 0) -> Double {
    DisplayPolicy.opacity(behavior: behavior(mode), now: now, lastChange: change, lastMove: move)
  }

  @Test func alwaysIsFullyOpaque() {
    #expect(opacity(.always, now: 1000) == 1)
  }

  @Test func afterSwitchIsOpaqueBeforeDelayAndHiddenAfter() {
    #expect(opacity(.afterSwitch, now: 1.9, change: 0) == 1)
    #expect(opacity(.afterSwitch, now: 2.0, change: 0) == 0)
    #expect(opacity(.afterSwitch, now: 10, change: 9) == 1)
  }

  @Test func afterSwitchIgnoresMouseMovement() {
    #expect(opacity(.afterSwitch, now: 5, change: 0, move: 4.9) == 0)
  }

  @Test func dimWhenIdleIsOpaqueWhileMovingAndDimAfterDelay() {
    #expect(opacity(.dimWhenIdle, now: 1.9, move: 0) == 1)
    #expect(opacity(.dimWhenIdle, now: 2.0, move: 0) == 0.3)
  }

  @Test func dimWhenIdleIgnoresSwitches() {
    #expect(opacity(.dimWhenIdle, now: 5, change: 4.9, move: 0) == 0.3)
  }
}

@Suite struct EmphasisLayoutTests {
  @Test func panelGrowsByScale() {
    #expect(EmphasisLayout.panelSize(badge: CGSize(width: 24, height: 20), scale: 1.5) == CGSize(width: 36, height: 30))
    #expect(EmphasisLayout.panelSize(badge: CGSize(width: 24, height: 20), scale: 1) == CGSize(width: 24, height: 20))
  }

  @Test func panelIsCenteredOnBadge() {
    let origin = EmphasisLayout.panelOrigin(
      badgeOrigin: CGPoint(x: 100, y: 200), badge: CGSize(width: 24, height: 20),
      panel: CGSize(width: 36, height: 30))
    #expect(origin == CGPoint(x: 94, y: 195))
  }
}
