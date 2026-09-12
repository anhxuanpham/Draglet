// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import XCTest
@testable import Draglet

final class DragSessionStateTests: XCTestCase {
    func testNewFilePasteboardWithinMouseGestureIsRequired() {
        var state = DragSessionState()
        state.mouseDown(pasteboardChangeCount: 10)
        XCTAssertFalse(state.mouseDragged(buttonIsDown: true, pasteboardChangeCount: 10, hasFileURLs: true))
        XCTAssertTrue(state.mouseDragged(buttonIsDown: true, pasteboardChangeCount: 11, hasFileURLs: true))
        state.mouseUp()
        XCTAssertFalse(state.isDraggingFiles)
        state.mouseDown(pasteboardChangeCount: 11)
        XCTAssertFalse(state.mouseDragged(buttonIsDown: true, pasteboardChangeCount: 11, hasFileURLs: true))
    }

    func testTextDragAndReleasedButtonAreNotFileDrags() {
        var state = DragSessionState()
        state.mouseDown(pasteboardChangeCount: 10)
        XCTAssertFalse(state.mouseDragged(buttonIsDown: true, pasteboardChangeCount: 11, hasFileURLs: false))
        XCTAssertFalse(state.mouseDragged(buttonIsDown: false, pasteboardChangeCount: 12, hasFileURLs: true))
        XCTAssertFalse(state.isMouseDown)
    }

    func testStartingMidGestureAbstainsFromStalePasteboard() {
        var state = DragSessionState()
        XCTAssertFalse(state.mouseDragged(buttonIsDown: true, pasteboardChangeCount: 10, hasFileURLs: true))
    }

    func testMouseDownWithoutPasteboardChangeStillTracksForShake() {
        var state = DragSessionState()
        state.mouseDown(pasteboardChangeCount: 16)
        XCTAssertFalse(state.mouseDragged(buttonIsDown: true, pasteboardChangeCount: 16, hasFileURLs: true))
        XCTAssertTrue(state.isMouseDown)
        XCTAssertFalse(state.isDraggingFiles)
        XCTAssertFalse(state.mouseDragged(buttonIsDown: false, pasteboardChangeCount: 17, hasFileURLs: true))
        XCTAssertFalse(state.isMouseDown)
    }
}
