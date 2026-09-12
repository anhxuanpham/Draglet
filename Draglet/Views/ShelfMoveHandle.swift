// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI

struct ShelfMoveHandle: NSViewRepresentable {
    let controller: ShelfController
    func makeNSView(context: Context) -> ShelfMoveHandleView {
        let view = ShelfMoveHandleView()
        view.controller = controller
        return view
    }
    func updateNSView(_ view: ShelfMoveHandleView, context: Context) { view.controller = controller }
}

final class ShelfMoveHandleView: NSImageView {
    weak var controller: ShelfController?
    init() {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: "tray.fill", accessibilityDescription: "Move shelf")
        contentTintColor = .controlAccentColor
        imageScaling = .scaleProportionallyDown
        toolTip = "Drag to move the shelf out of the way"
        setAccessibilityLabel("Move shelf")
    }
    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func mouseDown(with event: NSEvent) {
        guard let window, controller?.isDragging == false else { return }
        let start = window.frame.origin
        window.performDrag(with: event)
        let end = window.frame.origin
        controller?.shelfMoved(by: NSPoint(x: end.x - start.x, y: end.y - start.y))
    }
}
