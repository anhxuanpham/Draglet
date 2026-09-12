// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import SwiftUI

struct ShelfView: View {
    @ObservedObject var controller: ShelfController

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ShelfMoveHandle(controller: controller).frame(width: 24, height: 28)
                Menu {
                    ForEach(controller.shelves) { shelf in
                        Button { controller.switchShelf(shelf.id) } label: {
                            Label(shelf.name, systemImage: shelf.id == controller.activeShelfID ? "checkmark" : "tray")
                        }
                    }
                    Divider()
                    Button("New Shelf…") { editName(creating: true) }.disabled(controller.shelves.count >= 20)
                    Button("Rename Shelf…") { editName(creating: false) }
                    Button("Remove Empty Shelf", action: controller.deleteEmptyShelf)
                        .disabled(!controller.session.items.isEmpty || controller.shelves.count == 1)
                } label: {
                    Text(controller.activeShelfName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Choose or manage shelves")
                Spacer(minLength: 0)
                Menu {
                    if controller.preferences.favoriteFolders.isEmpty { Text("Add favorite folders in Settings") }
                    ForEach(controller.preferences.favoriteFolders, id: \.self) { url in
                        Button("\(url.lastPathComponent) — \(url.deletingLastPathComponent().lastPathComponent)") { controller.openFavorite(url) }
                    }
                    Divider()
                    Button("Select All", action: controller.selectAll).disabled(controller.session.items.isEmpty)
                    Button("Clear All", action: controller.clearShelf).disabled(controller.session.items.isEmpty)
                    Divider()
                    Button("Settings…") { controller.openSettings?() }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 28, height: 28) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Shelf actions and favorite folders")
                Button(action: controller.hideShelf) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium)).frame(width: 28, height: 28)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Hide shelf — items stay here")
                .accessibilityLabel("Hide shelf. Keep all items.")
            }
            .disabled(controller.isDragging)
            if controller.session.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: controller.isDropHighlighted ? "tray.and.arrow.down.fill" : "square.and.arrow.down")
                        .font(.system(size: 25, weight: .light)).foregroundStyle(.tint)
                    Text(controller.isDropHighlighted ? "Release to hold here" : "Drop it here. Carry on.")
                        .font(.system(size: 13, weight: .medium))
                    Text("Files, text, links and images").font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(controller.session.items) { item in
                                HStack(spacing: 2) {
                                    FileDragSource(controller: controller, itemIDs: [item.id], label: item.name) {
                                        ShelfItemView(item: item, selected: controller.selection.ids.contains(item.id),
                                                      unavailable: controller.unavailableIDs.contains(item.id))
                                    }
                                    Button { controller.remove([item.id]) } label: {
                                        Image(systemName: "minus.circle").font(.system(size: 13))
                                            .foregroundStyle(.secondary).frame(width: 28, height: 36)
                                    }
                                    .buttonStyle(.plain).help("Remove from shelf. Original stays in place.")
                                    .accessibilityLabel("Remove \(item.name) from shelf").disabled(controller.isDragging)
                                }.frame(height: Constants.rowHeight).id(item.id)
                            }
                        }
                    }
                    .onChange(of: controller.selection.ids) { _, selected in
                        if selected.count == 1, let id = selected.first { proxy.scrollTo(id) }
                    }
                }
                FileStackView(controller: controller)
            }
            if controller.canUndo || controller.message != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(controller.message ?? "Removed from shelf").font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading).help(controller.message ?? "")
                    if controller.canUndo {
                        Button("Undo", action: controller.undoRemoval).buttonStyle(.link).font(.system(size: 11, weight: .medium))
                            .disabled(controller.isDragging)
                    }
                }
            }
        }
        .padding(Constants.padding)
        .background(controller.isDropHighlighted ? Color.accentColor.opacity(0.12) : .clear)
        .overlay {
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .strokeBorder(controller.isDropHighlighted ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.12),
                              lineWidth: controller.isDropHighlighted ? 2 : 1).allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private func editName(creating: Bool) {
        guard !controller.isDragging else { return }
        let alert = NSAlert()
        alert.messageText = creating ? "New Shelf" : "Rename Shelf"
        alert.addButton(withTitle: creating ? "Create" : "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: creating ? "Shelf \(controller.shelves.count + 1)" : controller.activeShelfName)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if creating { controller.createShelf(named: field.stringValue) }
            else { controller.renameShelf(field.stringValue) }
        }
    }
}
