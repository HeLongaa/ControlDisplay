import Foundation
import CoreGraphics
import CGSPrivate

/// 用 dlsym 动态加载私有 CoreGraphics(SkyLight) API。
/// 任何符号缺失都返回 nil，调用方判空后再用，App 永远不会因此崩溃。
enum CGSBridge {

    /// 同时持有 CoreGraphics 与 SkyLight 两个句柄。
    /// CGS 前缀的符号一般在 CoreGraphics 里；SLS 前缀（较新）的在 SkyLight 里。
    /// 在不同 macOS 版本上同一个功能可能只有其中一种命名，所以两边都尝试。
    private static let handles: [UnsafeMutableRawPointer] = {
        let paths = [
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        ]
        return paths.compactMap { dlopen($0, RTLD_NOW) }
    }()

    private static func load<T>(_ names: [String], as _: T.Type) -> T? {
        for handle in handles {
            for name in names {
                if let sym = dlsym(handle, name) {
                    return unsafeBitCast(sym, to: T.self)
                }
            }
        }
        return nil
    }

    // MARK: - 函数指针类型

    /// 在配置事务里启用/禁用某显示器。enabled=false 时显示器真正下线，
    /// 从 CGGetOnlineDisplayList 中消失，鼠标和窗口都进不去。
    /// macOS 13+ Apple Silicon 上的"BlackOut 真断开"用的就是它。
    typealias ConfigureDisplayEnabledFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

    // 老的"模式禁用法"，主要用于 Intel Mac 兼容路径。
    typealias GetNumberOfDisplayModesFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Void
    typealias GetDisplayModeDescriptionFn = @convention(c) (CGDirectDisplayID, Int32, UnsafeMutablePointer<CGSDisplayModeDescription>, Int32) -> Void
    typealias GetCurrentDisplayModeFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Void
    typealias ConfigureDisplayModeFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Int32) -> CGError

    // MARK: - 懒加载的函数指针

    /// 首选：真断开。
    static let configureDisplayEnabled: ConfigureDisplayEnabledFn? =
        load(["CGSConfigureDisplayEnabled", "SLSConfigureDisplayEnabled"],
             as: ConfigureDisplayEnabledFn.self)

    /// 备选：模式禁用（Intel 路径）。
    static let getNumberOfDisplayModes: GetNumberOfDisplayModesFn? =
        load(["CGSGetNumberOfDisplayModes"], as: GetNumberOfDisplayModesFn.self)

    static let getDisplayModeDescription: GetDisplayModeDescriptionFn? =
        load(["CGSGetDisplayModeDescriptionOfLength"], as: GetDisplayModeDescriptionFn.self)

    static let getCurrentDisplayMode: GetCurrentDisplayModeFn? =
        load(["CGSGetCurrentDisplayMode"], as: GetCurrentDisplayModeFn.self)

    static let configureDisplayMode: ConfigureDisplayModeFn? =
        load(["CGSConfigureDisplayMode"], as: ConfigureDisplayModeFn.self)

    static var hardDisconnectSupported: Bool { configureDisplayEnabled != nil }

    static var modeDisableSupported: Bool {
        getNumberOfDisplayModes != nil &&
        getDisplayModeDescription != nil &&
        getCurrentDisplayMode != nil &&
        configureDisplayMode != nil
    }
}
