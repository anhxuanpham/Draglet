// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import XCTest
@testable import Draglet

final class ShelfExperienceTests: XCTestCase {
    @MainActor
    private func withController(_ body: (ShelfController, URL, UserDefaults) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "DragletExperience.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let controller = ShelfController(preferences: PreferencesService(defaults: defaults),
                                         persistence: WorkspacePersistence(url: root.appendingPathComponent("state.json")))
        defer { controller.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        try body(controller, root, defaults)
    }

    private func files(_ root: URL, count: Int) throws -> [URL] {
        try (0..<count).map { index in
            let url = root.appendingPathComponent("Document \(index).txt")
            try Data("Original content \(index)".utf8).write(to: url)
            return url
        }
    }

    @MainActor func testHidePreservesItemsAndReopenRestoresSelection() throws {
        try withController { controller, root, _ in
            let urls = try files(root, count: 3)
            controller.showShelf()
            controller.receive(urls)
            let ids = controller.session.items.map(\.id)
            controller.select(ids[1])
            controller.hideShelf()
            XCTAssertNil(controller.panel)
            XCTAssertEqual(controller.session.items.map(\.url), urls)
            XCTAssertEqual(controller.selection.ids, [ids[1]])
            controller.showShelf()
            XCTAssertEqual(controller.session.state, .holding)
            XCTAssertFalse(controller.panel!.canBecomeKey)
        }
    }

    @MainActor func testUndoDoesNotResurrectTransferredItemsAndPreservesNewDrops() throws {
        try withController { controller, root, _ in
            let urls = try files(root, count: 4)
            controller.showShelf()
            controller.receive(Array(urls.prefix(3)))
            let original = controller.session.items
            controller.remove([original[1].id])
            _ = controller.beginDrag(ids: [original[0].id])
            controller.endDrag(operation: .copy)
            controller.receive([urls[3]])
            controller.undoRemoval()
            XCTAssertEqual(Set(controller.session.items.map(\.url)), Set(urls.dropFirst()))
            XCTAssertFalse(controller.session.items.contains { $0.id == original[0].id })
            XCTAssertFalse(controller.canUndo)
            for (index, url) in urls.enumerated() { XCTAssertEqual(try String(contentsOf: url), "Original content \(index)") }
        }
    }

    @MainActor func testCommandShiftSelectionDragsOnlyChosenItemsAndCancelKeepsThem() throws {
        try withController { controller, root, _ in
            controller.showShelf()
            controller.receive(try files(root, count: 5))
            let ids = controller.session.items.map(\.id)
            controller.select(ids[1])
            controller.select(ids[3], modifiers: .shift)
            XCTAssertEqual(controller.selection.ids, Set(ids[1...3]))
            controller.select(ids[2], modifiers: .command)
            XCTAssertEqual(controller.dragIDs(for: ids[1]), [ids[1], ids[3]])
            XCTAssertEqual(Set(controller.beginDrag(ids: controller.dragIDs(for: ids[3])).map(\.id)), [ids[1], ids[3]])
            controller.hideShelf()
            controller.createShelf(named: "Cannot switch during drag")
            XCTAssertEqual(controller.shelves.count, 1)
            XCTAssertEqual(controller.session.state, .draggingOut)
            controller.endDrag(operation: [])
            XCTAssertEqual(controller.session.items.count, 5)
            _ = controller.beginDrag(ids: controller.selection.ids)
            controller.endDrag(operation: .copy)
            XCTAssertEqual(controller.session.items.map(\.id), [ids[0], ids[2], ids[4]])
        }
    }

    @MainActor func testDuplicateAndUnavailableDropCountsAreExact() throws {
        try withController { controller, root, _ in
            let urls = try files(root, count: 2)
            controller.showShelf()
            controller.receive([urls[0]])
            controller.receive([urls[0], urls[0], urls[1], root.appendingPathComponent("missing")])
            XCTAssertEqual(controller.message, "Added 1 item · 2 already held · 1 unavailable or unsupported")
            XCTAssertEqual(controller.session.items.count, 2)
        }
    }

    @MainActor func testIndependentShelvesKeepSeparateItemsAndUndo() throws {
        try withController { controller, root, _ in
            let urls = try files(root, count: 2)
            controller.showShelf()
            controller.receive([urls[0]])
            let first = controller.activeShelfID
            controller.clearShelf()
            controller.createShelf(named: "Work")
            let second = controller.activeShelfID
            XCTAssertFalse(controller.canUndo)
            controller.receive([urls[1]])
            controller.switchShelf(first)
            XCTAssertTrue(controller.session.items.isEmpty)
            controller.undoRemoval()
            XCTAssertEqual(controller.session.items.map(\.url), [urls[0]])
            controller.switchShelf(second)
            XCTAssertEqual(controller.session.items.map(\.url), [urls[1]])
            controller.renameShelf("Deliveries")
            XCTAssertEqual(controller.activeShelfName, "Deliveries")
        }
    }

    @MainActor func testPersistenceIsOptInAndRestoresMissingReferencesWithoutOverwritingSources() throws {
        try withController { controller, root, defaults in
            let urls = try files(root, count: 2)
            let persistence = WorkspacePersistence(url: root.appendingPathComponent("state.json"))
            controller.showShelf()
            controller.receive(urls)
            controller.flushPersistence()
            XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.url.path))
            controller.preferences.persistSession = true
            controller.createShelf(named: "Second")
            controller.flushPersistence()
            try FileManager.default.removeItem(at: urls[0])
            let restored = ShelfController(preferences: PreferencesService(defaults: defaults), persistence: persistence)
            defer { restored.stop() }
            XCTAssertEqual(restored.shelves.count, 2)
            XCTAssertEqual(restored.activeShelfName, "Second")
            restored.switchShelf(restored.shelves[0].id)
            XCTAssertEqual(restored.session.items.map(\.url), urls)
            XCTAssertEqual(restored.unavailableIDs.count, 1)
            XCTAssertTrue(restored.beginDrag(ids: Set(restored.session.items.map(\.id))).isEmpty)
            XCTAssertEqual(try String(contentsOf: urls[1]), "Original content 1")
            restored.preferences.persistSession = false
            restored.flushPersistence()
            XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.url.path))
            controller.preferences.persistSession = false
        }
    }

    @MainActor func testCorruptSavedSessionIsPreservedUntilExplicitReset() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "DragletCorrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let persistence = WorkspacePersistence(url: root.appendingPathComponent("state.json"))
        let bytes = Data("corrupt saved state".utf8)
        try bytes.write(to: persistence.url)
        defaults.set(true, forKey: "persistSession")
        let controller = ShelfController(preferences: PreferencesService(defaults: defaults), persistence: persistence)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        XCTAssertNotNil(controller.message)
        controller.stop()
        XCTAssertEqual(try Data(contentsOf: persistence.url), bytes)
    }

    @MainActor func testClearAllUndoRestoresOrderWithoutTouchingOriginals() throws {
        try withController { controller, root, _ in
            let urls = try files(root, count: 20)
            controller.showShelf()
            controller.receive(urls)
            let items = controller.session.items
            controller.clearShelf()
            XCTAssertTrue(controller.session.items.isEmpty)
            XCTAssertTrue(controller.canUndo)
            controller.undoRemoval()
            XCTAssertEqual(controller.session.items, items)
            XCTAssertTrue(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        }
    }

    @MainActor func testNativeKeyboardRoutingSelectsPreviewsAndHidesOnlyOnIntentionalFocus() throws {
        try withController { controller, root, _ in
            controller.showShelf()
            controller.receive(try files(root, count: 2))
            XCTAssertFalse(controller.panel!.canBecomeKey)
            controller.showShelf(interactive: true)
            let panel = controller.panel!
            XCTAssertTrue(panel.canBecomeKey)
            XCTAssertTrue(panel.firstResponder === panel)
            let commandA = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
                                           windowNumber: panel.windowNumber, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0)!
            panel.firstResponder?.keyDown(with: commandA)
            XCTAssertEqual(controller.selection.ids.count, 2)
            let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                         windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
            panel.firstResponder?.keyDown(with: escape)
            XCTAssertNil(controller.panel)
            XCTAssertEqual(controller.session.items.count, 2)
        }
    }

    @MainActor func testNativeShelfLayoutsWithOneTwentyAndOneHundredRealFilesInBothAppearances() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let urls = try files(root, count: 100)
        let suite = "DragletLayouts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let controller = ShelfController(preferences: PreferencesService(defaults: defaults))
        defer { controller.stop(); defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            for count in [1, 20, 100] {
                controller.createShelf(named: "\(count) documents")
                controller.receive(Array(urls.prefix(count)))
                let panel = try XCTUnwrap(controller.panel)
                panel.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(200))
                let view = try XCTUnwrap(panel.contentView)
                view.layoutSubtreeIfNeeded()
                XCTAssertEqual(panel.frame.width, Constants.shelfWidth)
                XCTAssertLessThanOrEqual(panel.frame.height, Constants.maximumHeight)
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = "Shelf \(count) items \(appearance.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
