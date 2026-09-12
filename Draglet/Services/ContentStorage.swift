// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import CryptoKit
import ImageIO

/// Owns only Draglet-generated backing files; original dropped files are never written.
final class ContentStorage {
    static let maximumPayloadBytes = 20 * 1024 * 1024
    private let directory: URL
    private var writtenBytes = 0

    init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Draglet-\(UUID().uuidString)", isDirectory: true)) {
        self.directory = directory
    }

    func text(_ value: String) throws -> ShelfItem {
        let bytes = Data(value.utf8)
        let url = try materialize(bytes, extension: "txt")
        var item = ShelfItem(url: url, name: String(value.split(whereSeparator: \.isNewline).first ?? "Text").prefix(100).description,
                             fileSize: Int64(bytes.count))
        item.kind = .text
        item.text = value
        return item
    }

    func image(_ data: Data) throws -> ShelfItem {
        guard data.count <= Self.maximumPayloadBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16384, height <= 16384, width * height <= 16_000_000,
              let bitmap = NSBitmapImageRep(data: data),
              let png = bitmap.representation(using: .png, properties: [:]) else { throw ContentError.unsupported }
        let url = try materialize(png, extension: "png")
        var item = ShelfItem(url: url, name: "Image · \(bitmap.pixelsWide) × \(bitmap.pixelsHigh)", fileSize: Int64(png.count))
        item.kind = .image
        item.imageData = png
        return item
    }

    func restore(_ item: ShelfItem) throws -> ShelfItem {
        var restored = item
        switch item.kind {
        case .file:
            guard FileMetadataService.isLocalFileURL(item.url) else { throw ContentError.unsupported }
        case .link:
            guard ["http", "https"].contains(item.url.scheme?.lowercased() ?? ""), item.url.host != nil else { throw ContentError.unsupported }
        case .text:
            guard let value = item.text else { throw ContentError.unsupported }
            restored.url = try materialize(Data(value.utf8), extension: "txt")
        case .image:
            guard let bytes = item.imageData else { throw ContentError.unsupported }
            restored.url = try image(bytes).url
        }
        return restored
    }

    private func materialize(_ data: Data, extension suffix: String) throws -> URL {
        guard data.count <= Self.maximumPayloadBytes else { throw ContentError.tooLarge }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = directory.appendingPathComponent(hash).appendingPathExtension(suffix)
        if !FileManager.default.fileExists(atPath: url.path) {
            guard writtenBytes + data.count <= 256 * 1024 * 1024 else { throw ContentError.tooLarge }
            try data.write(to: url, options: .atomic)
            writtenBytes += data.count
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        return url
    }

    func cleanUp() { try? FileManager.default.removeItem(at: directory) }
    enum ContentError: Error { case tooLarge, unsupported }
}
