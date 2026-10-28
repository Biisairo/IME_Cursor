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

/// 배지 하나의 창. 커서 배지와 캐럿 배지가 하나씩 가진다.
@MainActor
private final class BadgeWindow {
  private static let fadeDuration = 0.2

  private let panel: BadgePanel
  private let state = BadgeState()
  private var badge: ResolvedBadge?

  init() {
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
  }

  func update(_ badge: ResolvedBadge, label: String, behavior: BehaviorSettings) {
    self.badge = badge
    state.style = badge.style
    state.label = label
    let scale = behavior.emphasisEnabled ? behavior.emphasisScale : 1
    panel.setContentSize(
      EmphasisLayout.panelSize(
        badge: CGSize(width: badge.style.outerWidth, height: badge.style.outerHeight),
        scale: scale))
  }

  func move(to target: CGRect) {
    guard let badge else { return }
    let size = CGSize(width: badge.style.outerWidth, height: badge.style.outerHeight)
    let origin = BadgePlacement.origin(
      target: target, style: badge.style, position: badge.position,
      screens: NSScreen.screens.map(\.frame))
    panel.setFrameOrigin(
      EmphasisLayout.panelOrigin(badgeOrigin: origin, badge: size, panel: panel.frame.size))
  }

  func show(emphasis behavior: BehaviorSettings?) {
    panel.orderFrontRegardless()
    guard let behavior else { return }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { state.scale = behavior.emphasisScale }
    DispatchQueue.main.async { [state] in
      withAnimation(.easeOut(duration: behavior.emphasisDuration)) { state.scale = 1 }
    }
  }

  func hide() {
    panel.orderOut(nil)
  }

  func setOpacity(_ opacity: Double) {
    guard opacity != state.opacity else { return }
    withAnimation(.easeInOut(duration: Self.fadeDuration)) { state.opacity = opacity }
  }
}

@MainActor
final class BadgeController {
  private let model: AppModel
  private let suppression = SuppressionMonitor()
  private let tracker = CaretTracker()
  private let cursorWindow = BadgeWindow()
  private let caretWindow = BadgeWindow()
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
    cancellable = model.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.render() }
    suppression.onChange = { [weak self] in self?.render() }
    suppression.onTick = { [weak self] in self?.tick() }
    suppression.interval = { [weak self] in self?.pollingInterval() ?? PollingPolicy.normal }
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.render() } }
    startTracking()
    suppression.start()
    render()
  }

  /// 켰던 `AXEnhancedUserInterface`를 되돌린다(FR-CARET-12).
  func stop() {
    tracker.restore()
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
    cursorWindow.move(to: pointerTarget)
    suppression.refreshCursor()
    updateOpacity()
  }

  private func tick() {
    tracker.setActive(model.settings.caretCondition != .off)
    if tracker.refresh() {
      render()
    }
    updateOpacity()
  }

  private func pollingInterval() -> TimeInterval {
    let now = ProcessInfo.processInfo.systemUptime
    return PollingPolicy.interval(
      caretActive: tracker.isActive,
      sinceKey: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown),
      sinceFocusChange: now - tracker.lastFocusChange)
  }

  private var pointerTarget: CGRect {
    CGRect(origin: NSEvent.mouseLocation, size: .zero)
  }

  private func render() {
    let settings = model.settings
    let source = (id: model.current?.id, capsLock: suppression.capsLock)
    let switched = shownSource.map { $0.id != source.id || $0.capsLock != source.capsLock } ?? false
    shownSource = source
    if switched {
      lastChange = ProcessInfo.processInfo.systemUptime
    }

    let cursor = StyleResolver.resolve(.cursor, current: model.current, settings: settings)
    cursorWindow.update(
      cursor, label: BadgeLabel.display(cursor.label, capsLock: source.capsLock),
      behavior: settings.cursor.behavior)
    cursorWindow.move(to: pointerTarget)
    let cursorVisible = BadgeVisibility.shouldShow(
      badge: cursor, cursorVisible: suppression.cursorVisible, capturing: suppression.capturing)
    show(cursorWindow, visible: cursorVisible, switched: switched, behavior: settings.cursor.behavior)

    let caret = StyleResolver.resolve(.caret, current: model.current, settings: settings)
    caretWindow.update(
      caret, label: BadgeLabel.display(caret.label, capsLock: source.capsLock),
      behavior: settings.caret.behavior)
    tracker.caret.map(caretWindow.move)
    let caretVisible = CaretVisibility.shouldShow(
      badge: caret, condition: settings.caretCondition, cursorVisible: suppression.cursorVisible,
      hasCaret: tracker.caret != nil, capturing: suppression.capturing)
    show(caretWindow, visible: caretVisible, switched: switched, behavior: settings.caret.behavior)
    updateOpacity()
  }

  private func show(
    _ window: BadgeWindow, visible: Bool, switched: Bool, behavior: BehaviorSettings
  ) {
    guard visible else {
      window.hide()
      return
    }
    window.show(emphasis: switched && behavior.emphasisEnabled ? behavior : nil)
  }

  private func updateOpacity() {
    let now = ProcessInfo.processInfo.systemUptime
    for (window, kind) in [(cursorWindow, BadgeKind.cursor), (caretWindow, .caret)] {
      window.setOpacity(
        DisplayPolicy.opacity(
          behavior: model.settings[kind].behavior, now: now, lastChange: lastChange,
          lastMove: lastMove))
    }
  }
}
