// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import SwiftUI

struct ShelfItemView: View {
    let item: ShelfItem
    var selected = false
    var unavailable = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: thumbnail ?? item.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(unavailable ? "Unavailable — add again from Finder" : "\(item.detail) · \(item.source)")
                    .font(.system(size: 11)).foregroundStyle(unavailable ? .red : .secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            if selected { RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3).padding(.vertical, 12) }
        }
        .contentShape(Rectangle())
        .help("\(item.name)\n\(item.source)\n\(unavailable ? "Original is unavailable" : "Drag to transfer · Double-click to preview")")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .task(id: item.id) { thumbnail = await ThumbnailService.shared.thumbnail(for: item) }
    }
}
