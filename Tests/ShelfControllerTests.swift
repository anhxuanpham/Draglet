// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI
import XCTest
@testable import Draglet

final class ShelfControllerTests: XCTestCase {
    @MainActor
    private func makeController() -> (ShelfController, String) {
        let suite = "DragletControllerTests.\(UUID().uuidString)"
        let preferences = PreferencesService(defaults: UserDefaults(suiteName: suite)!)
        return (ShelfController(preferences: preferences), suite)
    }

    @MainActor
    func testNativePanelDoesNotBecomeKeyOrChangeActiveApplication() async throws {
        let (controller, suite) = makeController()
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite) }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        controller.showShelf(at: CGPoint(x: 500, y: 500))
        try await Task.sleep(for: .milliseconds(200))
        let panel = try XCTUnwrap(controller.panel)
        XCTAssertTrue(panel.isVisible)
        XCTAssertFalse(panel.isKeyWindow)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.collectionBehavior.contains([.canJoinAllSpaces, .fullScreenAuxiliary]))
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, frontmost)
    }

    @MainActor
    func testReopenDuringDismissStaysVisible() async throws {
        let (controller, suite) = makeController()
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite) }
        controller.showShelf(at: CGPoint(x: 500, y: 500))
        controller.dismissEmptyShelf()
        controller.showShelf(at: CGPoint(x: 600, y: 400))
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(controller.session.state, .visible)
        XCTAssertTrue(controller.panel?.isVisible == true)
        XCTAssertEqual(controller.panel?.alphaValue, 1)
        XCTAssertEqual(controller.panel?.contentView?.layer?.opacity, 1)
    }

    @MainActor
    func testRealReferencesSurviveCancelledOutgoingDragAndRender() async throws {
        let (controller, suite) = makeController()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            controller.stop()
            UserDefaults().removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let file = folder.appendingPathComponent("Draglet verification.txt")
        let original = Data("Real file used by native panel integration tests.".utf8)
        try original.write(to: file)
        controller.showShelf(at: CGPoint(x: 500, y: 500))
        XCTAssertTrue(controller.receive([file, folder]))
        let ids = Set(controller.session.items.map(\.id))
        XCTAssertEqual(controller.beginDrag(ids: ids).count, 2)
        controller.endDrag(operation: [])
        XCTAssertEqual(controller.session.items.count, 2)
        try await Task.sleep(for: .milliseconds(300))
        let view = try XCTUnwrap(controller.panel?.contentView)
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "Native shelf with real file references"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(try Data(contentsOf: file), original)
        _ = controller.beginDrag(ids: ids)
        controller.endDrag(operation: .copy)
        try await Task.sleep(for: .milliseconds(850))
        XCTAssertTrue(controller.session.items.isEmpty)
        XCTAssertEqual(controller.session.state, .idle)
        XCTAssertFalse(controller.panel?.isVisible == true)
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertNil(controller.panel, "An empty dismissed shelf releases its SwiftUI hierarchy")
    }

    @MainActor
    func testMissingFileCannotBeginDragAndReferenceIsRetained() throws {
        let (controller, suite) = makeController()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: file) }
        try Data("test".utf8).write(to: file)
        controller.showShelf()
        XCTAssertTrue(controller.receive([file]))
        let id = try XCTUnwrap(controller.session.items.first?.id)
        try FileManager.default.removeItem(at: file)
        XCTAssertTrue(controller.beginDrag(ids: [id]).isEmpty)
        XCTAssertEqual(controller.session.items.count, 1)
        XCTAssertNotNil(controller.message)
        XCTAssertEqual(controller.session.state, .holding)
    }

    @MainActor
    func testShakeOpenedShelfStaysAvailableAfterMouseRelease() async throws {
        let (controller, suite) = makeController()
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite) }
        controller.showShelf()
        controller.externalDragEnded()
        try await Task.sleep(for: .milliseconds(3200))
        XCTAssertEqual(controller.session.state, .visible)
        XCTAssertTrue(controller.panel?.isVisible == true)
        XCTAssertFalse(controller.panel?.canBecomeKey == true)

        controller.scheduleEmptyDismiss()
        try await Task.sleep(for: .milliseconds(850))
        XCTAssertEqual(controller.session.state, .idle)
        XCTAssertNil(controller.panel)
    }

    @MainActor
    func testInteractiveEmptyShelfSurvivesEndedDragUntilOutsideClick() async throws {
        let (controller, suite) = makeController()
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite) }
        controller.showShelf(interactive: true)
        controller.externalDragEnded()
        try await Task.sleep(for: .milliseconds(750))
        XCTAssertTrue(controller.panel?.isVisible == true)
        XCTAssertEqual(controller.session.state, .visible)
        controller.scheduleEmptyDismiss()
        try await Task.sleep(for: .milliseconds(850))
        XCTAssertFalse(controller.panel?.isVisible == true)
        XCTAssertEqual(controller.session.state, .idle)
    }

    @MainActor
    func testDisabledAutoDismissKeepsEmptyShelfUntilClosed() async throws {
        let (controller, suite) = makeController()
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite) }
        controller.preferences.autoDismissEmptyShelf = false
        controller.showShelf()
        controller.externalDragEnded()
        try await Task.sleep(for: .milliseconds(750))
        XCTAssertTrue(controller.panel?.isVisible == true)
        controller.clearOrClose()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(controller.panel?.isVisible == true)
    }

    @MainActor
    func testEnablingAutoDismissOnEmptyVisibleShelfTakesEffect() async throws {
        let (controller, suite) = makeController()
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite) }
        controller.preferences.autoDismissEmptyShelf = false
        controller.showShelf()
        controller.preferences.autoDismissEmptyShelf = true
        try await Task.sleep(for: .milliseconds(850))
        XCTAssertFalse(controller.panel?.isVisible == true)
        XCTAssertEqual(controller.session.state, .idle)
    }

    @MainActor
    func testNewDropDuringFadeOutRemainsVisible() async throws {
        let (controller, suite) = makeController()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { controller.stop(); UserDefaults().removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: file) }
        try Data("test".utf8).write(to: file)
        controller.showShelf()
        try await Task.sleep(for: .milliseconds(180))
        controller.dismissEmptyShelf()
        XCTAssertTrue(controller.receive([file]))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(controller.session.state, .holding)
        XCTAssertTrue(controller.panel?.isVisible == true)
        XCTAssertEqual(controller.panel?.alphaValue, 1)
        XCTAssertEqual(controller.panel?.contentView?.layer?.opacity, 1)
    }

    @MainActor
    func testSettingsRenderWithoutChangingLoginRegistration() async throws {
        let (controller, suite) = makeController()
        let login = LaunchAtLoginService()
        let originalStatus = login.status
        let window = ShelfPanel()
        let view = NSHostingView(rootView: SettingsView(preferences: controller.preferences, login: login))
        defer {
            window.orderOut(nil)
            window.contentView = nil
            controller.stop()
            UserDefaults().removePersistentDomain(forName: suite)
        }
        window.setContentSize(Constants.settingsSize)
        window.contentView = view
        window.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(250))
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "Native settings"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(login.status, originalStatus)
        XCTAssertFalse(login.isUpdating)
    }
}
