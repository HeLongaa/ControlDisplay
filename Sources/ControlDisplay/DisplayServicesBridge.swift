import Foundation
import CoreGraphics

/// 通过 dlopen 动态加载私有框架 DisplayServices，用于读写显示器亮度。
/// 这是兜底策略里"把背光降到最低"用的；框架/符号缺失时所有调用安全地变成空操作。
enum DisplayServicesBridge {

    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
               RTLD_NOW)
    }()

    private static let setFunc: SetBrightnessFunc? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFunc.self)
    }()

    private static let getFunc: GetBrightnessFunc? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFunc.self)
    }()

    /// 设置亮度（0.0 ~ 1.0）。失败/不支持时静默忽略。
    static func setBrightness(_ display: CGDirectDisplayID, _ value: Float) {
        _ = setFunc?(display, max(0, min(1, value)))
    }

    /// 读取当前亮度，读不到返回 nil。
    static func getBrightness(_ display: CGDirectDisplayID) -> Float? {
        guard let getFunc else { return nil }
        var value: Float = 0
        let result = getFunc(display, &value)
        return result == 0 ? value : nil
    }
}
