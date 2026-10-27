import Testing
import ImeCursorCore

@Suite struct BadgeStyleTests {
  @Test func initialValuesMatchSpec() {
    let s = BadgeStyle.initial
    #expect(s.isVisible)
    #expect(s.fontSize == 12)
    #expect(s.fontWeight == .semibold)
    #expect(s.textColor == RGBA(red: 1, green: 1, blue: 1, alpha: 1))
    #expect(s.backgroundColor == RGBA(red: 0.45, green: 0.45, blue: 0.45, alpha: 0.85))
    #expect(s.width == 22)
    #expect(s.height == 18)
    #expect(s.cornerRadius == 5)
    #expect(s.offsetX == 16)
    #expect(s.offsetY == 16)
  }

  @Test func valuesInRangeAreUnchanged() {
    var s = BadgeStyle.initial
    s.fontSize = 6
    s.width = 200
    s.offsetX = -200
    #expect(s.clamped() == s)
  }

  @Test func valuesBelowRangeClampToLowerBound() {
    var s = BadgeStyle.initial
    s.fontSize = 1
    s.width = 0
    s.height = -5
    s.cornerRadius = -1
    s.offsetX = -999
    s.offsetY = -201
    let c = s.clamped()
    #expect(c.fontSize == 6)
    #expect(c.width == 4)
    #expect(c.height == 4)
    #expect(c.cornerRadius == 0)
    #expect(c.offsetX == -200)
    #expect(c.offsetY == -200)
  }

  @Test func valuesAboveRangeClampToUpperBound() {
    var s = BadgeStyle.initial
    s.fontSize = 100
    s.width = 201
    s.height = 1000
    s.cornerRadius = 101
    s.offsetX = 999
    s.offsetY = 200.5
    let c = s.clamped()
    #expect(c.fontSize == 72)
    #expect(c.width == 200)
    #expect(c.height == 200)
    #expect(c.cornerRadius == 100)
    #expect(c.offsetX == 200)
    #expect(c.offsetY == 200)
  }

  @Test func nonFiniteValuesClampIntoRange() {
    var s = BadgeStyle.initial
    s.fontSize = .nan
    s.width = .infinity
    let c = s.clamped()
    #expect(BadgeStyle.Limits.fontSize.contains(c.fontSize))
    #expect(c.width == 200)
  }

  @Test func colorComponentsClampToUnitRange() {
    let c = RGBA(red: -0.5, green: 1.5, blue: 0.3, alpha: 2).clamped()
    #expect(c == RGBA(red: 0, green: 1, blue: 0.3, alpha: 1))
  }

  @Test func styleClampAlsoClampsColors() {
    var s = BadgeStyle.initial
    s.textColor = RGBA(red: 2, green: 2, blue: 2, alpha: -1)
    #expect(s.clamped().textColor == RGBA(red: 1, green: 1, blue: 1, alpha: 0))
  }

  @Test func effectiveCornerRadiusIsLimitedByHalfOfShorterSide() {
    var s = BadgeStyle.initial
    s.width = 30
    s.height = 10
    s.cornerRadius = 100
    #expect(s.effectiveCornerRadius == 5)
    s.width = 8
    #expect(s.effectiveCornerRadius == 4)
    s.cornerRadius = 2
    #expect(s.effectiveCornerRadius == 2)
  }
}
