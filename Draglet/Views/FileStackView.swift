// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import SwiftUI

struct FileStackView: View {
    @ObservedObject var controller: ShelfController
    var body: some View {
        let count = controller.selection.ids.count
        let ids = count > 0 ? controller.selection.ids : Set(controller.session.items.map(\.id))
        HStack(spacing: 10) {
            Text(count > 0 ? "\(count) selected" : "\(controller.session.items.count) held")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            FileDragSource(controller: controller, itemIDs: ids, label: "Drag \(ids.count) items") {
                Label(count > 0 ? "Drag selected (\(count))" : "Drag all (\(ids.count))", systemImage: "square.stack.3d.up")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }.frame(width: 172, height: 34)
        }.frame(height: 34)
    }
}
