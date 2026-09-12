// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit

@main
enum DragletApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
