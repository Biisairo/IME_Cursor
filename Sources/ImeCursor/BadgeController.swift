import AppKit
import Combine
import ImeCursorCore
import SwiftUI

private final class BadgePanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
private final class BadgeState: ObservableObject {
  @Published var style = BadgeStyle.initial
  @Published var label = ""
  @Published var scale = 1.0
  @Published var opacity = 1.0
}

private struct BadgeHost: View {
  @ObservedObject var state: BadgeState

  var body: some View {
    BadgeView(style: state.style, label: state.label)
      .scaleEffect(state.scale)
      .opacity(state.opacity)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

@MainActor
final class BadgeController {
  private static let fadeDuration = 0.2

  private let model: AppModel
  private let suppression = SuppressionMonitor()
  private let panel: BadgePanel
  private let state = BadgeState()
  private var monitors: [Any] = []
  private var cancellable: AnyCancellable?
  private var shownSource: (id: String?, capsLock: Bool)?
  private var lastChange = ProcessInfo.processInfo.systemUptime
  private var lastMove = ProcessInfo.processInfo.systemUptime

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
    let host = NSHostingView(rootView: BadgeHost(state: state))
    host.sizingOptions = []
    panel.contentView = host

    cancellable = model.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.render() }
    suppression.onChange = { [weak self] in self?.render() }
    suppression.onTick = { [weak self] in self?.updateOpacity() }
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
    lastMove = ProcessInfo.processInfo.systemUptime
    move()
    suppression.refreshCursor()
    updateOpacity()
  }

  private func render() {
    let badge = model.resolved
    let behavior = model.settings.behavior
    let source = (id: model.current?.id, capsLock: suppression.capsLock)
    let switched = shownSource.map { $0.id != source.id || $0.capsLock != source.capsLock } ?? false
    shownSource = source
    if switched {
      lastChange = ProcessInfo.processInfo.systemUptime
    }

    state.style = badge.style
    state.label = BadgeLabel.display(badge.label, capsLock: source.capsLock)
    let scale = behavior.emphasisEnabled ? behavior.emphasisScale : 1
    panel.setContentSize(
      EmphasisLayout.panelSize(
        badge: CGSize(width: badge.style.outerWidth, height: badge.style.outerHeight),
        scale: scale))
    move()
    let visible = BadgeVisibility.shouldShow(
      badge: badge, cursorVisible: suppression.cursorVisible, capturing: suppression.capturing)
    guard visible else {
      panel.orderOut(nil)
      return
    }
    updateOpacity()
    panel.orderFrontRegardless()
    if switched && behavior.emphasisEnabled {
      emphasize(scale: behavior.emphasisScale, duration: behavior.emphasisDuration)
    }
  }

  private func emphasize(scale: Double, duration: Double) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { state.scale = scale }
    DispatchQueue.main.async { [state] in
      withAnimation(.easeOut(duration: duration)) { state.scale = 1 }
    }
  }

  private func updateOpacity() {
    let opacity = DisplayPolicy.opacity(
      behavior: model.settings.behavior, now: ProcessInfo.processInfo.systemUptime,
      lastChange: lastChange, lastMove: lastMove)
    guard opacity != state.opacity else { return }
    withAnimation(.easeInOut(duration: Self.fadeDuration)) { state.opacity = opacity }
  }

  private func move() {
    let style = model.resolved.style
    let badge = CGSize(width: style.outerWidth, height: style.outerHeight)
    let origin = BadgePlacement.origin(
      pointer: NSEvent.mouseLocation, size: badge,
      offset: CGVector(dx: style.outerOffsetX, dy: style.outerOffsetY),
      screens: NSScreen.screens.map(\.frame))
    panel.setFrameOrigin(
      EmphasisLayout.panelOrigin(badgeOrigin: origin, badge: badge, panel: panel.frame.size))
  }
}
