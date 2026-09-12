// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import Quartz

@MainActor
final class QuickLookController: NSObject, @MainActor QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var urls: [URL] = []
    private weak var panel: QLPreviewPanel?

    func show(_ items: [ShelfItem], storage: ContentStorage) {
        urls = items.compactMap { item in
            if item.kind == .link { return try? storage.text(item.url.absoluteString).url }
            return item.url
        }
        guard !urls.isEmpty, let preview = QLPreviewPanel.shared() else { return }
        panel = preview
        preview.dataSource = self
        preview.delegate = self
        preview.reloadData()
        preview.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel?.dataSource = nil
        panel?.delegate = nil
        panel = nil
        urls.removeAll()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard urls.indices.contains(index) else { return nil }
        return urls[index] as NSURL
    }
}
