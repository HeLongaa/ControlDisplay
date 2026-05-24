import AppKit

/// 屏幕中央弹出的快速切换面板：三个大按钮（全部 / 内建 / 外接），毛玻璃背景。
final class QuickSwitchPanel: NSPanel {

    private let onSelect: (DisplayMode) -> Void
    private var buttons: [DisplayMode: ModeButton] = [:]
    private let modes: [DisplayMode] = [.all, .internalOnly, .externalOnly]
    private var selectedIndex: Int = 0

    init(onSelect: @escaping (DisplayMode) -> Void) {
        self.onSelect = onSelect
        let size = NSSize(width: 360, height: 160)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = true
        isMovableByWindowBackground = true

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let visual = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        visual.material = .hudWindow
        visual.state = .active
        visual.blendingMode = .behindWindow
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 20
        visual.layer?.masksToBounds = true
        visual.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for mode in modes {
            let btn = ModeButton(mode: mode, target: self, action: #selector(buttonTapped(_:)))
            buttons[mode] = btn
            stack.addArrangedSubview(btn)
        }

        visual.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: visual.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: visual.trailingAnchor),
            stack.topAnchor.constraint(equalTo: visual.topAnchor),
            stack.bottomAnchor.constraint(equalTo: visual.bottomAnchor),
        ])

        container.addSubview(visual)
        NSLayoutConstraint.activate([
            visual.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visual.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visual.topAnchor.constraint(equalTo: container.topAnchor),
            visual.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
    }

    override var canBecomeKey: Bool { true }

    func show(currentMode: DisplayMode) {
        selectedIndex = modes.firstIndex(of: currentMode) ?? 0
        updateButtonStates()
        if let screen = NSScreen.main {
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.midY - frame.height / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func updateButtonStates() {
        for (i, mode) in modes.enumerated() {
            buttons[mode]?.setSelected(i == selectedIndex)
        }
    }

    @objc private func buttonTapped(_ sender: ModeButton) {
        onSelect(sender.mode)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: orderOut(nil)
        case 123: selectedIndex = (selectedIndex - 1 + modes.count) % modes.count; updateButtonStates()
        case 124: selectedIndex = (selectedIndex + 1) % modes.count; updateButtonStates()
        case 36, 76: onSelect(modes[selectedIndex])
        default:
            switch event.charactersIgnoringModifiers {
            case "1"?: onSelect(.all)
            case "2"?: onSelect(.internalOnly)
            case "3"?: onSelect(.externalOnly)
            default: super.keyDown(with: event)
            }
        }
    }
}

final class ModeButton: NSControl {
    let mode: DisplayMode
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var isCurrentMode = false

    init(mode: DisplayMode, target: AnyObject?, action: Selector) {
        self.mode = mode
        super.init(frame: .zero)
        self.target = target
        self.action = action
        wantsLayer = true
        layer?.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false

        if let img = NSImage(systemSymbolName: mode.symbol, accessibilityDescription: mode.title) {
            iconView.image = img.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 30, weight: .regular))
        }
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = mode.title
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ active: Bool) {
        isCurrentMode = active
        layer?.backgroundColor = active
            ? NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
            : NSColor.white.withAlphaComponent(0.08).cgColor
    }

    override func mouseDown(with event: NSEvent) { sendAction(action, to: target) }

    override func mouseEntered(with event: NSEvent) {
        if !isCurrentMode { layer?.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor }
    }
    override func mouseExited(with event: NSEvent) {
        if !isCurrentMode { layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                      options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                      owner: self, userInfo: nil))
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 96, height: 112) }
    override var acceptsFirstResponder: Bool { true }
}
