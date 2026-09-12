// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit

enum DragPasteboardReader {
    static let supportedTypes: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .png, .tiff, .string]
    static let dragPresenceTypes: [NSPasteboard.PasteboardType] = supportedTypes + [
        .init("NSFilenamesPboardType"),
        .init("NSFilesPromisePboardType"),
        .init("com.apple.pasteboard.promised-file-url"),
        .init("com.apple.pasteboard.promised-file-content-type"),
        .init("public.file-promise"),
    ]

    static func hasSupportedContent(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: supportedTypes) != nil
    }

    /// Finder can advertise a drag before file URLs are readable. Presence types
    /// are enough to treat the gesture as a live drag; drop still uses `read`.
    static func hasDragPresence(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: dragPresenceTypes) != nil
    }

    static func read(_ pasteboard: NSPasteboard, storage: ContentStorage) -> FileMetadataService.Result {
        var result = FileMetadataService.Result()
        for object in pasteboard.pasteboardItems ?? [] {
            do {
                if let string = object.string(forType: .fileURL), let url = URL(string: string) {
                    let files = FileMetadataService.read([url])
                    result.items.append(contentsOf: files.items)
                    result.rejectedCount += files.rejectedCount
                } else if let string = object.string(forType: .URL), let url = URL(string: string),
                          ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                    var item = ShelfItem(url: url, name: string)
                    item.kind = .link
                    result.items.append(item)
                } else if let data = object.data(forType: .png) ?? object.data(forType: .tiff) {
                    result.items.append(try storage.image(data))
                } else if let value = object.string(forType: .string), !value.isEmpty {
                    result.items.append(try storage.text(value))
                } else { result.rejectedCount += 1 }
            } catch { result.rejectedCount += 1 }
        }
        return result
    }

    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return [] }
        return objects.filter(FileMetadataService.isLocalFileURL)
    }

    static func safeOperation(from mask: NSDragOperation) -> NSDragOperation {
        if mask.contains(.copy) { return .copy }
        if mask.contains(.link) { return .link }
        return []
    }

    static func isSuccessful(_ operation: NSDragOperation) -> Bool {
        !operation.isEmpty && operation.subtracting([.copy, .link]).isEmpty
    }
}

/// Finder populates the drag pasteboard asynchronously. A one-shot miss must not
/// latch "no content" for the rest of the mouse gesture.
struct DragPresenceCache {
    private var changeCount: Int?
    private var hasContent = false

    mutating func update(changeCount: Int, detect: () -> Bool) -> Bool {
        if self.changeCount != changeCount {
            self.changeCount = changeCount
            hasContent = false
        }
        if !hasContent { hasContent = detect() }
        return hasContent
    }
}
