// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shelf: ShelfController?
    private var menuBar: MenuBarController?
    private var dragMonitor: DragMonitor?
    private var shortcutService: GlobalShortcutService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests construct their own controllers and must not install monitors.
        guard NSClassFromString("XCTestCase") == nil else { return }
        let preferences = PreferencesService()
        let shelf = ShelfController(preferences: preferences, persistence: .application)
        self.shelf = shelf
        let shortcut = GlobalShortcutService(preferences: preferences) { [weak shelf] in shelf?.showShelf(interactive: true) }
        shortcutService = shortcut
        menuBar = MenuBarController(shelf: shelf, preferences: preferences, shortcutService: shortcut)
        let monitor = DragMonitor(preferences: preferences, shelf: shelf)
        dragMonitor = monitor
        monitor.start()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-shelf") { shelf.showShelf() }
        #endif
        AppLog.lifecycle.info("Draglet launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor?.stop()
        shortcutService?.stop()
        shelf?.stop()
        AppLog.lifecycle.info("Draglet stopped")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shelf?.showShelf(interactive: true)
        return false
    }
}
