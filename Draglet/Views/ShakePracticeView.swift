// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI

struct ShakePracticeView: NSViewRepresentable {
    let sensitivity: ShakeSensitivity
    var onRecognized: () -> Void
    func makeNSView(context: Context) -> ShakePracticePad { ShakePracticePad() }
    func updateNSView(_ view: ShakePracticePad, context: Context) {
        view.detector.configuration = .preset(sensitivity)
        view.onRecognized = onRecognized
    }
}

final class ShakePracticePad: NSView {
    var detector = ShakeDetector()
    var onRecognized: (() -> Void)?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        setAccessibilityElement(true)
        setAccessibilityLabel("Shake practice area. Hold the mouse button and move sideways to practice. Use the keyboard shortcut as an alternative.")
    }
    required init?(coder: NSCoder) { nil }
    override func mouseDown(with event: NSEvent) { detector.reset() }
    override func mouseUp(with event: NSEvent) { detector.reset() }
    override func mouseDragged(with event: NSEvent) {
        if detector.add(MouseSample(position: event.locationInWindow, timestamp: event.timestamp), isDragging: true) { onRecognized?() }
    }
}
