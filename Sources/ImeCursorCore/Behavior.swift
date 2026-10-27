import CoreGraphics
import Foundation

public enum DisplayMode: String, Codable, CaseIterable, Sendable {
  case always
  case afterSwitch
  case dimWhenIdle
}

/// 앱 전체에 적용되는 동작 설정(FR-EMPH-1, FR-MODE-1, 2).
public struct BehaviorSettings: Codable, Equatable, Sendable {
  public enum Limits {
    public static let emphasisScale: ClosedRange<Double> = 1...3
    public static let emphasisDuration: ClosedRange<Double> = 0.1...1
    public static let delay: ClosedRange<Double> = 0.5...10
    public static let dimOpacity: ClosedRange<Double> = 0...1
  }

  public static let initial = BehaviorSettings(
    emphasisEnabled: false, emphasisScale: 1.6, emphasisDuration: 0.35, displayMode: .always,
    delay: 2, dimOpacity: 0.3)

  public var emphasisEnabled: Bool
  public var emphasisScale: Double
  public var emphasisDuration: Double
  public var displayMode: DisplayMode
  public var delay: Double
  public var dimOpacity: Double

  public init(
    emphasisEnabled: Bool, emphasisScale: Double, emphasisDuration: Double,
    displayMode: DisplayMode, delay: Double, dimOpacity: Double
  ) {
    self.emphasisEnabled = emphasisEnabled
    self.emphasisScale = emphasisScale
    self.emphasisDuration = emphasisDuration
    self.displayMode = displayMode
    self.delay = delay
    self.dimOpacity = dimOpacity
  }

  public func clamped() -> BehaviorSettings {
    var b = self
    b.emphasisScale = emphasisScale.clamped(to: Limits.emphasisScale)
    b.emphasisDuration = emphasisDuration.clamped(to: Limits.emphasisDuration)
    b.delay = delay.clamped(to: Limits.delay)
    b.dimOpacity = dimOpacity.clamped(to: Limits.dimOpacity)
    return b
  }
}

public enum DisplayPolicy {
  /// 표시 모드에 따른 배지 불투명도(FR-MODE-3 ~ 5). 시각은 같은 기준의 초 단위이다.
  public static func opacity(
    behavior: BehaviorSettings, now: TimeInterval, lastChange: TimeInterval,
    lastMove: TimeInterval
  ) -> Double {
    switch behavior.displayMode {
    case .always: 1
    case .afterSwitch: now - lastChange < behavior.delay ? 1 : 0
    case .dimWhenIdle: now - lastMove < behavior.delay ? 1 : behavior.dimOpacity
    }
  }
}

public enum EmphasisLayout {
  public static func panelSize(badge: CGSize, scale: Double) -> CGSize {
    CGSize(width: badge.width * scale, height: badge.height * scale)
  }

  public static func panelOrigin(badgeOrigin: CGPoint, badge: CGSize, panel: CGSize) -> CGPoint {
    CGPoint(
      x: badgeOrigin.x - (panel.width - badge.width) / 2,
      y: badgeOrigin.y - (panel.height - badge.height) / 2)
  }
}
