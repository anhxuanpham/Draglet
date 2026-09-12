// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import XCTest
@testable import Draglet

final class RichContentTests: XCTestCase {
    private func png() throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8,
                                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<8 { for y in 0..<8 { bitmap.setColor(.systemBlue, atX: x, y: y) } }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    func testTextLinkAndImageRoundTripThroughNativePasteboard() throws {
        let storage = ContentStorage()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { storage.cleanUp(); pasteboard.releaseGlobally() }
        let text = try storage.text("Một đoạn văn bản\nSecond line")
        let image = try storage.image(png())
        var link = ShelfItem(url: URL(string: "https://example.com/a?q=1")!, name: "Example")
        link.kind = .link
        for item in [text, image, link] {
            let writer = item.pasteboardWriter()
            switch item.kind {
            case .text: XCTAssertEqual(writer.string(forType: .string), text.text)
            case .image: XCTAssertNotNil(writer.data(forType: .png))
            case .link: XCTAssertEqual(writer.string(forType: .URL), link.url.absoluteString)
            case .file: XCTFail("Unexpected file")
            }
        }
        let incomingText = NSPasteboardItem()
        incomingText.setString(text.text!, forType: .string)
        let incomingImage = NSPasteboardItem()
        incomingImage.setData(try png(), forType: .png)
        XCTAssertTrue(pasteboard.writeObjects([incomingText, link.pasteboardWriter(), incomingImage]))
        XCTAssertTrue(DragPasteboardReader.hasSupportedContent(pasteboard))
        let result = DragPasteboardReader.read(pasteboard, storage: storage)
        XCTAssertEqual(result.items.map(\.kind), [.text, .link, .image])
        XCTAssertEqual(result.rejectedCount, 0)
        XCTAssertEqual(try String(contentsOf: result.items[0].url), text.text)
        XCTAssertEqual(result.items[2].imageData, image.imageData)
    }

    func testContentPersistenceRematerializesBackingFilesAndRejectsUnknownSchema() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let persistence = WorkspacePersistence(url: root.appendingPathComponent("state.json"))
        let storage = ContentStorage()
        let freshStorage = ContentStorage()
        defer { storage.cleanUp(); freshStorage.cleanUp(); try? FileManager.default.removeItem(at: root) }
        let text = try storage.text("Restore me")
        let image = try storage.image(png())
        let shelf = NamedShelf(name: "Mixed", items: [text, image])
        var workspace = ShelfWorkspace(shelves: [shelf], activeID: shelf.id)
        try persistence.save(workspace)
        storage.cleanUp()
        XCTAssertFalse(text.isAvailable)
        let restored = try XCTUnwrap(persistence.load(storage: freshStorage))
        XCTAssertEqual(restored.shelves[0].items.map(\.id), [text.id, image.id])
        XCTAssertTrue(restored.shelves[0].items.allSatisfy(\.isAvailable))
        XCTAssertEqual(try String(contentsOf: restored.shelves[0].items[0].url), "Restore me")
        workspace.version = 999
        try persistence.save(workspace)
        XCTAssertThrowsError(try persistence.load(storage: freshStorage))
    }

    func testMalformedImageAndOversizedTextAreRejected() throws {
        let storage = ContentStorage()
        defer { storage.cleanUp() }
        XCTAssertThrowsError(try storage.image(Data("not an image".utf8)))
        XCTAssertThrowsError(try storage.text(String(repeating: "x", count: ContentStorage.maximumPayloadBytes + 1)))
    }

    @MainActor func testShortcutPreferencesValidateAndPersistWithoutEnablingSessionSaving() throws {
        let suite = "DragletShortcut.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = PreferencesService(defaults: defaults)
        XCTAssertFalse(prefs.persistSession)
        XCTAssertTrue(prefs.shortcut!.isValid)
        XCTAssertFalse(KeyboardShortcut(keyCode: 1, modifiers: 0, key: "S").isValid)
        prefs.shortcut = nil
        XCTAssertNil(PreferencesService(defaults: defaults).shortcut)
        prefs.shortcut = .defaultShortcut
        XCTAssertEqual(PreferencesService(defaults: defaults).shortcut, .defaultShortcut)
        XCTAssertFalse(PreferencesService(defaults: defaults).persistSession)
    }
}

extension RichContentTests {
    @MainActor func testRegisteredShortcutConflictsAreVisibleAndRegistrationIsReleased() throws {
        let firstSuite = "DragletRegistrationA.\(UUID().uuidString)"
        let secondSuite = "DragletRegistrationB.\(UUID().uuidString)"
        let firstDefaults = UserDefaults(suiteName: firstSuite)!
        let secondDefaults = UserDefaults(suiteName: secondSuite)!
        defer {
            firstDefaults.removePersistentDomain(forName: firstSuite)
            secondDefaults.removePersistentDomain(forName: secondSuite)
        }
        let firstPrefs = PreferencesService(defaults: firstDefaults)
        let secondPrefs = PreferencesService(defaults: secondDefaults)
        // All four modifiers plus F19 are isolated from the app's ordinary shortcut.
        let shortcut = KeyboardShortcut(keyCode: 80, modifiers: 256 + 512 + 2048 + 4096, key: "F19")
        firstPrefs.shortcut = shortcut
        secondPrefs.shortcut = shortcut
        let first = GlobalShortcutService(preferences: firstPrefs) {}
        let second = GlobalShortcutService(preferences: secondPrefs) {}
        XCTAssertNil(first.errorMessage)
        XCTAssertNotNil(second.errorMessage)
        second.stop()
        first.stop()
        let recovered = GlobalShortcutService(preferences: secondPrefs) {}
        defer { recovered.stop() }
        XCTAssertNil(recovered.errorMessage)
    }
}
