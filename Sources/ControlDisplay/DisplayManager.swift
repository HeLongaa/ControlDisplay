import AppKit
import CoreGraphics

/// 显示器枚举 + 模式切换的总入口。
/// 真关闭策略本身在 PrivateDisplayControl 里实现，这里负责"对哪些屏做什么"。
final class DisplayManager {

    private(set) var currentMode: DisplayMode = .all

    /// 当前 online 的显示器列表（不含被我们硬断开的那些）。
    private(set) var onlineDisplays: [CGDirectDisplayID] = []

    /// "是否为内置屏"的缓存。被硬断开后调用 CGDisplayIsBuiltin 可能拿不到结果，
    /// 所以在显示器还在线时就把这个属性记下来。
    private var builtinCache: [CGDirectDisplayID: Bool] = [:]

    init() {
        refreshDisplays()
    }

    // MARK: - 枚举

    func refreshDisplays() {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        onlineDisplays = Array(ids.prefix(Int(count)))

        // 更新内置缓存（只对在线的更新，避免覆盖已断开屏的旧值）。
        for id in onlineDisplays {
            builtinCache[id] = CGDisplayIsBuiltin(id) != 0
        }
    }

    /// 我们关心的全部显示器：在线的 ∪ 被本 App 断开了的。
    /// 这样切换"全部"时，已经断开的内置屏也能被找回来。
    private var knownDisplays: [CGDirectDisplayID] {
        let disabled = PrivateDisplayControl.shared.disabledDisplays
        return Array(Set(onlineDisplays).union(disabled))
    }

    private func isBuiltin(_ id: CGDirectDisplayID) -> Bool {
        if let cached = builtinCache[id] { return cached }
        let v = CGDisplayIsBuiltin(id) != 0
        builtinCache[id] = v
        return v
    }

    // MARK: - 模式应用

    func apply(_ mode: DisplayMode) {
        refreshDisplays()

        let known = knownDisplays
        let internalIDs = known.filter { isBuiltin($0) }
        let externalIDs = known.filter { !isBuiltin($0) }

        let toEnable: [CGDirectDisplayID]
        let toDisable: [CGDirectDisplayID]

        switch mode {
        case .all:
            toEnable = known
            toDisable = []
        case .internalOnly:
            guard !internalIDs.isEmpty else {
                showAlert(title: "未检测到内置屏",
                          message: "没有找到内置屏，已忽略本次操作。")
                return
            }
            toEnable = internalIDs
            toDisable = externalIDs
        case .externalOnly:
            // 安全保护：如果没有外接屏，就拒绝关闭内置屏，
            // 否则会出现"全黑、无法操作"的死局。
            guard !externalIDs.isEmpty else {
                showAlert(title: "未检测到外接显示器",
                          message: "切换到\"外接\"会关闭内置屏，但当前没有外接显示器在线，已忽略本次操作。")
                return
            }
            toEnable = externalIDs
            toDisable = internalIDs
        }

        // 顺序：先开后关。万一私有 API 失败导致全部下线，至少要开的那台先在线，
        // 避免"所有屏都黑、无法操作"。
        for d in toEnable {
            PrivateDisplayControl.shared.enable(d)
        }
        for d in toDisable {
            PrivateDisplayControl.shared.disable(d)
        }

        currentMode = mode

        // 重新枚举，让 onlineDisplays 反映实际状态。
        refreshDisplays()
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
