import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 子模块
    let displayManager = DisplayManager()
    let hotKeyManager = HotKeyManager()
    var quickSwitchPanel: QuickSwitchPanel?

    // MARK: - 状态栏
    private var statusItem: NSStatusItem!

    // MARK: - 菜单项引用
    private var allItem: NSMenuItem!
    private var internalItem: NSMenuItem!
    private var externalItem: NSMenuItem!
    private var loginAtStartupItem: NSMenuItem!

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        buildMenu()
        refreshChecks()
        observeDisplayChanges()
        registerHotKey()
        Updater.checkInBackground()
    }

    func applicationWillTerminate(_ notification: Notification) {
        displayManager.apply(.all)
    }

    // MARK: - 状态栏图标

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "display", accessibilityDescription: "ControlDisplay")
            image?.isTemplate = true
            button.image = image
        }
    }

    // MARK: - 菜单

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        allItem = makeModeItem(title: "全部", symbol: "rectangle.on.rectangle", mode: .all)
        internalItem = makeModeItem(title: "内建", symbol: "laptopcomputer", mode: .internalOnly)
        externalItem = makeModeItem(title: "外接", symbol: "display", mode: .externalOnly)
        menu.addItem(allItem)
        menu.addItem(internalItem)
        menu.addItem(externalItem)

        menu.addItem(.separator())

        let quickSwitch = NSMenuItem(title: "快速切换…", action: #selector(showQuickSwitch), keyEquivalent: "p")
        quickSwitch.keyEquivalentModifierMask = [.option, .shift]
        quickSwitch.target = self
        menu.addItem(quickSwitch)

        let customizeHotKey = NSMenuItem(title: "自定义快捷键…", action: #selector(customizeHotKey), keyEquivalent: "")
        customizeHotKey.target = self
        menu.addItem(customizeHotKey)

        let refresh = NSMenuItem(title: "刷新", action: #selector(refresh), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        loginAtStartupItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLoginAtStartup), keyEquivalent: "")
        loginAtStartupItem.target = self
        menu.addItem(loginAtStartupItem)

        let checkUpdate = NSMenuItem(title: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdate.target = self
        menu.addItem(checkUpdate)

        let about = NSMenuItem(title: "关于 ControlDisplay", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func makeModeItem(title: String, symbol: String, mode: DisplayMode) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(switchMode(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = mode
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            img.isTemplate = true
            item.image = img
        }
        return item
    }

    // MARK: - 操作

    @objc private func switchMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? DisplayMode else { return }
        displayManager.apply(mode)
        refreshChecks()
    }

    @objc private func showQuickSwitch() {
        if quickSwitchPanel == nil {
            quickSwitchPanel = QuickSwitchPanel(onSelect: { [weak self] mode in
                self?.displayManager.apply(mode)
                self?.refreshChecks()
                self?.quickSwitchPanel?.orderOut(nil)
            })
        }
        quickSwitchPanel?.show(currentMode: displayManager.currentMode)
    }

    @objc private func customizeHotKey() {
        HotKeyPreferencesWindow.shared.show(currentBinding: hotKeyManager.binding) { [weak self] newBinding in
            self?.hotKeyManager.update(binding: newBinding)
        }
    }

    @objc private func refresh() {
        displayManager.refreshDisplays()
        refreshChecks()
    }

    @objc private func toggleLoginAtStartup() {
        LoginItem.toggle()
        refreshChecks()
    }

    @objc private func checkForUpdates() {
        Updater.checkManually()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ControlDisplay \(Updater.currentVersion)"
        alert.informativeText = "一个原生 macOS 菜单栏小工具，用于在内置屏与外接显示器之间快速切换。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "关闭")
        alert.addButton(withTitle: "查看源码")
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/HeLongaa/ControlDisplay")!)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 勾选状态

    private func refreshChecks() {
        allItem.state = displayManager.currentMode == .all ? .on : .off
        internalItem.state = displayManager.currentMode == .internalOnly ? .on : .off
        externalItem.state = displayManager.currentMode == .externalOnly ? .on : .off
        loginAtStartupItem.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: - 显示器热插拔监听

    private func observeDisplayChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func displaysChanged() {
        displayManager.refreshDisplays()
        if displayManager.currentMode == .externalOnly {
            let hasExternal = displayManager.onlineDisplays.contains { CGDisplayIsBuiltin($0) == 0 }
            if !hasExternal {
                displayManager.apply(.all)
            }
        }
        refreshChecks()
    }

    // MARK: - 快捷键

    private func registerHotKey() {
        hotKeyManager.onTrigger = { [weak self] in
            self?.showQuickSwitch()
        }
        hotKeyManager.registerDefault()
    }
}
