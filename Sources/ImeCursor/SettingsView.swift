import ApplicationServices
import Combine
import ImeCursorCore
import SwiftUI

private enum Selection: Hashable {
  case behavior
  case defaultStyle
  case source(BadgeKind, String)
}

private enum PreviewCursor: String, CaseIterable {
  case arrow = "화살표"
  case iBeam = "I-beam"

  var cursor: NSCursor {
    switch self {
    case .arrow: .arrow
    case .iBeam: .iBeam
    }
  }
}

/// CLT에는 SwiftUIMacros 플러그인이 없어서 `@State` 대신 쓴다.
@MainActor
private final class SettingsViewState: ObservableObject {
  @Published var selection: Selection? = .defaultStyle
  @Published var previewCursor: PreviewCursor = .arrow
  @Published var launchAtLogin = LaunchAtLogin.isEnabled
  @Published var launchError: String?
  @Published var trusted = AXIsProcessTrusted()
}

extension BadgeKind {
  fileprivate var title: String {
    switch self {
    case .cursor: "커서 배지"
    case .caret: "캐럿 배지"
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  @StateObject private var state = SettingsViewState()

  var body: some View {
    NavigationSplitView {
      List(selection: $state.selection) {
        Text("동작").tag(Selection.behavior)
        Text("기본 스타일").tag(Selection.defaultStyle)
        ForEach(BadgeKind.allCases, id: \.self) { kind in
          Section(kind.title) {
            ForEach(model.sources) { source in
              HStack {
                Text(source.localizedName ?? source.id)
                Spacer()
                if source.id == model.current?.id {
                  Circle().fill(.green).frame(width: 7, height: 7)
                }
              }
              .tag(Selection.source(kind, source.id))
            }
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    } detail: {
      detail
    }
    .frame(minWidth: 680, minHeight: 560)
    .environmentObject(state)
  }

  @ViewBuilder
  private var detail: some View {
    switch state.selection {
    case .behavior:
      BehaviorEditor()
    case .defaultStyle:
      DefaultStyleEditor()
    case .source(let kind, let id):
      if let source = model.sources.first(where: { $0.id == id }) {
        SourceEditor(kind: kind, source: source)
      } else {
        placeholder
      }
    case nil:
      placeholder
    }
  }

  private var placeholder: some View {
    Text("왼쪽 목록에서 항목을 선택하세요.").foregroundStyle(.secondary)
  }
}

extension DisplayMode {
  fileprivate var title: String {
    switch self {
    case .always: "항상 표시"
    case .afterSwitch: "전환 후 잠시 표시"
    case .dimWhenIdle: "멈추면 흐리게"
    }
  }

  /// 캐럿 배지에는 "멈추면 흐리게"가 없다(FR-MODE-1).
  fileprivate static func cases(for kind: BadgeKind) -> [DisplayMode] {
    kind == .cursor ? allCases : [.always, .afterSwitch]
  }
}

extension CaretCondition {
  fileprivate var title: String {
    switch self {
    case .off: "끄기"
    case .whenCursorHidden: "커서가 숨겨졌을 때"
    case .always: "캐럿이 있으면 항상"
    }
  }
}

private struct BehaviorEditor: View {
  @EnvironmentObject private var model: AppModel
  @EnvironmentObject private var state: SettingsViewState
  private let permissionCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    let cursorEnabled = Binding(
      get: { model.settings.cursorEnabled },
      set: { newValue in model.update { $0.cursorEnabled = newValue } })
    let condition = Binding(
      get: { model.settings.caretCondition },
      set: { newValue in
        // 끄기에서 바꿀 때만 권한을 요청한다(FR-CARET-2).
        if model.settings.caretCondition == .off && newValue != .off && !AXIsProcessTrusted() {
          state.trusted = AXIsProcessTrustedWithOptions(
            [Self.promptOption: true] as CFDictionary)
        }
        model.update { $0.caretCondition = newValue }
      })
    Form {
      Section("시작") {
        Toggle("로그인 시 자동 실행", isOn: $state.launchAtLogin)
          .onChange(of: state.launchAtLogin) { _, newValue in
            guard newValue != LaunchAtLogin.isEnabled else { return }
            state.launchError = LaunchAtLogin.set(newValue)
            state.launchAtLogin = LaunchAtLogin.isEnabled
          }
        if let launchError = state.launchError {
          Text(launchError).font(.caption).foregroundStyle(.red)
        }
      }
      Section("커서 배지") {
        Toggle("커서 배지 표시", isOn: cursorEnabled)
      }
      BehaviorFields(kind: .cursor)
      Section("캐럿 배지") {
        Picker("표시 조건", selection: condition) {
          ForEach(CaretCondition.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.radioGroup)
        LabeledContent("접근성 권한") {
          HStack {
            Text(state.trusted ? "허용됨" : "허용 안 됨")
              .foregroundStyle(state.trusted ? Color.secondary : Color.red)
            if !state.trusted {
              Button("시스템 설정 열기") {
                NSWorkspace.shared.open(Self.accessibilitySettings)
              }
            }
          }
        }
      }
      BehaviorFields(kind: .caret)
      ResetRow {
        model.update { settings in
          for kind in BadgeKind.allCases {
            settings.updateBehavior(kind) { $0 = .initial }
          }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("동작")
    .onReceive(permissionCheck) { _ in state.trusted = AXIsProcessTrusted() }
  }

  /// `kAXTrustedCheckOptionPrompt`는 전역 변수라서 Swift 6 동시성 검사에 걸린다. 같은 값의 문자열을 쓴다.
  private static let promptOption = "AXTrustedCheckOptionPrompt"
  private static let accessibilitySettings = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}

private struct BehaviorFields: View {
  @EnvironmentObject private var model: AppModel
  let kind: BadgeKind

  var body: some View {
    let behavior = Binding(
      get: { model.settings[kind].behavior },
      set: { newValue in model.update { $0.updateBehavior(kind) { $0 = newValue } } })
    Section("\(kind.title): 전환 강조 (입력 소스나 Caps Lock이 바뀔 때)") {
      Toggle("전환 강조", isOn: behavior.emphasisEnabled)
      NumberRow(
        title: "확대 배율", value: behavior.emphasisScale,
        range: BehaviorSettings.Limits.emphasisScale, step: 0.1)
      .disabled(!behavior.wrappedValue.emphasisEnabled)
      NumberRow(
        title: "지속 시간 (초)", value: behavior.emphasisDuration,
        range: BehaviorSettings.Limits.emphasisDuration, step: 0.05)
      .disabled(!behavior.wrappedValue.emphasisEnabled)
    }
    Section("\(kind.title): 표시 모드") {
      Picker("표시 모드", selection: behavior.displayMode) {
        ForEach(DisplayMode.cases(for: kind), id: \.self) { Text($0.title).tag($0) }
      }
      .pickerStyle(.radioGroup)
      NumberRow(
        title: "대기 시간 (초)", value: behavior.delay, range: BehaviorSettings.Limits.delay,
        step: 0.5)
      .disabled(behavior.wrappedValue.displayMode == .always)
      if kind == .cursor {
        NumberRow(
          title: "흐린 정도 (불투명도)", value: behavior.dimOpacity,
          range: BehaviorSettings.Limits.dimOpacity, step: 0.05)
        .disabled(behavior.wrappedValue.displayMode != .dimWhenIdle)
      }
    }
  }
}

private struct DefaultStyleEditor: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let style = Binding(
      get: { model.settings.defaultStyle },
      set: { newValue in model.update { $0.updateDefaultStyle { $0 = newValue } } })
    let label = StyleResolver.resolve(.cursor, current: model.current, settings: model.settings)
      .label
    Form {
      PreviewRow(
        kind: .cursor, style: style.wrappedValue, position: model.settings.cursor.position,
        label: label)
      StyleFields(style: style)
      ForEach(BadgeKind.allCases, id: \.self) { kind in
        let position = Binding(
          get: { model.settings[kind].position },
          set: { newValue in model.update { $0.updatePosition(kind) { $0 = newValue } } })
        Section("\(kind.title) 위치 기본값 (오른쪽·아래쪽이 양수)") {
          LabeledContent("기준 방향") { AnchorGrid(anchor: position.anchor) }
          NumberRow(title: "X", value: position.offsetX, range: BadgeStyle.Limits.offset)
          NumberRow(title: "Y", value: position.offsetY, range: BadgeStyle.Limits.offset)
        }
      }
      ResetRow { model.update { $0.resetDefaultStyle() } }
    }
    .formStyle(.grouped)
    .navigationTitle("기본 스타일")
  }
}

private struct SourceEditor: View {
  @EnvironmentObject private var model: AppModel
  let kind: BadgeKind
  let source: InputSourceInfo

  var body: some View {
    let settings = model.settings
    let override = StyleResolver.override(kind, for: source, in: settings)
    let base = settings.defaultStyle
    let basePosition = settings[kind].position
    let style = override.style(over: base)
    let label = Binding(
      get: { StyleResolver.sourceSettings(for: source, in: settings).label },
      set: { newValue in model.update { $0.updateSource(source) { $0.label = newValue } } })
    Form {
      PreviewRow(
        kind: kind, style: style, position: override.position(over: basePosition),
        label: label.wrappedValue)
      Section("표시 글자 (커서 배지와 캐럿 배지가 함께 씀)") {
        TextField("표시 글자 (최대 \(BadgeLabel.maxLength)자)", text: label)
      }
      Section("표시") {
        field(override, \.isVisible, base.isVisible) { Toggle("배지 표시", isOn: $0) }
      }
      Section("글자") {
        field(override, \.fontSize, base.fontSize) {
          NumberRow(title: "크기", value: $0, range: BadgeStyle.Limits.fontSize)
        }
        field(override, \.fontWeight, base.fontWeight) { value in
          Picker("굵기", selection: value) {
            ForEach(FontWeight.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
        }
        field(override, \.textColor, base.textColor) { ColorRow(title: "색", rgba: $0) }
        field(override, \.textBorderWidth, base.textBorderWidth) {
          NumberRow(title: "테두리 두께", value: $0, range: BadgeStyle.Limits.textBorder)
        }
        field(override, \.textBorderColor, base.textBorderColor) {
          ColorRow(title: "테두리 색", rgba: $0)
        }
      }
      Section("배경") {
        field(override, \.width, base.width) {
          NumberRow(title: "폭", value: $0, range: BadgeStyle.Limits.size)
        }
        field(override, \.height, base.height) {
          NumberRow(title: "높이", value: $0, range: BadgeStyle.Limits.size)
        }
        field(override, \.cornerRadius, base.cornerRadius) {
          NumberRow(title: "모서리 둥글기", value: $0, range: BadgeStyle.Limits.cornerRadius)
        }
        field(override, \.backgroundColor, base.backgroundColor) { ColorRow(title: "색", rgba: $0) }
        field(override, \.backgroundBorderWidth, base.backgroundBorderWidth) {
          NumberRow(title: "테두리 두께", value: $0, range: BadgeStyle.Limits.backgroundBorder)
        }
        field(override, \.backgroundBorderColor, base.backgroundBorderColor) {
          ColorRow(title: "테두리 색", rgba: $0)
        }
      }
      Section("위치 (오른쪽·아래쪽이 양수)") {
        field(override, \.anchor, basePosition.anchor) { value in
          LabeledContent("기준 방향") { AnchorGrid(anchor: value) }
        }
        field(override, \.offsetX, basePosition.offsetX) {
          NumberRow(title: "X", value: $0, range: BadgeStyle.Limits.offset)
        }
        field(override, \.offsetY, basePosition.offsetY) {
          NumberRow(title: "Y", value: $0, range: BadgeStyle.Limits.offset)
        }
      }
      ResetRow { model.update { $0.resetOverride(kind, for: source) } }
    }
    .formStyle(.grouped)
    .navigationTitle("\(source.localizedName ?? source.id) · \(kind.title)")
  }

  private func field<Value: Equatable, Content: View>(
    _ override: StyleOverride, _ path: WritableKeyPath<StyleOverride, Value?>, _ base: Value,
    @ViewBuilder content: @escaping (Binding<Value>) -> Content
  ) -> some View {
    OverrideRow(
      value: override[keyPath: path], base: base,
      set: { [kind, source] newValue in
        model.update { $0.updateOverride(kind, for: source) { $0[keyPath: path] = newValue } }
      }, content: content)
  }
}

/// 덮어쓴 항목에는 점과 되돌리기 버튼을 붙인다(UI-14).
private struct OverrideRow<Value: Equatable, Content: View>: View {
  let value: Value?
  let base: Value
  let set: (Value?) -> Void
  @ViewBuilder let content: (Binding<Value>) -> Content

  var body: some View {
    HStack {
      Circle().fill(value == nil ? Color.clear : Color.accentColor).frame(width: 6, height: 6)
      content(Binding(get: { value ?? base }, set: { set($0) }))
      Button {
        set(nil)
      } label: {
        Image(systemName: "arrow.uturn.backward")
      }
      .buttonStyle(.borderless)
      .help("되돌리기")
      .opacity(value == nil ? 0 : 1)
      .disabled(value == nil)
    }
  }
}

/// 기준 방향 3 × 3 격자(UI-17).
private struct AnchorGrid: View {
  @Binding var anchor: BadgeAnchor

  private static let rows: [[BadgeAnchor]] = [
    [.topLeft, .top, .topRight], [.left, .center, .right], [.bottomLeft, .bottom, .bottomRight],
  ]

  var body: some View {
    Grid(horizontalSpacing: 2, verticalSpacing: 2) {
      ForEach(Self.rows, id: \.self) { row in
        GridRow {
          ForEach(row, id: \.self) { item in
            Button {
              anchor = item
            } label: {
              Image(systemName: item.symbol)
                .frame(width: 22, height: 22)
                .background(item == anchor ? Color.accentColor.opacity(0.35) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.borderless)
          }
        }
      }
    }
  }
}

extension BadgeAnchor {
  fileprivate var symbol: String {
    switch self {
    case .topLeft: "arrow.up.left"
    case .top: "arrow.up"
    case .topRight: "arrow.up.right"
    case .left: "arrow.left"
    case .center: "circle.fill"
    case .right: "arrow.right"
    case .bottomLeft: "arrow.down.left"
    case .bottom: "arrow.down"
    case .bottomRight: "arrow.down.right"
    }
  }
}

private struct PreviewRow: View {
  @EnvironmentObject private var state: SettingsViewState
  let kind: BadgeKind
  let style: BadgeStyle
  let position: BadgePosition
  let label: String

  var body: some View {
    let cursor = state.previewCursor.cursor
    let layout =
      switch kind {
      case .cursor:
        PreviewLayout.make(
          cursorSize: cursor.image.size, hotSpot: cursor.hotSpot, style: style, position: position)
      case .caret:
        PreviewLayout.make(caretSize: PreviewLayout.caretSize, style: style, position: position)
      }
    Section("미리보기") {
      if kind == .cursor {
        Picker("커서", selection: $state.previewCursor) {
          ForEach(PreviewCursor.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
      }
      HStack {
        Spacer()
        ZStack(alignment: .topLeading) {
          switch kind {
          case .cursor:
            Image(nsImage: cursor.image)
              .offset(x: layout.imageOrigin.x, y: layout.imageOrigin.y)
          case .caret:
            Rectangle().fill(.primary)
              .frame(width: PreviewLayout.caretSize.width, height: PreviewLayout.caretSize.height)
              .offset(x: layout.imageOrigin.x, y: layout.imageOrigin.y)
          }
          BadgeView(style: style, label: label)
            .opacity(style.isVisible ? 1 : 0.3)
            .offset(x: layout.badgeOrigin.x, y: layout.badgeOrigin.y)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
        Spacer()
      }
    }
  }
}

private struct StyleFields: View {
  @Binding var style: BadgeStyle

  var body: some View {
    Section("표시") {
      Toggle("배지 표시", isOn: $style.isVisible)
    }
    Section("글자") {
      NumberRow(title: "크기", value: $style.fontSize, range: BadgeStyle.Limits.fontSize)
      Picker("굵기", selection: $style.fontWeight) {
        ForEach(FontWeight.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      ColorRow(title: "색", rgba: $style.textColor)
      NumberRow(
        title: "테두리 두께", value: $style.textBorderWidth, range: BadgeStyle.Limits.textBorder)
      ColorRow(title: "테두리 색", rgba: $style.textBorderColor)
    }
    Section("배경") {
      NumberRow(title: "폭", value: $style.width, range: BadgeStyle.Limits.size)
      NumberRow(title: "높이", value: $style.height, range: BadgeStyle.Limits.size)
      NumberRow(
        title: "모서리 둥글기", value: $style.cornerRadius, range: BadgeStyle.Limits.cornerRadius)
      ColorRow(title: "색", rgba: $style.backgroundColor)
      NumberRow(
        title: "테두리 두께", value: $style.backgroundBorderWidth,
        range: BadgeStyle.Limits.backgroundBorder)
      ColorRow(title: "테두리 색", rgba: $style.backgroundBorderColor)
    }
  }
}

private struct NumberRow: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  var step: Double = 1

  var body: some View {
    LabeledContent(title) {
      HStack {
        // step을 주면 단계마다 눈금을 계산해서 레이아웃이 크게 느려진다. 반올림으로 단위를 유지한다.
        Slider(
          value: Binding(get: { value }, set: { value = ($0 / step).rounded() * step }), in: range)
        TextField("", value: $value, format: .number.precision(.fractionLength(0...2)))
          .multilineTextAlignment(.trailing)
          .frame(width: 56)
        Stepper("", value: $value, in: range, step: step).labelsHidden()
      }
    }
  }
}

private struct ColorRow: View {
  let title: String
  @Binding var rgba: RGBA

  var body: some View {
    ColorPicker(
      title, selection: Binding(get: { Color(rgba) }, set: { rgba = RGBA($0) }),
      supportsOpacity: true)
  }
}

private struct ResetRow: View {
  let action: () -> Void

  var body: some View {
    Section {
      Button("초기화", role: .destructive, action: action)
    }
  }
}
