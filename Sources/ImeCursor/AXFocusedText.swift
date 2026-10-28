import ApplicationServices
import ImeCursorCore

/// 텍스트 마커 함수는 공개 헤더에 없어서 실행 시간에 찾는다(FR-CARET-5 (2)).
/// 마커는 다른 프로세스가 준 값이므로, 함수에 넘기기 전에 타입을 확인한다.
private enum TextMarker {
  typealias CopyEnd = @convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?
  typealias Create = @convention(c) (CFAllocator?, CFTypeRef, CFTypeRef) -> Unmanaged<CFTypeRef>?
  typealias TypeID = @convention(c) () -> CFTypeID

  nonisolated(unsafe) static let handle = dlopen(
    "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
  static let copyEnd = dlsym(handle, "AXTextMarkerRangeCopyEndMarker").map {
    unsafeBitCast($0, to: CopyEnd.self)
  }
  static let create = dlsym(handle, "AXTextMarkerRangeCreate").map {
    unsafeBitCast($0, to: Create.self)
  }
  static let rangeTypeID = dlsym(handle, "AXTextMarkerRangeGetTypeID").map {
    unsafeBitCast($0, to: TypeID.self)()
  }
  static let markerTypeID = dlsym(handle, "AXTextMarkerGetTypeID").map {
    unsafeBitCast($0, to: TypeID.self)()
  }

  static func isRange(_ value: CFTypeRef) -> Bool {
    rangeTypeID.map { CFGetTypeID(value) == $0 } ?? false
  }

  static func isMarker(_ value: CFTypeRef) -> Bool {
    markerTypeID.map { CFGetTypeID(value) == $0 } ?? false
  }
}

/// AX 포커스 요소를 `FocusedText`로 감싼다(QA-4).
struct AXFocusedText: FocusedText {
  let element: AXUIElement

  var hasEditableAncestor: Bool {
    attribute("AXEditableAncestor") != nil
  }

  var isSelectedRangeSettable: Bool {
    var settable = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(
      element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success
      && settable.boolValue
  }

  var frame: CGRect? {
    var point = CGPoint.zero
    var size = CGSize.zero
    guard let position = axValue(attribute(kAXPositionAttribute)),
      let extent = axValue(attribute(kAXSizeAttribute)),
      AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(extent, .cgSize, &size)
    else { return nil }
    return CGRect(origin: point, size: size)
  }

  var characterCount: Int? {
    attribute(kAXNumberOfCharactersAttribute) as? Int
  }

  var selectedRange: TextSpan? {
    var range = CFRange()
    guard let value = axValue(attribute(kAXSelectedTextRangeAttribute)),
      AXValueGetValue(value, .cfRange, &range)
    else { return nil }
    return TextSpan(location: range.location, length: range.length)
  }

  func bounds(for range: TextSpan) -> CGRect? {
    var value = CFRange(location: range.location, length: range.length)
    guard let parameter = AXValueCreate(.cfRange, &value) else { return nil }
    return rect(parameterized(kAXBoundsForRangeParameterizedAttribute, parameter))
  }

  func collapsedMarkerBounds() -> CGRect? {
    guard let end = endMarker() else { return nil }
    return markerBounds(from: end, to: end)
  }

  func markerBoundsBeforeEnd() -> CGRect? {
    guard let end = endMarker(),
      let previous = parameterized("AXPreviousTextMarkerForTextMarker", end),
      TextMarker.isMarker(previous)
    else { return nil }
    return markerBounds(from: previous, to: end)
  }

  private func endMarker() -> CFTypeRef? {
    guard let selection = attribute("AXSelectedTextMarkerRange"), TextMarker.isRange(selection),
      let copyEnd = TextMarker.copyEnd, let end = copyEnd(selection)?.takeRetainedValue(),
      TextMarker.isMarker(end)
    else { return nil }
    return end
  }

  private func markerBounds(from start: CFTypeRef, to end: CFTypeRef) -> CGRect? {
    guard let create = TextMarker.create, let range = create(nil, start, end)?.takeRetainedValue()
    else { return nil }
    return rect(parameterized("AXBoundsForTextMarkerRange", range))
  }

  private func attribute(_ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  private func parameterized(_ name: String, _ parameter: CFTypeRef) -> CFTypeRef? {
    var value: CFTypeRef?
    guard
      AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value)
        == .success
    else { return nil }
    return value
  }

  private func rect(_ value: CFTypeRef?) -> CGRect? {
    var rect = CGRect.zero
    guard let value = axValue(value), AXValueGetValue(value, .cgRect, &rect) else { return nil }
    return rect
  }

  /// 다른 프로세스가 준 값이므로 강제 캐스팅하지 않고 타입을 확인한다.
  private func axValue(_ value: CFTypeRef?) -> AXValue? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    return (value as! AXValue)
  }
}
