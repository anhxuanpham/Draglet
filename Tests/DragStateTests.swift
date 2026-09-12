// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import XCTest
@testable import Draglet

final class DragStateTests: XCTestCase {
    private func item(_ name: String) -> ShelfItem { ShelfItem(url: URL(fileURLWithPath: "/tmp/\(name)")) }

    func testCompleteSingleUseWorkflow() {
        var session = ShelfSession()
        let file = item("one")
        session.detectDrag()
        XCTAssertEqual(session.state, .dragDetected)
        session.show()
        XCTAssertEqual(session.state, .visible)
        XCTAssertEqual(session.receive([file]), 1)
        XCTAssertEqual(session.state, .holding)
        XCTAssertEqual(session.beginDrag(ids: [file.id]), [file])
        XCTAssertEqual(session.state, .draggingOut)
        session.endDrag(succeeded: true, removeAfterSuccess: true)
        XCTAssertTrue(session.items.isEmpty)
        XCTAssertTrue(session.beginDismiss())
        session.finishDismiss()
        XCTAssertEqual(session.state, .idle)
    }

    func testCancelledDragKeepsEveryItem() {
        var session = ShelfSession()
        let items = [item("one"), item("two")]
        session.receive(items)
        _ = session.beginDrag(ids: [items[0].id])
        session.endDrag(succeeded: false, removeAfterSuccess: true)
        XCTAssertEqual(session.items, items)
        XCTAssertEqual(session.state, .holding)
        XCTAssertTrue(session.outgoingIDs.isEmpty)
    }

    func testSuccessfulDragRemovesOnlySelectedReferences() {
        var session = ShelfSession()
        let items = [item("one"), item("two"), item("three")]
        session.receive(items)
        _ = session.beginDrag(ids: [items[0].id, items[2].id])
        session.endDrag(succeeded: true, removeAfterSuccess: true)
        XCTAssertEqual(session.items, [items[1]])
        XCTAssertFalse(session.beginDismiss())
    }

    func testKeepPreferencePreservesItemsAfterSuccess() {
        var session = ShelfSession()
        let file = item("one")
        session.receive([file])
        _ = session.beginDrag(ids: [file.id])
        session.endDrag(succeeded: true, removeAfterSuccess: false)
        XCTAssertEqual(session.items, [file])
    }

    func testDeduplicationWithinAndAcrossDrops() {
        var session = ShelfSession()
        XCTAssertEqual(session.receive([item("one"), item("one")]), 1)
        XCTAssertEqual(session.receive([item("one"), item("two")]), 1)
        XCTAssertEqual(session.items.count, 2)
    }

    func testReopenAndNewDropInvalidateDismissal() {
        var session = ShelfSession()
        session.show()
        XCTAssertTrue(session.beginDismiss())
        session.show()
        session.finishDismiss()
        XCTAssertEqual(session.state, .visible)
        XCTAssertTrue(session.beginDismiss())
        session.receive([item("new")])
        session.finishDismiss()
        XCTAssertEqual(session.state, .holding)
        XCTAssertEqual(session.items.count, 1)
    }

    func testOutgoingDragCannotDropOntoItselfOrBeCleared() {
        var session = ShelfSession()
        let file = item("one")
        session.receive([file])
        _ = session.beginDrag(ids: [file.id])
        session.remove([file.id])
        XCTAssertEqual(session.receive([item("two")]), 0)
        session.show()
        XCTAssertFalse(session.beginDismiss())
        XCTAssertEqual(session.items, [file])
        XCTAssertEqual(session.state, .draggingOut)
    }

    func testUnknownSelectionAndLateCompletionDoNothing() {
        var session = ShelfSession()
        let file = item("one")
        session.receive([file])
        XCTAssertTrue(session.beginDrag(ids: [UUID()]).isEmpty)
        session.endDrag(succeeded: true, removeAfterSuccess: true)
        XCTAssertEqual(session.items, [file])
        session.endExternalDrag()
        XCTAssertEqual(session.state, .holding)
    }

    func testCancelledExternalDragReturnsToIdle() {
        var session = ShelfSession()
        session.detectDrag()
        session.endExternalDrag()
        XCTAssertEqual(session.state, .idle)
    }
}
