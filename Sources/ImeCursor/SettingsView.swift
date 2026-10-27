import ImeCursorCore
import SwiftUI

private enum Selection: Hashable {
  case behavior
  case defaultStyle
  case source(String)
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
}

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  @StateObject private var state = SettingsViewState()

  var body: some View {
    NavigationSplitView {
      List(selection: $state.selection) {
        Text("동작").tag(Selection.behavior)
        Text("기본 스타일").tag(Selection.defaultStyle)
        Section("입력 소스") {
          ForEach(model.sources) { source in
            HStack {
              Text(source.localizedName ?? source.id)
              Spacer()
              if source.id == model.current?.id {
                Circle().fill(.green).frame(width: 7, height: 7)
              }
            }
            .tag(Selection.source(source.id))
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
    case .source(let id):
      if let source = model.sources.first(where: { $0.id == id }) {
        SourceEditor(source: source)
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
}

private struct BehaviorEditor: View {
  @EnvironmentObject private var model: AppModel
  @EnvironmentObject private var state: SettingsViewState

  var body: some View {
    let behavior = Binding(
      get: { model.settings.behavior },
      set: { newValue in model.update { $0.updateBehavior { $0 = newValue } } })
    Form {
      Section("전환 강조 (입력 소스나 Caps Lock이 바뀔 때)") {
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
      Section("표시 모드") {
        Picker("표시 모드", selection: behavior.displayMode) {
          ForEach(DisplayMode.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.radioGroup)
        NumberRow(
          title: "대기 시간 (초)", value: behavior.delay, range: BehaviorSettings.Limits.delay,
          step: 0.5)
        .disabled(behavior.wrappedValue.displayMode == .always)
        NumberRow(
          title: "흐린 정도 (불투명도)", value: behavior.dimOpacity,
          range: BehaviorSettings.Limits.dimOpacity, step: 0.05)
        .disabled(behavior.wrappedValue.displayMode != .dimWhenIdle)
      }
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
      ResetRow { model.update { $0.updateBehavior { $0 = .initial } } }
    }
    .formStyle(.grouped)
    .navigationTitle("동작")
  }
}

private struct DefaultStyleEditor: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let style = Binding(
      get: { model.settings.defaultStyle },
      set: { newValue in model.update { $0.updateDefaultStyle { $0 = newValue } } })
    Form {
      PreviewRow(style: style.wrappedValue, label: model.resolved.label)
      StyleFields(style: style)
      ResetRow { model.update { $0.resetDefaultStyle() } }
    }
    .formStyle(.grouped)
    .navigationTitle("기본 스타일")
  }
}

private struct SourceEditor: View {
  @EnvironmentObject private var model: AppModel
  let source: InputSourceInfo

  var body: some View {
    let settings = StyleResolver.sourceSettings(for: source, in: model.settings)
    let label = Binding(
      get: { settings.label },
      set: { newValue in model.update { $0.updateSource(source) { $0.label = newValue } } })
    let usesDefault = Binding(
      get: { settings.mode == .useDefault },
      set: { newValue in model.update { $0.setUsesDefaultStyle(newValue, for: source) } })
    Form {
      PreviewRow(
        style: StyleResolver.style(for: settings, in: model.settings), label: settings.label)
      Section {
        TextField("표시 글자 (최대 \(BadgeLabel.maxLength)자)", text: label)
        Toggle("기본 스타일 사용", isOn: usesDefault)
      }
      if case .custom(let custom) = settings.mode {
        StyleFields(
          style: Binding(
            get: { custom },
            set: { newValue in
              model.update { $0.updateSource(source) { $0.mode = .custom(newValue) } }
            }))
      }
      ResetRow { model.update { $0.resetSource(source) } }
    }
    .formStyle(.grouped)
    .navigationTitle(source.localizedName ?? source.id)
  }
}

private struct PreviewRow: View {
  @EnvironmentObject private var state: SettingsViewState
  let style: BadgeStyle
  let label: String

  var body: some View {
    let cursor = state.previewCursor.cursor
    let layout = PreviewLayout.make(
      cursorSize: cursor.image.size, hotSpot: cursor.hotSpot, style: style)
    Section("미리보기") {
      Picker("커서", selection: $state.previewCursor) {
        ForEach(PreviewCursor.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      HStack {
        Spacer()
        ZStack(alignment: .topLeading) {
          Image(nsImage: cursor.image)
            .offset(x: layout.cursorOrigin.x, y: layout.cursorOrigin.y)
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
    Section("커서 기준 위치 (오른쪽·아래쪽이 양수)") {
      NumberRow(title: "X", value: $style.offsetX, range: BadgeStyle.Limits.offset)
      NumberRow(title: "Y", value: $style.offsetY, range: BadgeStyle.Limits.offset)
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
