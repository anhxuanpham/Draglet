// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit

@MainActor
final class DragMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var session = DragSessionState()
    private var detector = ShakeDetector()
    private let pasteboard = NSPasteboard(name: .drag)
    private var presence = DragPresenceCache()
    private let preferences: PreferencesService
    private weak var shelf: ShelfController?

    init(preferences: PreferencesService, shelf: ShelfController) {
        self.preferences = preferences
        self.shelf = shelf
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
        if globalMonitor == nil {
            AppLog.lifecycle.error("Could not install global mouse monitor; manual shelf remains available")
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        session.mouseUp()
        detector.reset()
        presence = DragPresenceCache()
    }

    private func handle(_ event: NSEvent) {
        guard let shelf else { return }
        switch event.type {
        case .leftMouseDown:
            session.mouseDown(pasteboardChangeCount: pasteboard.changeCount)
            detector.reset()
            presence = DragPresenceCache()
            // A manual empty shelf stays available until the next outside interaction.
            if event.window !== shelf.panel { shelf.scheduleEmptyDismiss() }
        case .leftMouseUp:
            session.mouseUp()
            detector.reset()
            presence = DragPresenceCache()
            shelf.externalDragEnded()
        case .leftMouseDragged:
            guard shelf.session.state != .draggingOut else { detector.reset(); return }
            let changeCount = pasteboard.changeCount
            let hasContent = presence.update(changeCount: changeCount) {
                DragPasteboardReader.hasDragPresence(pasteboard)
            }
            let buttonIsDown = NSEvent.pressedMouseButtons & 1 != 0
            let wasDragging = session.isDraggingFiles
            let isFileDrag = session.mouseDragged(
                buttonIsDown: buttonIsDown,
                pasteboardChangeCount: changeCount,
                hasFileURLs: hasContent
            )
            if isFileDrag && !wasDragging { shelf.externalDragDetected() }
            detector.configuration = .preset(preferences.sensitivity)
            // Finder can leave the drag pasteboard unchanged until a drop target.
            // The shake itself is the filter: hold the button and shake sideways.
            if detector.add(
                MouseSample(position: NSEvent.mouseLocation, timestamp: event.timestamp),
                isDragging: session.isMouseDown && buttonIsDown
            ) {
                shelf.showShelf()
            }
        default: break
        }
    }
}
