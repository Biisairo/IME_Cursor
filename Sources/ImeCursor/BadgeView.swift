import AppKit
import ImeCursorCore
import SwiftUI

/// 배지 전체(배경 테두리 포함). 배경 테두리는 배경 영역 바깥에 그린다(FR-STYLE-5).
struct BadgeView: View {
  let style: BadgeStyle
  let label: String

  var body: some View {
    ZStack {
      if style.backgroundBorderWidth > 0 {
        RoundedRectangle(cornerRadius: style.outerCornerRadius)
          .strokeBorder(Color(style.backgroundBorderColor), lineWidth: style.backgroundBorderWidth)
      }
      OutlinedText(style: style, label: label)
        .frame(width: style.width, height: style.height)
        .background(Color(style.backgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: style.effectiveCornerRadius))
    }
    .frame(width: style.outerWidth, height: style.outerHeight)
  }
}

/// SwiftUI `Text`에는 윤곽선이 없어서 AppKit으로 그린다(FR-STYLE-6).
private struct OutlinedText: NSViewRepresentable {
  let style: BadgeStyle
  let label: String

  func makeNSView(context: Context) -> OutlinedTextView { OutlinedTextView() }

  func updateNSView(_ view: OutlinedTextView, context: Context) {
    view.content = (style, label)
  }
}

private final class OutlinedTextView: NSView {
  var content: (style: BadgeStyle, label: String) = (.initial, "") {
    didSet { needsDisplay = true }
  }

  override func draw(_ dirtyRect: NSRect) {
    let style = content.style
    let font = NSFont.systemFont(ofSize: style.fontSize, weight: style.fontWeight.appKit)
    let fill = NSAttributedString(
      string: content.label,
      attributes: [.font: font, .foregroundColor: NSColor(style.textColor)])
    let size = fill.size()
    let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
    if style.textBorderWidth > 0 {
      // 획 가운데에 그려지는 윤곽선을 먼저 그리고 글자로 덮어서 바깥쪽만 남긴다.
      NSAttributedString(
        string: content.label,
        attributes: [
          .font: font, .strokeWidth: style.textOutlineStrokePercent,
          .strokeColor: NSColor(style.textBorderColor),
        ]
      ).draw(at: origin)
    }
    fill.draw(at: origin)
  }
}

extension FontWeight {
  var appKit: NSFont.Weight {
    switch self {
    case .regular: .regular
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    }
  }
}

extension NSColor {
  convenience init(_ rgba: RGBA) {
    self.init(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
  }
}

extension Color {
  init(_ rgba: RGBA) {
    self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
  }
}

extension RGBA {
  init(_ color: Color) {
    let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
    self.init(
      red: c.redComponent, green: c.greenComponent, blue: c.blueComponent,
      alpha: c.alphaComponent)
  }
}
