// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

struct DragSessionState {
    private(set) var isDraggingFiles = false
    private(set) var isMouseDown = false
    private var initialPasteboardChangeCount: Int?

    mutating func mouseDown(pasteboardChangeCount: Int) {
        isMouseDown = true
        isDraggingFiles = false
        initialPasteboardChangeCount = pasteboardChangeCount
    }

    @discardableResult
    mutating func mouseDragged(buttonIsDown: Bool, pasteboardChangeCount: Int, hasFileURLs: Bool) -> Bool {
        guard buttonIsDown, isMouseDown, let initialPasteboardChangeCount else {
            mouseUp()
            return false
        }
        // A drag pasteboard persists after release. A new mouse gesture must have
        // newly declared file data, not merely the previous session's file URLs.
        isDraggingFiles = pasteboardChangeCount != initialPasteboardChangeCount && hasFileURLs
        return isDraggingFiles
    }

    mutating func mouseUp() {
        isMouseDown = false
        isDraggingFiles = false
        initialPasteboardChangeCount = nil
    }
}
