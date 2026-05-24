import Foundation

/// 三种"启用集"模式，与菜单和快速切换面板一一对应。
enum DisplayMode: Equatable {
    case all              // 全部显示器都开
    case internalOnly     // 只开内置屏，关闭所有外接显示器
    case externalOnly     // 只开外接显示器，关闭内置屏

    var title: String {
        switch self {
        case .all: return "全部"
        case .internalOnly: return "内建"
        case .externalOnly: return "外接"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "rectangle.on.rectangle"
        case .internalOnly: return "laptopcomputer"
        case .externalOnly: return "display"
        }
    }
}
