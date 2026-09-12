// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import CryptoKit

struct ShelfItem: Identifiable, Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable { case file, text, link, image }
    let id: UUID
    var url: URL
    let name: String
    let fileSize: Int64?
    let isDirectory: Bool
    let addedAt: Date
    var kind: Kind = .file
    var text: String?
    var imageData: Data?

    var identity: String {
        switch kind {
        case .file, .link: return "\(kind.rawValue):\(url.absoluteString)"
        case .text: return "text:\(text ?? "")"
        case .image: return "image:\(SHA256.hash(data: imageData ?? Data()).map { String(format: "%02x", $0) }.joined())"
        }
    }

    var isAvailable: Bool { kind == .link || FileManager.default.fileExists(atPath: url.path) }
    var source: String {
        switch kind {
        case .file: return url.deletingLastPathComponent().abbreviatingWithTildeInPath
        case .text: return "Text snippet"
        case .link: return url.host ?? "Web link"
        case .image: return "Dropped image"
        }
    }
    var icon: NSImage {
        if kind == .link { return NSImage(systemSymbolName: "link", accessibilityDescription: nil)! }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func pasteboardWriter() -> NSPasteboardItem {
        let writer = NSPasteboardItem()
        if kind == .link {
            writer.setString(url.absoluteString, forType: .URL)
            writer.setString(url.absoluteString, forType: .string)
        } else {
            writer.setString(url.absoluteString, forType: .fileURL)
            if let text { writer.setString(text, forType: .string) }
            if let imageData { writer.setData(imageData, forType: .png) }
        }
        return writer
    }

    init(url: URL, name: String? = nil, fileSize: Int64? = nil, isDirectory: Bool = false) {
        id = UUID()
        self.url = url.standardizedFileURL
        self.name = name ?? url.lastPathComponent
        self.fileSize = fileSize
        self.isDirectory = isDirectory
        addedAt = Date()
    }

    var detail: String {
        if isDirectory { return "Folder" }
        guard let fileSize else { return "File" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

private extension URL {
    var abbreviatingWithTildeInPath: String { (path as NSString).abbreviatingWithTildeInPath }
}
