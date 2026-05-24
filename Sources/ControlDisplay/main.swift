import AppKit

// 菜单栏 App 入口。Info.plist 里 LSUIElement = true，所以不显示 Dock 图标。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
