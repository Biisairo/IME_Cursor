import AppKit
import ApplicationServices

// 앱마다 접근성 API로 캐럿 좌표를 얻을 수 있는지 측정한다.
// 얻은 사각형에 빨간 테두리를, 입력 요소 사각형에 노란 테두리를 그린다.
// 얻은 방법이 바뀔 때마다 한 줄씩 출력한다.

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func parameterized(_ element: AXUIElement, _ name: String, _ parameter: CFTypeRef) -> CFTypeRef? {
  var value: CFTypeRef?
  guard
    AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value)
      == .success
  else { return nil }
  return value
}

func rect(_ value: CFTypeRef?) -> CGRect? {
  guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
  var rect = CGRect.zero
  guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
  return rect
}

func elementFrame(_ element: AXUIElement) -> CGRect? {
  var point = CGPoint.zero
  var size = CGSize.zero
  guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
    AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size)
  else { return nil }
  return CGRect(origin: point, size: size)
}

/// 선택 범위 끝을 캐럿으로 본다. 크기 0 범위 → 끝 앞 글자의 오른쪽 변 → 끝 글자의 왼쪽 변 순서로 묻는다.
func caretByRange(_ element: AXUIElement, field: CGRect?) -> CGRect? {
  guard let value = attribute(element, kAXSelectedTextRangeAttribute) else { return nil }
  var range = CFRange()
  guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
  let end = range.location + range.length
  let bounds = { (location: Int, length: Int) -> CGRect? in
    var copy = CFRange(location: location, length: length)
    let parameter = AXValueCreate(.cfRange, &copy)!
    return rect(parameterized(element, kAXBoundsForRangeParameterizedAttribute, parameter))
  }
  if let found = bounds(end, 0), valid(found, field) { return found }
  if end > 0, let found = bounds(end - 1, 1).map(rightEdge), valid(found, field) { return found }
  if let found = bounds(end, 1).map(leftEdge), valid(found, field) { return found }
  return nil
}

func rightEdge(_ rect: CGRect) -> CGRect {
  CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height)
}

func leftEdge(_ rect: CGRect) -> CGRect {
  CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
}

/// 텍스트 마커 함수는 공개 헤더에 없어서 실행 시간에 찾는다.
enum Marker {
  typealias CopyEnd = @convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?
  typealias Create = @convention(c) (CFAllocator?, CFTypeRef, CFTypeRef) -> Unmanaged<CFTypeRef>?

  static let handle = dlopen(
    "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
  static let copyEnd = dlsym(handle, "AXTextMarkerRangeCopyEndMarker").map {
    unsafeBitCast($0, to: CopyEnd.self)
  }
  static let create = dlsym(handle, "AXTextMarkerRangeCreate").map {
    unsafeBitCast($0, to: Create.self)
  }
}

/// WebKit, Chromium은 텍스트 마커로만 좌표를 주는 경우가 있다. 선택 범위 끝 마커로 캐럿을 구한다.
func caretByMarker(_ element: AXUIElement, field: CGRect?) -> CGRect? {
  guard let selection = attribute(element, "AXSelectedTextMarkerRange"),
    let copyEnd = Marker.copyEnd, let create = Marker.create,
    let end = copyEnd(selection)?.takeRetainedValue()
  else { return nil }
  let bounds = { (start: CFTypeRef) -> CGRect? in
    guard let range = create(nil, start, end)?.takeRetainedValue() else { return nil }
    return rect(parameterized(element, "AXBoundsForTextMarkerRange", range))
  }
  if let found = bounds(end), valid(found, field) { return found }
  if let previous = parameterized(element, "AXPreviousTextMarkerForTextMarker", end),
    let found = bounds(previous).map(rightEdge), valid(found, field)
  {
    return found
  }
  return nil
}

/// 포커스 요소 사각형 안에 있어야 한다. Chrome은 위치를 모를 때 웹 영역 원점 같은 엉뚱한 점을 준다.
func valid(_ rect: CGRect, _ field: CGRect?) -> Bool {
  // 캐럿 대신 줄이나 요소 전체 사각형을 주는 경우를 거른다.
  guard plausible(rect), rect.width <= max(rect.height, 1) else { return false }
  guard let field else { return true }
  return field.insetBy(dx: -4, dy: -4).contains(CGPoint(x: rect.minX, y: rect.midY))
}

/// AXEditableAncestor가 있거나 AXSelectedTextRange를 설정할 수 있으면 편집 가능으로 본다(A-13).
/// 탭 버튼은 AXValue를 설정할 수 있어서 AXValue로는 판별하지 않는다.
func editable(_ element: AXUIElement) -> Bool {
  if ancestor(element, "AXEditableAncestor") != nil { return true }
  var result = DarwinBoolean(false)
  return AXUIElementIsAttributeSettable(
    element, kAXSelectedTextRangeAttribute as CFString, &result) == .success && result.boolValue
}

/// Chromium은 좌표를 모를 때 x = 0, 크기 0인 사각형을 준다. 크기 0이어도 x가 있고 화면 안이면 캐럿 점으로 본다.
func plausible(_ rect: CGRect) -> Bool {
  guard rect.minX != 0 else { return false }
  let point = toScreen(rect).origin
  return NSScreen.screens.contains { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }
}

/// 한 줄 높이 이하이고 폭이 높이 이하인 요소는 요소 자체를 캐럿 칸으로 본다(xterm.js의 숨은 textarea).
let lineHeightLimit: CGFloat = 40

/// 빈 입력란은 캐럿이 시작점에 있다고 본다.
func estimatedCaret(_ element: AXUIElement, field: CGRect) -> (CGRect, String)? {
  if field.height <= lineHeightLimit, field.width <= field.height {
    return (field, "추정: 작은 요소")
  }
  let characters = attribute(element, kAXNumberOfCharactersAttribute) as? Int
  if characters == 0 {
    return (CGRect(x: field.minX, y: field.minY, width: 2, height: lineHeightLimit / 2), "추정: 빈 입력란 시작점")
  }
  return nil
}

/// AX 좌표(주 화면 왼쪽 위 원점)를 AppKit 좌표로 바꾼다.
func toScreen(_ rect: CGRect) -> CGRect {
  let height = NSScreen.screens.first?.frame.height ?? 0
  return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
}

func overlay(_ color: NSColor) -> NSWindow {
  let window = NSWindow(
    contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
  window.isOpaque = false
  window.backgroundColor = .clear
  window.level = .screenSaver
  window.ignoresMouseEvents = true
  window.collectionBehavior = [.canJoinAllSpaces, .stationary]
  let view = NSView()
  view.wantsLayer = true
  view.layer?.borderColor = color.cgColor
  view.layer?.borderWidth = 2
  window.contentView = view
  return window
}

func describe(_ value: CFTypeRef?) -> String {
  guard let value else { return "nil" }
  if CFGetTypeID(value) == AXValueGetTypeID() {
    let axValue = value as! AXValue
    var range = CFRange()
    if AXValueGetValue(axValue, .cfRange, &range) { return "range(\(range.location), \(range.length))" }
    if let found = rect(value) { return "rect(\(found))" }
  }
  return String(describing: value).prefix(80).replacingOccurrences(of: "\n", with: " ")
}

func raw(_ element: AXUIElement, _ name: String, _ parameter: CFTypeRef) -> String {
  var value: CFTypeRef?
  let error = AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value)
  return error == .success ? describe(value) : "error \(error.rawValue)"
}

/// 캐럿을 얻지 못한 요소에서 단계별 결과를 출력한다.
func diagnose(_ element: AXUIElement) {
  var names: CFArray?
  AXUIElementCopyParameterizedAttributeNames(element, &names)
  let parameterNames = (names as? [String]) ?? []
  print("  subrole: \(describe(attribute(element, kAXSubroleAttribute)))")
  print("  description: \(describe(attribute(element, kAXDescriptionAttribute)))")
  print("  characters: \(describe(attribute(element, kAXNumberOfCharactersAttribute)))")
  print("  parameterized 개수: \(parameterNames.count)")
  let selected = attribute(element, kAXSelectedTextRangeAttribute)
  print("  AXSelectedTextRange: \(describe(selected))")
  if let selected {
    var range = CFRange()
    AXValueGetValue(selected as! AXValue, .cfRange, &range)
    for candidate in [range, CFRange(location: range.location, length: 1),
      CFRange(location: max(range.location - 1, 0), length: 1)]
    {
      var copy = candidate
      let parameter = AXValueCreate(.cfRange, &copy)!
      print("  BoundsForRange(\(candidate.location), \(candidate.length)): \(raw(element, kAXBoundsForRangeParameterizedAttribute, parameter))")
    }
  }
  let marker = attribute(element, "AXSelectedTextMarkerRange")
  print("  AXSelectedTextMarkerRange: \(marker == nil ? "nil" : "있음")")
  if let marker {
    print("  BoundsForTextMarkerRange: \(raw(element, "AXBoundsForTextMarkerRange", marker))")
  }
}

func settable(_ element: AXUIElement, _ name: String) -> String {
  var result = DarwinBoolean(false)
  guard AXUIElementIsAttributeSettable(element, name as CFString, &result) == .success else {
    return "error"
  }
  return result.boolValue ? "예" : "아니오"
}

func summary(_ element: AXUIElement?) -> String {
  guard let element else { return "nil" }
  let role = attribute(element, kAXRoleAttribute) as? String ?? "?"
  let description = attribute(element, kAXRoleDescriptionAttribute) as? String ?? "?"
  return "\(role) (\(description))"
}

func ancestor(_ element: AXUIElement, _ name: String) -> AXUIElement? {
  guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
    return nil
  }
  return (value as! AXUIElement)
}

/// 편집 가능 여부를 판별할 후보 신호를 출력한다(A-13).
func editability(_ element: AXUIElement) {
  print("  [편집 판별] subrole: \(describe(attribute(element, kAXSubroleAttribute)))")
  print("    AXValue 설정 가능: \(settable(element, kAXValueAttribute))")
  print("    AXSelectedTextRange 설정 가능: \(settable(element, kAXSelectedTextRangeAttribute))")
  print("    AXEditableAncestor: \(summary(ancestor(element, "AXEditableAncestor")))")
  print("    AXHighestEditableAncestor: \(summary(ancestor(element, "AXHighestEditableAncestor")))")
  print("    AXFocusableAncestor: \(summary(ancestor(element, "AXFocusableAncestor")))")
  guard let range = attribute(element, "AXSelectedTextMarkerRange") else {
    print("    캐럿 마커의 요소: 마커 없음")
    return
  }
  var marked: CFTypeRef?
  AXUIElementCopyParameterizedAttributeValue(
    element, "AXUIElementForTextMarker" as CFString, range, &marked)
  guard let marked, CFGetTypeID(marked) == AXUIElementGetTypeID() else {
    print("    캐럿 마커의 요소: 구하지 못함")
    return
  }
  let markedElement = marked as! AXUIElement
  print("    캐럿 마커의 요소: \(summary(markedElement))")
  print("      AXEditableAncestor: \(summary(ancestor(markedElement, "AXEditableAncestor")))")
}

@MainActor
final class Probe {
  let caretWindow = overlay(.systemRed)
  let fieldWindow = overlay(.systemYellow)
  var enhanced = Set<pid_t>()
  let systemWide = AXUIElementCreateSystemWide()

  init() {
    AXUIElementSetMessagingTimeout(systemWide, 0.05)
  }
  var last = ""

  func tick() {
    guard let app = NSWorkspace.shared.frontmostApplication else { return }
    let pid = app.processIdentifier
    let appElement = AXUIElementCreateApplication(pid)
    // Chromium, Electron은 이 값을 켜야 웹 내용의 접근성 트리를 만든다.
    if enhanced.insert(pid).inserted {
      AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
      // Chrome은 AXManualAccessibility를 무시하고 이 값에만 반응한다는 보고가 있다. 부작용이 있어 선택으로만 켠다.
      if useEnhanced {
        let error = AXUIElementSetAttributeValue(
          appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        print("AXEnhancedUserInterface 설정: \(app.localizedName ?? "?") 결과 \(error.rawValue)")
      }
    }
    // Spotlight처럼 맨 앞 앱이 되지 않고 포커스만 가져가는 창이 있어서 시스템 전체에서 묻는다.
    guard let focused = attribute(systemWide, kAXFocusedUIElementAttribute) else {
      report("\(app.localizedName ?? "?")\t포커스 요소 없음", caret: nil, field: nil)
      return
    }
    let element = focused as! AXUIElement
    var owner: pid_t = 0
    AXUIElementGetPid(element, &owner)
    let name = NSRunningApplication(processIdentifier: owner)?.localizedName ?? "pid \(owner)"
    let role = attribute(element, kAXRoleAttribute) as? String ?? "?"
    let field = elementFrame(element)
    guard editable(element) else {
      report("\(name)\t\(role)\t편집 불가, 표시 안 함", caret: nil, field: nil)
      return
    }
    if let caret = caretByRange(element, field: field) {
      report("\(name)\t\(role)\tBoundsForRange", caret: caret, field: field) {
        editability(element)
      }
    } else if let caret = caretByMarker(element, field: field) {
      report("\(name)\t\(role)\tTextMarker", caret: caret, field: field) { editability(element) }
    } else if let field, let (caret, method) = estimatedCaret(element, field: field) {
      report("\(name)\t\(role)\t\(method)", caret: caret, field: field, estimated: true) {
        editability(element)
      }
    } else if field != nil {
      report("\(name)\t\(role)\t캐럿 없음, 요소 사각형만", caret: nil, field: field) {
        editability(element)
        diagnose(element)
      }
    } else {
      report("\(name)\t\(role)\t좌표 없음", caret: nil, field: nil) {
        editability(element)
        diagnose(element)
      }
    }
  }

  func report(
    _ line: String, caret: CGRect?, field: CGRect?, estimated: Bool = false,
    onChange: () -> Void = {}
  ) {
    caretWindow.contentView?.layer?.borderColor =
      (estimated ? NSColor.systemOrange : NSColor.systemRed).cgColor
    show(caretWindow, caret.map { $0.insetBy(dx: -3, dy: -3) })
    show(fieldWindow, field)
    let detail = caret.map { "\t\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? ""
    if line != last {
      print(line + detail)
      last = line
      onChange()
    }
  }

  func show(_ window: NSWindow, _ rect: CGRect?) {
    guard let rect else {
      window.orderOut(nil)
      return
    }
    window.setFrame(toScreen(rect), display: true)
    window.orderFrontRegardless()
  }
}

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(options) else {
  print("접근성 권한이 필요하다. 시스템 설정에서 이 프로브를 실행한 터미널 앱을 허용한 뒤 다시 실행한다.")
  exit(1)
}
setvbuf(stdout, nil, _IOLBF, 0)
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let probe = MainActor.assumeIsolated { Probe() }
// 인자: [확인 주기(초), 기본 0.1] [--enhanced]
let arguments = CommandLine.arguments.dropFirst()
let interval = arguments.compactMap(TimeInterval.init).first ?? 0.1
let useEnhanced = arguments.contains("--enhanced")
let timer = Timer(timeInterval: interval, repeats: true) { _ in
  MainActor.assumeIsolated { probe.tick() }
}
RunLoop.main.add(timer, forMode: .common)
print("확인 주기 \(interval)초, AXEnhancedUserInterface \(useEnhanced ? "켬" : "끔")\n앱\t역할\t방법\t캐럿(AX 좌표)")
application.run()
