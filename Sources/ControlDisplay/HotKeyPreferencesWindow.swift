import AppKit
import Carbon.HIToolbox

final class HotKeyPreferencesWindow: NSObject, NSWindowDelegate {

    static let shared = HotKeyPreferencesWindow()
    private var window: NSWindow?
    private var recordField: HotKeyRecorderField?
    private var onSave: ((HotKeyBinding) -> Void)?
    private var pendingBinding: HotKeyBinding?

    func show(currentBinding: HotKeyBinding, onSave: @escaping (HotKeyBinding) -> Void) {
        self.onSave = onSave
        self.pendingBinding = currentBinding
        if window == nil { buildWindow() }
        recordField?.binding = currentBinding
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 180),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "自定义快捷键"
        win.delegate = self
        win.isReleasedWhenClosed = false

        let content = NSView(frame: win.contentLayoutRect)
        content.autoresizingMask = [.width, .height]

        let title = NSTextField(labelWithString: "快速切换显示器的全局快捷键")
        title.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        title.frame = NSRect(x: 24, y: 122, width: 332, height: 20)
        content.addSubview(title)

        let hint = NSTextField(labelWithString: "点击下方方框，然后按下想要的组合键")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 24, y: 100, width: 332, height: 18)
        content.addSubview(hint)

        let recorder = HotKeyRecorderField(frame: NSRect(x: 24, y: 56, width: 332, height: 34))
        recorder.onCapture = { [weak self] binding in self?.pendingBinding = binding }
        recordField = recorder
        content.addSubview(recorder)

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 268, y: 14, width: 88, height: 32)
        content.addSubview(saveBtn)

        let cancelBtn = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.frame = NSRect(x: 176, y: 14, width: 88, height: 32)
        content.addSubview(cancelBtn)

        win.contentView = content
        window = win
    }

    @objc private func save() {
        if let binding = pendingBinding { onSave?(binding) }
        window?.close()
    }
    @objc private func cancel() { window?.close() }
}

final class HotKeyRecorderField: NSView {
    var onCapture: ((HotKeyBinding) -> Void)?
    var binding: HotKeyBinding? { didSet { needsDisplay = true } }
    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12)
                     : NSColor.textBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text = isRecording ? "请按下组合键…" : (binding?.displayString ?? "点击以录制")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                  withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        var carbonMods: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
        guard carbonMods != 0 else { NSSound.beep(); return }
        let newBinding = HotKeyBinding(keyCode: UInt32(event.keyCode), carbonModifiers: carbonMods)
        binding = newBinding
        isRecording = false
        onCapture?(newBinding)
    }

    override func resignFirstResponder() -> Bool { isRecording = false; return true }
}
