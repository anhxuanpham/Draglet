// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        Task { @MainActor in
            defer { refresh(); isUpdating = false }
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try await SMAppService.mainApp.unregister() }
            } catch {
                errorMessage = "Could not change Launch at Login. Install Draglet in Applications and try again."
            }
        }
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
