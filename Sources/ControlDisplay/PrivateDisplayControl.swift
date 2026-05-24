import AppKit
import CoreGraphics
import CGSPrivate

/// 显示器"真关闭"引擎。三层策略，从最彻底到最兜底依次尝试：
///
///   ① 私有 CGSConfigureDisplayEnabled（macOS 13+ Apple Silicon 主用路径）
///      —— 在显示配置事务里把显示器置为 disabled，系统会把它从 online 列表移除，
///         鼠标过不去、窗口进不去、面板断电。Lunar BlackOut "断开" 走的就是它。
///
///   ② 私有 CGSConfigureDisplayMode 模式禁用（Intel 兼容路径）
///      —— 老 Intel Mac 上的标准做法。M 芯片上模式列表通常没有"关闭模式"，
///         所以会自动跳过。
///
///   ③ 伽马全黑 + 亮度归零（公开/半公开兜底）
///      —— 私有 API 全失败时使用，面板不真正断电、鼠标仍可移过去，
///         只是视觉上全黑、背光最暗。极端情况下的最后保险。
///
/// 每台显示器记录自己被关闭时用的是哪种策略，enable() 时按对应方式恢复。
final class PrivateDisplayControl {

    static let shared = PrivateDisplayControl()

    private enum Strategy {
        case hardDisconnect   // ① 真断开
        case modeDisable      // ② 模式禁用
        case gammaBlack       // ③ 伽马全黑兜底
    }

    private struct SavedState {
        var strategy: Strategy
        var previousModeNumber: Int?
        var previousBrightness: Float?
    }

    private var savedStates: [CGDirectDisplayID: SavedState] = [:]

    /// 当前被本 App 关闭的显示器集合（无论用的哪种策略）。
    /// DisplayManager 用它来追踪"已知但已下线"的显示器，恢复时仍能找回。
    var disabledDisplays: Set<CGDirectDisplayID> {
        Set(savedStates.keys)
    }

    // MARK: - 对外接口

    func disable(_ display: CGDirectDisplayID) {
        if savedStates[display] != nil { return }   // 已经是关闭状态

        if tryHardDisconnect(display) { return }
        if tryModeDisable(display) { return }
        applyGammaBlack(display)
    }

    func enable(_ display: CGDirectDisplayID) {
        guard let state = savedStates[display] else {
            // 没记录说明本来就是开的，确保伽马是正常的（防止上次崩溃残留）。
            CGDisplayRestoreColorSyncSettings()
            return
        }

        switch state.strategy {
        case .hardDisconnect:
            reconnect(display)
        case .modeDisable:
            restoreMode(display, modeNumber: state.previousModeNumber)
        case .gammaBlack:
            CGDisplayRestoreColorSyncSettings()
            if let b = state.previousBrightness {
                DisplayServicesBridge.setBrightness(display, b)
            }
        }
        savedStates[display] = nil
    }

    // MARK: - ① 私有真断开（CGSConfigureDisplayEnabled）

    private func tryHardDisconnect(_ display: CGDirectDisplayID) -> Bool {
        guard let configureEnabled = CGSBridge.configureDisplayEnabled else {
            return false
        }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else {
            return false
        }

        let err = configureEnabled(cfg, display, false)
        guard err == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }

        // permanently 让设置跨睡眠/唤醒持续；sessionOnly 只对当前会话有效。
        // 这里用 forSession 比较安全：万一程序意外退出，重启系统屏就回来了。
        let result = CGCompleteDisplayConfiguration(cfg, .forSession)
        guard result == .success else {
            return false
        }

        // 真断开后该显示器会从 online 列表里消失。验一下。
        let stillOnline = CGDisplayIsOnline(display) != 0 && CGDisplayIsActive(display) != 0
        if stillOnline {
            // 没断开成功 —— 这种情况理论上不应该发生，但谨慎处理。
            return false
        }

        savedStates[display] = SavedState(strategy: .hardDisconnect,
                                          previousModeNumber: nil,
                                          previousBrightness: nil)
        return true
    }

    private func reconnect(_ display: CGDirectDisplayID) {
        guard let configureEnabled = CGSBridge.configureDisplayEnabled else { return }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else { return }
        _ = configureEnabled(cfg, display, true)
        _ = CGCompleteDisplayConfiguration(cfg, .forSession)
    }

    // MARK: - ② 模式禁用（Intel 路径）

    private func tryModeDisable(_ display: CGDirectDisplayID) -> Bool {
        guard CGSBridge.modeDisableSupported,
              let getCurrent = CGSBridge.getCurrentDisplayMode,
              let configure = CGSBridge.configureDisplayMode,
              let offMode = findDisabledMode(display) else {
            return false
        }

        var currentMode: Int32 = 0
        getCurrent(display, &currentMode)

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else {
            return false
        }
        _ = configure(cfg, display, Int32(offMode))
        guard CGCompleteDisplayConfiguration(cfg, .forSession) == .success else {
            return false
        }

        if CGDisplayIsActive(display) == 0 {
            savedStates[display] = SavedState(strategy: .modeDisable,
                                              previousModeNumber: Int(currentMode),
                                              previousBrightness: nil)
            return true
        }
        // 没成功 —— 把模式切回去。
        restoreMode(display, modeNumber: Int(currentMode))
        return false
    }

    private func findDisabledMode(_ display: CGDirectDisplayID) -> Int? {
        guard let getCount = CGSBridge.getNumberOfDisplayModes,
              let getDesc = CGSBridge.getDisplayModeDescription else { return nil }

        var count: Int32 = 0
        getCount(display, &count)
        guard count > 0 else { return nil }

        for i in 0..<Int(count) {
            var desc = CGSDisplayModeDescription()
            getDesc(display,
                    Int32(i),
                    &desc,
                    Int32(MemoryLayout<CGSDisplayModeDescription>.size))
            if desc.width == 0 || desc.height == 0 {
                return Int(desc.modeNumber)
            }
        }
        return nil
    }

    private func restoreMode(_ display: CGDirectDisplayID, modeNumber: Int?) {
        guard let modeNumber,
              let configure = CGSBridge.configureDisplayMode else {
            CGDisplayRestoreColorSyncSettings()
            return
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let cfg = config else { return }
        _ = configure(cfg, display, Int32(modeNumber))
        _ = CGCompleteDisplayConfiguration(cfg, .forSession)
    }

    // MARK: - ③ 伽马全黑兜底

    private func applyGammaBlack(_ display: CGDirectDisplayID) {
        let previousBrightness = DisplayServicesBridge.getBrightness(display)

        CGSetDisplayTransferByFormula(display,
                                      0, 0, 1,   // red:   min, max, gamma
                                      0, 0, 1,   // green
                                      0, 0, 1)   // blue
        DisplayServicesBridge.setBrightness(display, 0)

        savedStates[display] = SavedState(strategy: .gammaBlack,
                                          previousModeNumber: nil,
                                          previousBrightness: previousBrightness)
    }
}
