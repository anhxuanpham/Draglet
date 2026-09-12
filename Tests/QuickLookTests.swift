// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import Quartz
import XCTest
@testable import Draglet

final class QuickLookTests: XCTestCase {
    @MainActor func testNativePreviewUsesRealLocalFilesAndClosesCleanly() async throws {
        let storage = ContentStorage()
        let preview = QuickLookController()
        defer { preview.close(); storage.cleanUp() }
        let item = try storage.text("Native Quick Look verification")
        preview.show([item], storage: storage)
        let panel = try XCTUnwrap(QLPreviewPanel.shared())
        XCTAssertEqual(panel.dataSource?.numberOfPreviewItems(in: panel), 1)
        XCTAssertEqual((preview.previewPanel(panel, previewItemAt: 0) as? NSURL)?.absoluteString, item.url.absoluteString)
        XCTAssertTrue(panel.isVisible)
        preview.close()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(panel.dataSource)
    }
}
