import AppKit
import Combine
import ImeCursorCore
import SwiftUI

private final class BadgePanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class BadgeController {
  private let model: AppModel
  private let suppression = SuppressionMonitor()
  private let panel: BadgePanel
  private let badgeView = NSHostingView(rootView: BadgeView(style: .initial, label: ""))
  private var monitors: [Any] = []
  private var cancellable: AnyCancellable?

  private static let trackedEvents: NSEvent.EventTypeMask = [
    .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
  ]

  init(model: AppModel) {
    self.model = model
    panel = BadgePanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.hidesOnDeactivate = false
    panel.level = .screenSaver
    // canJoinAllSpaces 창은 Space 전환 중 화면과 함께 미끄러진다. 현재 Space에만 두고 전환 뒤 다시 띄운다.
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
    panel.contentView = badgeView

    cancellable = model.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.render() }
    suppression.onChange = { [weak self] in self?.render() }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.render() } }
    startTracking()
    suppression.start()
    render()
  }

  private func startTracking() {
    if let global = NSEvent.addGlobalMonitorForEvents(
      matching: Self.trackedEvents,
      handler: { [weak self] _ in MainActor.assumeIsolated { self?.pointerMoved() } })
    {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(
      matching: Self.trackedEvents,
      handler: { [weak self] event in
        MainActor.assumeIsolated { self?.pointerMoved() }
        return event
      })
    {
      monitors.append(local)
    }
  }

  private func pointerMoved() {
    move()
    suppression.refreshCursor()
  }

  private func render() {
    let badge = model.resolved
    badgeView.rootView = BadgeView(style: badge.style, label: badge.label)
    panel.setContentSize(NSSize(width: badge.style.outerWidth, height: badge.style.outerHeight))
    move()
    if BadgeVisibility.shouldShow(
      badge: badge, cursorVisible: suppression.cursorVisible, capturing: suppression.capturing)
    {
      panel.orderFrontRegardless()
    } else {
      panel.orderOut(nil)
    }
  }

  private func move() {
    let style = model.resolved.style
    let origin = BadgePlacement.origin(
      pointer: NSEvent.mouseLocation,
      size: CGSize(width: style.outerWidth, height: style.outerHeight),
      offset: CGVector(dx: style.outerOffsetX, dy: style.outerOffsetY),
      screens: NSScreen.screens.map(\.frame))
    panel.setFrameOrigin(origin)
  }
}
