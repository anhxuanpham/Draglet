// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

enum ShelfState: Equatable {
    case idle, dragDetected, visible, holding, draggingOut, dismissing
}

struct ShelfSession {
    private(set) var state: ShelfState = .idle
    private(set) var items: [ShelfItem] = []
    private(set) var outgoingIDs: Set<UUID> = []

    mutating func detectDrag() {
        if state == .idle { state = .dragDetected }
    }

    mutating func endExternalDrag() {
        if state == .dragDetected { state = .idle }
    }

    mutating func show() {
        guard state != .draggingOut else { return }
        state = items.isEmpty ? .visible : .holding
    }

    @discardableResult
    mutating func receive(_ incoming: [ShelfItem]) -> Int {
        guard state != .draggingOut else { return 0 }
        var identities = Set(items.map(\.identity))
        let accepted = incoming.filter { identities.insert($0.identity).inserted }
        items.append(contentsOf: accepted)
        state = items.isEmpty ? .visible : .holding
        return accepted.count
    }

    mutating func replaceItems(_ replacement: [ShelfItem]) {
        guard state != .draggingOut else { return }
        items = replacement
        state = items.isEmpty ? .visible : .holding
    }

    mutating func hide() {
        guard state != .draggingOut else { return }
        state = .idle
    }

    mutating func remove(_ ids: Set<UUID>) {
        guard state != .draggingOut else { return }
        items.removeAll { ids.contains($0.id) }
        state = items.isEmpty ? .visible : .holding
    }

    mutating func beginDrag(ids: Set<UUID>) -> [ShelfItem] {
        guard state == .holding else { return [] }
        let selected = items.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return [] }
        outgoingIDs = Set(selected.map(\.id))
        state = .draggingOut
        return selected
    }

    mutating func endDrag(succeeded: Bool, removeAfterSuccess: Bool) {
        guard state == .draggingOut else { return }
        if succeeded && removeAfterSuccess { items.removeAll { outgoingIDs.contains($0.id) } }
        outgoingIDs.removeAll()
        state = items.isEmpty ? .visible : .holding
    }

    @discardableResult
    mutating func beginDismiss() -> Bool {
        guard items.isEmpty, state == .visible else { return false }
        state = .dismissing
        return true
    }

    mutating func finishDismiss() {
        guard state == .dismissing, items.isEmpty else { return }
        state = .idle
    }
}
