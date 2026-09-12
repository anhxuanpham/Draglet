// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import XCTest
@testable import Draglet

final class FileReferenceTests: XCTestCase {
    func testRealFilesFoldersAndMissingFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("a file #1.txt")
        let data = Data("Draglet reference test".utf8)
        try data.write(to: file)
        let result = FileMetadataService.read([file, file, folder, folder.appendingPathComponent("missing"), URL(string: "https://example.com/test")!])
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.rejectedCount, 2)
        XCTAssertEqual(result.items[0].name, "a file #1.txt")
        XCTAssertEqual(result.items[0].fileSize, Int64(data.count))
        XCTAssertTrue(result.items[1].isDirectory)
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testPasteboardReadsMultipleFileURLsOnly() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = [folder.appendingPathComponent("hello world.txt"), folder.appendingPathComponent("Việt #1.txt")]
        for url in urls { try Data("file URL representation".utf8).write(to: url) }
        XCTAssertTrue(pasteboard.writeObjects(urls as [NSURL]))
        XCTAssertEqual(DragPasteboardReader.urls(from: pasteboard), urls)
        pasteboard.clearContents()
        pasteboard.setString("https://example.com/file.pdf", forType: .string)
        XCTAssertTrue(DragPasteboardReader.urls(from: pasteboard).isEmpty)
    }

    func testDragPresenceRetriesAfterAnEmptyFirstSampleAndSeesFilenames() throws {
        var cache = DragPresenceCache()
        var samples = [false, false, true]
        XCTAssertFalse(cache.update(changeCount: 4) { samples.removeFirst() })
        XCTAssertFalse(cache.update(changeCount: 4) { samples.removeFirst() })
        XCTAssertTrue(cache.update(changeCount: 4) { samples.removeFirst() })
        XCTAssertTrue(cache.update(changeCount: 4) { XCTFail("Positive presence must be cached"); return false })
        XCTAssertFalse(cache.update(changeCount: 5) { false })
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("public.png", forType: .init("com.apple.pasteboard.promised-file-url"))
        XCTAssertTrue(DragPasteboardReader.hasDragPresence(pasteboard))
        XCTAssertFalse(DragPasteboardReader.hasSupportedContent(pasteboard))
        pasteboard.clearContents()
        pasteboard.setPropertyList(["NSFilenamesPboardType"], forType: .init("NSFilesPromisePboardType"))
        XCTAssertTrue(DragPasteboardReader.hasDragPresence(pasteboard))
    }

    func testOnlySafeOperationsCanAcceptOrRemoveReferences() {
        XCTAssertEqual(DragPasteboardReader.safeOperation(from: [.copy, .move]), .copy)
        XCTAssertEqual(DragPasteboardReader.safeOperation(from: [.link]), .link)
        XCTAssertEqual(DragPasteboardReader.safeOperation(from: [.move, .delete]), [])
        XCTAssertTrue(DragPasteboardReader.isSuccessful(.copy))
        XCTAssertTrue(DragPasteboardReader.isSuccessful(.link))
        for operation: NSDragOperation in [[], .move, .delete, .generic, [.copy, .delete]] {
            XCTAssertFalse(DragPasteboardReader.isSuccessful(operation))
        }
    }

    func testRemoteFileAuthorityIsRejected() {
        XCTAssertFalse(FileMetadataService.isLocalFileURL(URL(string: "file://remote.example/share/test")!))
        XCTAssertTrue(FileMetadataService.isLocalFileURL(URL(fileURLWithPath: "/Volumes/External/test")))
    }
}
