// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI

struct FileDragSource<Content: View>: NSViewRepresentable {
    let controller: ShelfController
    let itemIDs: Set<UUID>
    let label: String
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> FileDragSourceView<Content> {
        FileDragSourceView(controller: controller, ids: itemIDs, label: label, content: content())
    }

    func updateNSView(_ nsView: FileDragSourceView<Content>, context: Context) {
        nsView.itemIDs = itemIDs
        nsView.hosting.rootView = content()
        nsView.setAccessibilityLabel(label)
        nsView.setAccessibilitySelected(itemIDs.count == 1 && itemIDs.first.map { controller.selection.ids.contains($0) } == true)
    }
}

final class FileDragSourceView<Content: View>: NSView, NSDraggingSource {
    weak var controller: ShelfController?
    var itemIDs: Set<UUID>
    let hosting: NSHostingView<Content>
    private var mouseDownPoint: NSPoint?
    private var activeSession: NSDraggingSession?
    private var clickedSelectedItem: UUID?

    init(controller: ShelfController, ids: Set<UUID>, label: String, content: Content) {
        self.controller = controller
        itemIDs = ids
        hosting = NSHostingView(rootView: content)
        super.init(frame: .zero)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.row)
        setAccessibilityLabel(label)
        setAccessibilityHelp("Drag to Finder or another app. Your original file stays in place.")
    }

    required init?(coder: NSCoder) { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(convert(point, from: superview)) ? self : nil }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func accessibilityPerformPress() -> Bool {
        guard itemIDs.count == 1, let id = itemIDs.first, let controller, !controller.isDragging else { return false }
        controller.select(id)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        if itemIDs.count == 1, let id = itemIDs.first, let controller {
            let modifiers = event.modifierFlags.intersection([.command, .shift])
            if controller.selection.ids.contains(id), modifiers.isEmpty { clickedSelectedItem = id }
            else { controller.select(id, modifiers: modifiers) }
            if event.clickCount == 2 { controller.preview([id]); mouseDownPoint = nil }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let id = clickedSelectedItem { controller?.select(id) }
        clickedSelectedItem = nil
        mouseDownPoint = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let controller, let id = itemIDs.first, itemIDs.count == 1 else { return nil }
        if !controller.selection.ids.contains(id) { controller.select(id) }
        let menu = NSMenu()
        for (title, action) in [("Quick Look", #selector(previewItem)), ("Reveal in Finder", #selector(revealItem)),
                                ("Remove from Shelf", #selector(removeItems))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            if title == "Reveal in Finder", controller.session.items.first(where: { $0.id == id })?.kind != .file { continue }
            menu.addItem(item)
        }
        return menu
    }

    @objc private func previewItem() { if let controller { controller.preview(controller.selection.ids) } }
    @objc private func revealItem() { if let id = itemIDs.first { controller?.reveal(id) } }
    @objc private func removeItems() { if let controller { controller.remove(controller.selection.ids) } }

    override func mouseDragged(with event: NSEvent) {
        guard activeSession == nil, let start = mouseDownPoint, let controller else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) >= 4 else { return }
        mouseDownPoint = nil
        clickedSelectedItem = nil
        let ids = itemIDs.count == 1 ? controller.dragIDs(for: itemIDs.first!) : itemIDs
        let items = controller.beginDrag(ids: ids)
        guard !items.isEmpty else { return }
        let draggingItems = items.enumerated().map { index, item in
            let dragging = NSDraggingItem(pasteboardWriter: item.pasteboardWriter())
            let icon = item.icon
            let offset = CGFloat(min(index, 3)) * 3
            dragging.setDraggingFrame(
                NSRect(x: point.x - 20 + offset, y: point.y - 20 - offset, width: 40, height: 40),
                contents: icon
            )
            return dragging
        }
        activeSession = beginDraggingSession(with: draggingItems, event: event, source: self)
        activeSession?.animatesToStartingPositionsOnCancelOrFail = true
        activeSession?.draggingFormation = .pile
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .link]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard activeSession === session else { return }
        activeSession = nil
        controller?.endDrag(operation: operation)
    }
}
