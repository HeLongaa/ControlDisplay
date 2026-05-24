import AppKit
import Carbon.HIToolbox

struct HotKeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = HotKeyBinding(keyCode: UInt32(kVK_ANSI_P),
                                         carbonModifiers: UInt32(optionKey | shiftKey))

    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: UInt32) -> String {
        let map: [Int: String] = [
            kVK_ANSI_A:"A", kVK_ANSI_B:"B", kVK_ANSI_C:"C", kVK_ANSI_D:"D",
            kVK_ANSI_E:"E", kVK_ANSI_F:"F", kVK_ANSI_G:"G", kVK_ANSI_H:"H",
            kVK_ANSI_I:"I", kVK_ANSI_J:"J", kVK_ANSI_K:"K", kVK_ANSI_L:"L",
            kVK_ANSI_M:"M", kVK_ANSI_N:"N", kVK_ANSI_O:"O", kVK_ANSI_P:"P",
            kVK_ANSI_Q:"Q", kVK_ANSI_R:"R", kVK_ANSI_S:"S", kVK_ANSI_T:"T",
            kVK_ANSI_U:"U", kVK_ANSI_V:"V", kVK_ANSI_W:"W", kVK_ANSI_X:"X",
            kVK_ANSI_Y:"Y", kVK_ANSI_Z:"Z",
            kVK_ANSI_0:"0", kVK_ANSI_1:"1", kVK_ANSI_2:"2", kVK_ANSI_3:"3",
            kVK_ANSI_4:"4", kVK_ANSI_5:"5", kVK_ANSI_6:"6", kVK_ANSI_7:"7",
            kVK_ANSI_8:"8", kVK_ANSI_9:"9",
            kVK_Space:"Space", kVK_Return:"↩"
        ]
        return map[Int(keyCode)] ?? "?"
    }
}

final class HotKeyManager {
    var onTrigger: (() -> Void)?
    private(set) var binding: HotKeyBinding
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x4354524C
    private let defaultsKey = "HotKeyBinding"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(HotKeyBinding.self, from: data) {
            binding = saved
        } else {
            binding = .default
        }
    }

    func registerDefault() { register(binding) }

    func update(binding newBinding: HotKeyBinding) {
        binding = newBinding
        if let data = try? JSONEncoder().encode(newBinding) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        register(newBinding)
    }

    private func register(_ binding: HotKeyBinding) {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData -> OSStatus in
            guard let userData, let eventRef else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async { manager.onTrigger?() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(binding.keyCode, binding.carbonModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandler { RemoveEventHandler(ref); eventHandler = nil }
    }

    deinit { unregister() }
}
