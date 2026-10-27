import CoreGraphics
import Testing
import ImeCursorCore

@Suite struct BadgePlacementTests {
  let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
  let second = CGRect(x: 1000, y: 100, width: 500, height: 400)
  let size = CGSize(width: 20, height: 10)

  private func origin(_ pointer: CGPoint, offset: CGVector = CGVector(dx: 16, dy: 16)) -> CGPoint {
    BadgePlacement.origin(pointer: pointer, size: size, offset: offset, screens: [main, second])
  }

  @Test func topLeftIsPointerPlusOffsetWithYDown() {
    let o = origin(CGPoint(x: 500, y: 400))
    #expect(o == CGPoint(x: 516, y: 374))
  }

  @Test func negativeOffsetMovesLeftAndUp() {
    let o = origin(CGPoint(x: 500, y: 400), offset: CGVector(dx: -30, dy: -20))
    #expect(o == CGPoint(x: 470, y: 410))
  }

  @Test func clampsAtRightEdge() {
    #expect(origin(CGPoint(x: 995, y: 400)).x == 980)
  }

  @Test func clampsAtBottomEdge() {
    #expect(origin(CGPoint(x: 500, y: 5)).y == 0)
  }

  @Test func clampsAtLeftEdge() {
    #expect(origin(CGPoint(x: 5, y: 400), offset: CGVector(dx: -50, dy: 0)).x == 0)
  }

  @Test func clampsAtTopEdge() {
    #expect(origin(CGPoint(x: 500, y: 795), offset: CGVector(dx: 0, dy: -50)).y == 790)
  }

  @Test func usesScreenContainingPointer() {
    let o = origin(CGPoint(x: 1490, y: 300))
    #expect(o == CGPoint(x: 1480, y: 274))
  }

  @Test func clampsIntoSecondScreenBottom() {
    #expect(origin(CGPoint(x: 1200, y: 105)).y == 100)
  }

  @Test func pointerOnSharedEdgeStaysOnAScreen() {
    let o = origin(CGPoint(x: 1000, y: 400))
    #expect(o.x >= 0 && o.x <= 1480)
  }

  @Test func pointerOutsideAllScreensUsesFirstScreen() {
    let o = origin(CGPoint(x: 5000, y: 5000))
    #expect(o == CGPoint(x: 980, y: 790))
  }

  @Test func noScreensReturnsUnclampedPosition() {
    let o = BadgePlacement.origin(
      pointer: CGPoint(x: 10, y: 10), size: size, offset: CGVector(dx: 16, dy: 16), screens: [])
    #expect(o == CGPoint(x: 26, y: -16))
  }

  @Test func badgeLargerThanScreenAlignsToScreenOrigin() {
    let tiny = CGRect(x: 0, y: 0, width: 10, height: 5)
    let o = BadgePlacement.origin(
      pointer: CGPoint(x: 5, y: 2), size: size, offset: CGVector(dx: 16, dy: 16), screens: [tiny])
    #expect(o == CGPoint(x: 0, y: 0))
  }
}
