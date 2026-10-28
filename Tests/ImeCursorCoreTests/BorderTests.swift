import CoreGraphics
import Foundation
import Testing
import ImeCursorCore

@Suite struct BorderStyleTests {
  let transparent = RGBA(red: 0, green: 0, blue: 0, alpha: 0)

  @Test func initialBordersAreOnePointAndTransparent() {
    let s = BadgeStyle.initial
    #expect(s.backgroundBorderWidth == 1)
    #expect(s.backgroundBorderColor == transparent)
    #expect(s.textBorderWidth == 1)
    #expect(s.textBorderColor == transparent)
  }

  @Test func borderWidthsClampToRange() {
    var s = BadgeStyle.initial
    s.backgroundBorderWidth = -1
    s.textBorderWidth = -1
    #expect(s.clamped().backgroundBorderWidth == 0)
    #expect(s.clamped().textBorderWidth == 0)
    s.backgroundBorderWidth = 21
    s.textBorderWidth = 11
    #expect(s.clamped().backgroundBorderWidth == 20)
    #expect(s.clamped().textBorderWidth == 10)
  }

  @Test func borderColorsClamp() {
    var s = BadgeStyle.initial
    s.backgroundBorderColor = RGBA(red: 2, green: -1, blue: 0.5, alpha: 3)
    s.textBorderColor = RGBA(red: -2, green: 1, blue: 0.5, alpha: -3)
    #expect(s.clamped().backgroundBorderColor == RGBA(red: 1, green: 0, blue: 0.5, alpha: 1))
    #expect(s.clamped().textBorderColor == RGBA(red: 0, green: 1, blue: 0.5, alpha: 0))
  }

  @Test func outerFrameGrowsOutwardByBorderWidth() {
    var s = BadgeStyle.initial
    s.width = 22
    s.height = 18
    s.backgroundBorderWidth = 3
    #expect(s.outerWidth == 28)
    #expect(s.outerHeight == 24)
  }

  @Test func zeroBorderKeepsFrameEqualToBackground() {
    var s = BadgeStyle.initial
    s.backgroundBorderWidth = 0
    #expect(s.outerWidth == s.width)
    #expect(s.outerHeight == s.height)
  }

  @Test func outerCornerRadiusIsConcentric() {
    var s = BadgeStyle.initial
    s.width = 30
    s.height = 10
    s.cornerRadius = 100
    s.backgroundBorderWidth = 2
    #expect(s.outerCornerRadius == 7)
    s.cornerRadius = 0
    #expect(s.outerCornerRadius == 0)
  }

  @Test func textOutlineStrokeIsTwiceWidthAsPercentOfFontSize() {
    var s = BadgeStyle.initial
    s.fontSize = 20
    s.textBorderWidth = 1
    #expect(s.textOutlineStrokePercent == 10)
    s.textBorderWidth = 0
    #expect(s.textOutlineStrokePercent == 0)
  }
}

@Suite struct PreviewLayoutTests {
  let cursor = CGSize(width: 28, height: 40)
  let hotSpot = CGPoint(x: 5, y: 5)

  private func style(border: Double = 0) -> BadgeStyle {
    var s = BadgeStyle.initial
    s.width = 22
    s.height = 18
    s.backgroundBorderWidth = border
    return s
  }

  private func offset(_ dx: Double, _ dy: Double) -> BadgePosition {
    BadgePosition(anchor: .bottomRight, offsetX: dx, offsetY: dy)
  }

  @Test func badgeBelowRightOfCursor() {
    let l = PreviewLayout.make(cursorSize: cursor, hotSpot: hotSpot, style: style(), position: offset(16, 16))
    #expect(l.imageOrigin == CGPoint(x: 12, y: 12))
    #expect(l.badgeOrigin == CGPoint(x: 33, y: 33))
    #expect(l.canvasSize == CGSize(width: 67, height: 64))
  }

  @Test func badgeAboveLeftOfCursor() {
    let l = PreviewLayout.make(cursorSize: cursor, hotSpot: hotSpot, style: style(), position: offset(-40, -30))
    #expect(l.badgeOrigin == CGPoint(x: 12, y: 12))
    #expect(l.imageOrigin == CGPoint(x: 47, y: 37))
    #expect(l.canvasSize == CGSize(width: 87, height: 89))
  }

  @Test func borderExtendsBadgeFrame() {
    let l = PreviewLayout.make(
      cursorSize: cursor, hotSpot: hotSpot, style: style(border: 4), position: offset(16, 16))
    #expect(l.badgeOrigin == CGPoint(x: 29, y: 29))
    #expect(l.badgeSize == CGSize(width: 30, height: 26))
    #expect(l.canvasSize == CGSize(width: 71, height: 67))
  }

  @Test func caretPreviewPutsBadgeRightOfCaretBar() {
    let l = PreviewLayout.make(caretSize: PreviewLayout.caretSize, style: style(), position: .caretInitial)
    #expect(PreviewLayout.caretSize == CGSize(width: 2, height: 18))
    #expect(l.imageOrigin == CGPoint(x: 12, y: 12))
    #expect(l.badgeOrigin == CGPoint(x: 16, y: 12))
    #expect(l.canvasSize == CGSize(width: 50, height: 42))
  }
}
