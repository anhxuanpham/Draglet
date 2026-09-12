// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

struct NamedShelf: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var items: [ShelfItem] = []
}

struct ShelfWorkspace: Codable, Sendable {
    var version = 1
    var shelves: [NamedShelf]
    var activeID: UUID
    static let maximumItems = 1000
    static let maximumRichBytes = 64 * 1024 * 1024
}

struct ShelfSelection {
    private(set) var ids: Set<UUID> = []
    private var anchor: UUID?

    mutating func select(_ id: UUID, ordered: [UUID], extending: Bool, toggling: Bool) {
        if extending, let anchor, let start = ordered.firstIndex(of: anchor), let end = ordered.firstIndex(of: id) {
            let range = Set(ordered[min(start, end)...max(start, end)])
            ids = toggling ? ids.union(range) : range
        } else if toggling {
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
            anchor = id
        } else {
            ids = [id]
            anchor = id
        }
    }

    mutating func selectAll(_ ordered: [UUID]) { ids = Set(ordered); anchor = ordered.first }
    mutating func retain(_ valid: Set<UUID>) { ids.formIntersection(valid); if let anchor, !valid.contains(anchor) { self.anchor = nil } }
    mutating func clear() { ids.removeAll(); anchor = nil }
}

struct RemovedShelfItem {
    let item: ShelfItem
    let index: Int
}
