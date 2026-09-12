// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

struct WorkspacePersistence: Sendable {
    let url: URL
    static var application: WorkspacePersistence {
        WorkspacePersistence(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Draglet", isDirectory: true).appendingPathComponent("workspace.json"))
    }

    func load(storage: ContentStorage) throws -> ShelfWorkspace? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size < 100 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
        var workspace = try JSONDecoder().decode(ShelfWorkspace.self, from: Data(contentsOf: url))
        guard workspace.version == 1, !workspace.shelves.isEmpty, workspace.shelves.count <= 20,
              Set(workspace.shelves.map(\.id)).count == workspace.shelves.count,
              workspace.shelves.contains(where: { $0.id == workspace.activeID }),
              workspace.shelves.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 80 }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let items = workspace.shelves.flatMap(\.items)
        guard items.count <= ShelfWorkspace.maximumItems, Set(items.map(\.id)).count == items.count,
              items.reduce(0, { $0 + ($1.imageData?.count ?? 0) + ($1.text?.utf8.count ?? 0) }) <= ShelfWorkspace.maximumRichBytes else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for index in workspace.shelves.indices {
            workspace.shelves[index].items = try workspace.shelves[index].items.map { try storage.restore($0) }
        }
        return workspace
    }

    func save(_ workspace: ShelfWorkspace) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(workspace).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func remove() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
