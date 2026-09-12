// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import OSLog

enum AppLog {
    static let lifecycle = Logger(subsystem: "app.draglet.Draglet", category: "lifecycle")
    static let drag = Logger(subsystem: "app.draglet.Draglet", category: "drag")
}
