import CoreGraphics
import Testing
import ImeCursorCore

@Suite struct BadgeAnchorTests {
  @Test func oppositeMirrorsThroughCenter() {
    #expect(BadgeAnchor.topLeft.opposite == .bottomRight)
    #expect(BadgeAnchor.top.opposite == .bottom)
    #expect(BadgeAnchor.topRight.opposite == .bottomLeft)
    #expect(BadgeAnchor.left.opposite == .right)
    #expect(BadgeAnchor.center.opposite == .center)
    #expect(BadgeAnchor.right.opposite == .left)
    #expect(BadgeAnchor.bottomLeft.opposite == .topRight)
    #expect(BadgeAnchor.bottom.opposite == .top)
    #expect(BadgeAnchor.bottomRight.opposite == .topLeft)
  }

  @Test(arguments: BadgeAnchor.allCases)
  func oppositeTwiceIsSelf(anchor: BadgeAnchor) {
    #expect(anchor.opposite.opposite == anchor)
  }
}

@Suite struct BadgePositionTests {
  @Test func initialPositionsMatchSpec() {
    #expect(BadgePosition.cursorInitial == BadgePosition(anchor: .bottomRight, offsetX: 16, offsetY: 16))
    #expect(BadgePosition.caretInitial == BadgePosition(anchor: .right, offsetX: 2, offsetY: 0))
  }

  @Test func offsetsClampToRange() {
    let p = BadgePosition(anchor: .top, offsetX: -1000, offsetY: 1000).clamped()
    #expect(p.offsetX == -200)
    #expect(p.offsetY == 200)
  }
}

/// 좌표는 Y 아래쪽이 양수인 공간이다(FR-STYLE-8).
@Suite struct BackgroundRectTests {
  let size = CGSize(width: 20, height: 10)
  let caret = CGRect(x: 100, y: 50, width: 4, height: 30)

  private func rect(_ anchor: BadgeAnchor, dx: Double = 0, dy: Double = 0) -> CGRect {
    BadgePlacement.backgroundRect(
      target: caret, size: size, position: BadgePosition(anchor: anchor, offsetX: dx, offsetY: dy))
  }

  @Test func rightPutsBadgeLeftMiddleOnTargetRightMiddle() {
    #expect(rect(.right) == CGRect(x: 104, y: 60, width: 20, height: 10))
  }

  @Test func leftPutsBadgeRightMiddleOnTargetLeftMiddle() {
    #expect(rect(.left) == CGRect(x: 80, y: 60, width: 20, height: 10))
  }

  @Test func topPutsBadgeBottomCenterOnTargetTopCenter() {
    #expect(rect(.top) == CGRect(x: 92, y: 40, width: 20, height: 10))
  }

  @Test func bottomPutsBadgeTopCenterOnTargetBottomCenter() {
    #expect(rect(.bottom) == CGRect(x: 92, y: 80, width: 20, height: 10))
  }

  @Test func cornersPutBadgeDiagonallyOutside() {
    #expect(rect(.topLeft) == CGRect(x: 80, y: 40, width: 20, height: 10))
    #expect(rect(.topRight) == CGRect(x: 104, y: 40, width: 20, height: 10))
    #expect(rect(.bottomLeft) == CGRect(x: 80, y: 80, width: 20, height: 10))
    #expect(rect(.bottomRight) == CGRect(x: 104, y: 80, width: 20, height: 10))
  }

  @Test func centerOverlapsTarget() {
    #expect(rect(.center) == CGRect(x: 92, y: 60, width: 20, height: 10))
  }

  @Test func offsetIsAddedAfterAlignmentWithYDown() {
    #expect(rect(.right, dx: 2, dy: -3) == CGRect(x: 106, y: 57, width: 20, height: 10))
  }

  @Test func caretThicknessDoesNotChangeGapOnTheRight() {
    let thin = BadgePlacement.backgroundRect(
      target: CGRect(x: 100, y: 50, width: 0, height: 30), size: size,
      position: BadgePosition(anchor: .right, offsetX: 2, offsetY: 0))
    let cell = BadgePlacement.backgroundRect(
      target: CGRect(x: 100, y: 50, width: 10, height: 30), size: size,
      position: BadgePosition(anchor: .right, offsetX: 2, offsetY: 0))
    #expect(thin.minX == 102)
    #expect(cell.minX == 112)
  }

  @Test func zeroSizeTargetActsAsPoint() {
    let point = CGRect(x: 10, y: 10, width: 0, height: 0)
    let r = BadgePlacement.backgroundRect(target: point, size: size, position: .cursorInitial)
    #expect(r == CGRect(x: 26, y: 26, width: 20, height: 10))
  }
}

/// AppKit 좌표(원점 왼쪽 아래, Y 위쪽)에서 배지 창(테두리 포함)의 원점을 구한다(FR-BADGE-2, 3, 4).
@Suite struct BadgePlacementTests {
  let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
  let second = CGRect(x: 1000, y: 100, width: 500, height: 400)

  private func style(border: Double = 0) -> BadgeStyle {
    var s = BadgeStyle.initial
    s.width = 20
    s.height = 10
    s.backgroundBorderWidth = border
    return s
  }

  private func origin(
    _ pointer: CGPoint, position: BadgePosition = .cursorInitial, border: Double = 0
  ) -> CGPoint {
    BadgePlacement.origin(
      target: CGRect(origin: pointer, size: .zero), style: style(border: border),
      position: position, screens: [main, second])
  }

  private func offset(_ dx: Double, _ dy: Double) -> BadgePosition {
    BadgePosition(anchor: .bottomRight, offsetX: dx, offsetY: dy)
  }

  @Test func cursorInitialMatchesPreviousPlacement() {
    #expect(origin(CGPoint(x: 500, y: 400)) == CGPoint(x: 516, y: 374))
  }

  @Test func borderGrowsOutwardKeepingBackgroundPosition() {
    #expect(origin(CGPoint(x: 500, y: 400), border: 3) == CGPoint(x: 513, y: 371))
  }

  @Test func negativeOffsetMovesLeftAndUp() {
    #expect(origin(CGPoint(x: 500, y: 400), position: offset(-30, -20)) == CGPoint(x: 470, y: 410))
  }

  @Test func caretRightIsVerticallyCentered() {
    let o = BadgePlacement.origin(
      target: CGRect(x: 100, y: 300, width: 2, height: 30), style: style(),
      position: .caretInitial, screens: [main])
    #expect(o == CGPoint(x: 104, y: 310))
  }

  @Test func clampsAtRightEdge() {
    #expect(origin(CGPoint(x: 995, y: 400)).x == 980)
  }

  @Test func clampsAtBottomEdge() {
    #expect(origin(CGPoint(x: 500, y: 5)).y == 0)
  }

  @Test func clampsAtLeftEdge() {
    #expect(origin(CGPoint(x: 5, y: 400), position: offset(-50, 0)).x == 0)
  }

  @Test func clampsAtTopEdge() {
    #expect(origin(CGPoint(x: 500, y: 795), position: offset(0, -50)).y == 790)
  }

  @Test func usesScreenContainingTargetTopLeft() {
    #expect(origin(CGPoint(x: 1490, y: 300)) == CGPoint(x: 1480, y: 274))
  }

  @Test func clampsIntoSecondScreenBottom() {
    #expect(origin(CGPoint(x: 1200, y: 105)).y == 100)
  }

  @Test func pointerOnSharedEdgeStaysOnAScreen() {
    let o = origin(CGPoint(x: 1000, y: 400))
    #expect(o.x >= 0 && o.x <= 1480)
  }

  @Test func pointerOutsideAllScreensUsesFirstScreen() {
    #expect(origin(CGPoint(x: 5000, y: 5000)) == CGPoint(x: 980, y: 790))
  }

  @Test func noScreensReturnsUnclampedPosition() {
    let o = BadgePlacement.origin(
      target: CGRect(x: 10, y: 10, width: 0, height: 0), style: style(), position: .cursorInitial,
      screens: [])
    #expect(o == CGPoint(x: 26, y: -16))
  }

  @Test func badgeLargerThanScreenAlignsToScreenOrigin() {
    let tiny = CGRect(x: 0, y: 0, width: 10, height: 5)
    let o = BadgePlacement.origin(
      target: CGRect(x: 5, y: 2, width: 0, height: 0), style: style(), position: .cursorInitial,
      screens: [tiny])
    #expect(o == CGPoint(x: 0, y: 0))
  }
}

@Suite struct ScreenGeometryTests {
  @Test func flipsBetweenAccessibilityAndAppKitCoordinates() {
    let ax = CGRect(x: 10, y: 20, width: 5, height: 30)
    let appKit = ScreenGeometry.flipped(ax, primaryHeight: 800)
    #expect(appKit == CGRect(x: 10, y: 750, width: 5, height: 30))
    #expect(ScreenGeometry.flipped(appKit, primaryHeight: 800) == ax)
  }
}
