import Carbon
import ImeCursorCore

struct TISInputSourceProvider: InputSourceProvider {
  func current() -> InputSourceInfo? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
    return info(of: source)
  }

  func enabled() -> [InputSourceInfo] {
    let filter = [
      kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
      kTISPropertyInputSourceIsSelectCapable as String: true,
    ] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
    else { return [] }
    return list.compactMap(info(of:))
  }

  private func info(of source: TISInputSource) -> InputSourceInfo? {
    guard let id: String = property(of: source, kTISPropertyInputSourceID) else { return nil }
    let languages: [String]? = property(of: source, kTISPropertyInputSourceLanguages)
    return InputSourceInfo(
      id: id, localizedName: property(of: source, kTISPropertyLocalizedName),
      language: languages?.first)
  }

  private func property<T>(of source: TISInputSource, _ key: CFString) -> T? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? T
  }
}
