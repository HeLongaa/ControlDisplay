import Foundation
import ServiceManagement

/// 用 macOS 13+ 的 SMAppService 管理"登录时启动"。
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("切换登录启动失败: \(error.localizedDescription)")
        }
    }
}
