// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import Carbon
import Combine

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let key: String
    static let defaultShortcut = KeyboardShortcut(keyCode: 49, modifiers: UInt32(controlKey | optionKey), key: "Space")
    var isValid: Bool {
        let allowed = UInt32(cmdKey | controlKey | optionKey | shiftKey)
        return keyCode < 128 && modifiers & ~allowed == 0 && modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 && !key.isEmpty && key.count <= 20
    }
    var label: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + key
    }

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.key = key
    }

    init?(event: NSEvent) {
        var mask: UInt32 = 0
        for (flag, carbon) in [(NSEvent.ModifierFlags.command, cmdKey), (.control, controlKey), (.option, optionKey), (.shift, shiftKey)] {
            if event.modifierFlags.contains(flag) { mask |= UInt32(carbon) }
        }
        keyCode = UInt32(event.keyCode)
        modifiers = mask
        key = event.keyCode == 49 ? "Space" : (event.charactersIgnoringModifiers ?? "").uppercased()
        guard isValid, event.keyCode != 53 else { return nil }
    }
}

@MainActor
final class GlobalShortcutService: ObservableObject {
    @Published private(set) var errorMessage: String?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var subscription: AnyCancellable?
    private let action: () -> Void
    private static var nextID: UInt32 = 0
    private let identifier: UInt32

    init(preferences: PreferencesService, action: @escaping () -> Void) {
        self.action = action
        Self.nextID += 1
        identifier = Self.nextID
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID) == noErr else { return OSStatus(eventNotHandledErr) }
            let received = hotKeyID
            return MainActor.assumeIsolated {
                let service = Unmanaged<GlobalShortcutService>.fromOpaque(context).takeUnretainedValue()
                guard received.signature == 0x4452474C, received.id == service.identifier else { return OSStatus(eventNotHandledErr) }
                service.action()
                return noErr
            }
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { errorMessage = "Keyboard shortcut is unavailable. You can still use the menu bar or shake."; return }
        register(preferences.shortcut)
        subscription = preferences.$shortcut.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.register($0) }
    }

    private func register(_ shortcut: KeyboardShortcut?) {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        errorMessage = nil
        guard let shortcut else { return }
        guard shortcut.isValid else { errorMessage = "Choose a shortcut containing Command, Control or Option."; return }
        let id = EventHotKeyID(signature: 0x4452474C, id: identifier)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { errorMessage = "This shortcut could not be registered. Choose another combination; it may be in use by another app." }
    }

    func stop() {
        subscription = nil
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil; handler = nil
    }
}
