// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()
    private let cache = NSCache<NSUUID, NSImage>()
    private var requests: [UUID: QLThumbnailGenerator.Request] = [:]
    private var cacheGeneration = 0

    private init() {
        cache.countLimit = 64
        cache.totalCostLimit = 4 * 1024 * 1024
    }

    func thumbnail(for item: ShelfItem) async -> NSImage? {
        if let image = cache.object(forKey: item.id as NSUUID) { return image }
        guard !item.isDirectory, item.kind != .link, item.isAvailable, !Task.isCancelled else { return nil }
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 40, height: 40), scale: 2, representationTypes: .thumbnail)
        let requestID = UUID()
        let generation = cacheGeneration
        requests[requestID] = request
        defer { requests[requestID] = nil }
        let representation = try? await withTaskCancellationHandler {
            try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(requestID) }
        }
        guard !Task.isCancelled, cacheGeneration == generation, let image = representation?.nsImage else { return nil }
        cache.setObject(image, forKey: item.id as NSUUID, cost: 80 * 80 * 4)
        return image
    }

    func clear() {
        cacheGeneration += 1
        cache.removeAllObjects()
        for request in requests.values { QLThumbnailGenerator.shared.cancel(request) }
    }

    private func cancel(_ id: UUID) {
        if let request = requests[id] { QLThumbnailGenerator.shared.cancel(request) }
    }
}
