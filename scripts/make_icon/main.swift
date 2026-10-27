import AppKit

// 사용법: make_icon <출력 .iconset 디렉터리> <미리보기 png 디렉터리>
let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
let previews = URL(fileURLWithPath: CommandLine.arguments[2])
let canvas: CGFloat = 1024

func render(pixels: Int) -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  let context = NSGraphicsContext(bitmapImageRep: rep)!
  let cg = context.cgContext
  let scale = CGFloat(pixels) / canvas
  cg.translateBy(x: 0, y: CGFloat(pixels))
  cg.scaleBy(x: scale, y: -scale)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
  IconArtwork.drawAppIcon()
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
try? fm.createDirectory(at: iconset, withIntermediateDirectories: true)
try? fm.createDirectory(at: previews, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
  try! render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
  try! render(pixels: points * 2).write(
    to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let menu = IconArtwork.menuBarImage()
for (name, dark) in [("menubar_light", false), ("menubar_dark", true)] {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 72, pixelsHigh: 72, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = NSSize(width: 18, height: 18)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  (dark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
  NSRect(x: 0, y: 0, width: 18, height: 18).fill()
  let tinted = NSImage(size: menu.size, flipped: false) { rect in
    menu.draw(in: rect)
    (dark ? NSColor.white : NSColor.black).set()
    rect.fill(using: .sourceAtop)
    return true
  }
  tinted.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .png, properties: [:])!.write(
    to: previews.appendingPathComponent("\(name).png"))
}
try! render(pixels: 512).write(to: previews.appendingPathComponent("app_512.png"))
try! render(pixels: 32).write(to: previews.appendingPathComponent("app_32.png"))
