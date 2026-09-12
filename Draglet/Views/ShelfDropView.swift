// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI

final class ShelfDropView: NSVisualEffectView {
    weak var controller: ShelfController?

    init(controller: ShelfController) {
        self.controller = controller
        super.init(frame: .zero)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = Constants.cornerRadius
        layer?.masksToBounds = true
        registerForDraggedTypes(DragPasteboardReader.supportedTypes)

        let hosting = NSHostingView(rootView: ShelfView(controller: controller))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrag(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrag(sender) }

    private func updateDrag(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let controller, controller.session.state != .draggingOut,
              DragPasteboardReader.hasSupportedContent(sender.draggingPasteboard) else { return [] }
        let operation = DragPasteboardReader.safeOperation(from: sender.draggingSourceOperationMask)
        controller.setDropHighlight(!operation.isEmpty)
        return operation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { controller?.setDropHighlight(false) }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !updateDrag(sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !updateDrag(sender).isEmpty else { return false }
        controller?.setDropHighlight(false)
        return controller?.receive(sender.draggingPasteboard) ?? false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) { controller?.setDropHighlight(false) }
}
