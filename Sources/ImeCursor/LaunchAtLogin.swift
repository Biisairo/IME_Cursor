import ServiceManagement

enum LaunchAtLogin {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  /// 실패하면 오류 설명을 반환한다.
  static func set(_ enabled: Bool) -> String? {
    let service = SMAppService.mainApp
    let result = Result { enabled ? try service.register() : try service.unregister() }
    if case .failure(let error) = result {
      return error.localizedDescription
    }
    return nil
  }
}
