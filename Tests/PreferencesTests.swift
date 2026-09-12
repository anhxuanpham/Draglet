// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import XCTest
@testable import Draglet

final class PreferencesTests: XCTestCase {
    @MainActor
    func testDefaultsPersistenceAndInvalidPresetFallback() throws {
        let suite = "DragletTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesService(defaults: defaults)
        XCTAssertEqual(preferences.sensitivity, .medium)
        XCTAssertTrue(preferences.autoDismissEmptyShelf)
        XCTAssertTrue(preferences.removeAfterSuccessfulDrag)
        preferences.sensitivity = .high
        preferences.autoDismissEmptyShelf = false
        preferences.removeAfterSuccessfulDrag = false
        let reloaded = PreferencesService(defaults: defaults)
        XCTAssertEqual(reloaded.sensitivity, .high)
        XCTAssertFalse(reloaded.autoDismissEmptyShelf)
        XCTAssertFalse(reloaded.removeAfterSuccessfulDrag)
        defaults.set("invalid", forKey: "shakeSensitivity")
        XCTAssertEqual(PreferencesService(defaults: defaults).sensitivity, .medium)
        XCTAssertEqual(Set(defaults.persistentDomain(forName: suite)?.keys.map { $0 } ?? []),
                       Set(["shakeSensitivity", "autoDismissEmptyShelf", "removeAfterSuccessfulDrag"]))
    }
}
