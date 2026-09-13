// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let shelf: ShelfController
    private let preferences: PreferencesService
    private let login = LaunchAtLoginService()
    private var settingsWindow: NSWindow?
    private var sensitivityItems: [NSMenuItem] = []
    private var loginItem: NSMenuItem?
    private var subscription: AnyCancellable?
    private let shortcutService: GlobalShortcutService

    init(shelf: ShelfController, preferences: PreferencesService, shortcutService: GlobalShortcutService) {
        self.shelf = shelf
        self.preferences = preferences
        self.shortcutService = shortcutService
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        shelf.openSettings = { [weak self] in self?.showSettings() }
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Draglet")
            button.image?.isTemplate = true
            button.toolTip = "Draglet — Drop it here. Finish the drag later."
            button.setAccessibilityLabel("Draglet")
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Draglet", action: nil, keyEquivalent: ""))
        menu.addItem(item("Show Shelf", action: #selector(showShelf)))
        menu.addItem(.separator())
        let sensitivity = NSMenuItem(title: "Shake Sensitivity", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (index, preset) in ShakeSensitivity.allCases.enumerated() {
            let choice = item(preset.label, action: #selector(changeSensitivity(_:)))
            choice.tag = index
            submenu.addItem(choice)
            sensitivityItems.append(choice)
        }
        sensitivity.submenu = submenu
        menu.addItem(sensitivity)
        let loginItem = item("Launch at Login", action: #selector(toggleLogin))
        self.loginItem = loginItem
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
        menu.addItem(item("About Draglet", action: #selector(showAbout)))
        menu.addItem(item("Quit Draglet", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        updateCount()
        subscription = shelf.objectWillChange.debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.updateCount() }
    }

    private func updateCount() {
        let count = shelf.totalCount
        statusItem.button?.title = count == 0 ? "" : " \(count)"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.toolTip = count == 0 ? "Draglet — Shake a drag or choose Show Shelf" : "Draglet — \(count) items across \(shelf.shelves.count) shelves"
        statusItem.button?.setAccessibilityLabel("Draglet, \(count) items held")
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        login.refresh()
        loginItem?.state = login.isEnabled ? .on : .off
        loginItem?.isEnabled = !login.isUpdating
        for (index, item) in sensitivityItems.enumerated() {
            item.state = ShakeSensitivity.allCases[index] == preferences.sensitivity ? .on : .off
        }
    }

    @objc private func showShelf() { shelf.showShelf(interactive: true) }

    @objc private func changeSensitivity(_ sender: NSMenuItem) {
        guard ShakeSensitivity.allCases.indices.contains(sender.tag) else { return }
        preferences.sensitivity = ShakeSensitivity.allCases[sender.tag]
    }

    @objc private func toggleLogin() {
        login.setEnabled(!login.isEnabled)
        showSettings()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: Constants.settingsSize),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Draglet Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(
                preferences: preferences,
                login: login,
                shortcutService: shortcutService,
                onPracticeRecognized: { [weak self] in self?.shelf.showShelf(interactive: true) },
                onShowAbout: { [weak self] in self?.showAbout() }
            ))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Draglet",
            .credits: NSAttributedString(string: "Drop it here. Finish the drag later.\nCreated by William (@anhxuanpham).\nhttps://github.com/anhxuanpham/Draglet\nGNU GPL v3 — provided without warranty.")
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
