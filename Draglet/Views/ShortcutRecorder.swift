// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    var onRecord: (KeyboardShortcut?) -> Void
    func makeNSView(context: Context) -> RecorderView { RecorderView(onRecord: onRecord) }
    func updateNSView(_ view: RecorderView, context: Context) { view.onRecord = onRecord }
}

final class RecorderView: NSView {
    var onRecord: (KeyboardShortcut?) -> Void
    init(onRecord: @escaping (KeyboardShortcut?) -> Void) {
        self.onRecord = onRecord
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityLabel("Press a shortcut with Command, Control or Option. Escape cancels.")
        setAccessibilityRole(.textField)
    }
    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onRecord(nil) }
        else if let shortcut = KeyboardShortcut(event: event) { onRecord(shortcut) }
        else { NSSound.beep() }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        keyDown(with: event)
        return true
    }
}
