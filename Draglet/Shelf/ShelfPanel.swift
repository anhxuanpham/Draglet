// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit

final class ShelfPanel: NSPanel {
    var allowsKeyboard = false
    var handleKey: ((NSEvent) -> Bool)?
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.shelfWidth, height: Constants.minimumHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
        title = "Draglet Shelf"
        setAccessibilityLabel("Draglet file shelf")
    }

    override var canBecomeKey: Bool { allowsKeyboard }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {
        if handleKey?(event) != true { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isKeyWindow, handleKey?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}
