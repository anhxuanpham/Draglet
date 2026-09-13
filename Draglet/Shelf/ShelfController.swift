// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import AppKit
import Combine
import QuartzCore

@MainActor
final class ShelfController: ObservableObject {
    @Published private(set) var session = ShelfSession()
    @Published private(set) var isDropHighlighted = false
    @Published private(set) var message: String?
    @Published private(set) var shelves: [NamedShelf]
    @Published private(set) var activeShelfID: UUID
    @Published private(set) var selection = ShelfSelection()
    @Published private(set) var unavailableIDs: Set<UUID> = []
    @Published private var undoHistory: [UUID: [[RemovedShelfItem]]] = [:]
    let preferences: PreferencesService
    var openSettings: (() -> Void)?
    let contentStorage = ContentStorage()
    private let persistence: WorkspacePersistence?
    private var persistenceBlocked = false
    private let persistenceQueue = DispatchQueue(label: "app.draglet.workspace", qos: .utility)
    private var persistenceWork: DispatchWorkItem?
    private let quickLook = QuickLookController()
    private(set) var panel: ShelfPanel?
    private var anchor = NSPoint.zero
    private var dismissWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var animationGeneration = 0
    private var subscriptions = Set<AnyCancellable>()

    init(preferences: PreferencesService, persistence: WorkspacePersistence? = nil) {
        self.preferences = preferences
        self.persistence = persistence
        let first = NamedShelf(name: "Shelf 1")
        shelves = [first]
        activeShelfID = first.id
        if preferences.persistSession, let persistence {
            do {
                if let saved = try persistence.load(storage: contentStorage) {
                    shelves = saved.shelves
                    activeShelfID = saved.activeID
                    session.replaceItems(saved.shelves.first(where: { $0.id == saved.activeID })!.items)
                    session.hide()
                }
            } catch {
                persistenceBlocked = true
                message = "Saved shelves could not be restored. The saved file has been preserved. Turn session saving off and on to start a new saved session."
            }
        }
        preferences.$persistSession.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled { self.saveWorkspace() }
                else {
                    self.persistenceWork?.cancel()
                    do { try self.persistenceQueue.sync { try self.persistence?.remove() }; self.persistenceBlocked = false }
                    catch { self.message = "Could not remove the saved session. Check access to Draglet in Application Support." }
                }
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &subscriptions)
        preferences.$autoDismissEmptyShelf.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if enabled { self?.scheduleEmptyDismiss() } else { self?.cancelEmptyDismiss() }
            }.store(in: &subscriptions)
    }

    func showShelf(at point: NSPoint? = nil, interactive: Bool = false) {
        guard session.state != .draggingOut else { return }
        cancelEmptyDismiss()
        closeWork?.cancel()
        animationGeneration += 1
        anchor = point ?? NSEvent.mouseLocation
        session.show()
        if panel == nil {
            let panel = ShelfPanel()
            panel.handleKey = { [weak self] event in self?.handleKey(event) ?? false }
            panel.contentView = ShelfDropView(controller: self)
            self.panel = panel
        }
        guard let panel else { return }
        panel.allowsKeyboard = interactive
        refreshAvailability()
        let wasVisible = panel.isVisible && (panel.contentView?.layer?.opacity ?? 0) > 0
        reposition()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        if interactive { panel.makeKey(); panel.makeFirstResponder(panel) }
        presentContent(visible: true, fromOpacity: wasVisible ? 1 : 0, fromScale: wasVisible ? 1 : 0.92, animated: true)
    }

    @discardableResult
    func receive(_ urls: [URL]) -> Bool {
        receive(FileMetadataService.read(urls))
    }

    @discardableResult
    func receive(_ pasteboard: NSPasteboard) -> Bool {
        receive(DragPasteboardReader.read(pasteboard, storage: contentStorage))
    }

    @discardableResult
    private func receive(_ result: FileMetadataService.Result) -> Bool {
        guard session.state != .draggingOut else { return false }
        guard !result.items.isEmpty else {
            message = "Nothing added. \(result.rejectedCount) item(s) unavailable, unsupported, or over the 20 MB content limit."
            reposition()
            return false
        }
        cancelEmptyDismiss()
        closeWork?.cancel()
        animationGeneration += 1
        var seen = Set(session.items.map(\.identity))
        let unique = result.items.filter { seen.insert($0.identity).inserted }
        let existing = allItems
        let richBytes = (existing + unique).reduce(0) { $0 + ($1.imageData?.count ?? 0) + ($1.text?.utf8.count ?? 0) }
        guard existing.count + unique.count <= ShelfWorkspace.maximumItems, richBytes <= ShelfWorkspace.maximumRichBytes else {
            message = "Shelf limit reached: 1,000 items or 64 MB of text/images across all shelves. Remove some items and try again."
            reposition()
            return false
        }
        let accepted = session.receive(unique)
        let duplicates = result.duplicateCount + result.items.count - accepted
        var parts = ["Added \(accepted) \(accepted == 1 ? "item" : "items")"]
        if duplicates > 0 { parts.append("\(duplicates) already held") }
        if result.rejectedCount > 0 { parts.append("\(result.rejectedCount) unavailable or unsupported") }
        message = parts.joined(separator: " · ")
        refreshAvailability()
        saveWorkspace()
        panel?.alphaValue = 1
        presentContent(visible: true, fromOpacity: 1, fromScale: 1, animated: false)
        reposition()
        AppLog.drag.info("Held \(result.items.count) file reference(s)")
        return true
    }

    func remove(_ ids: Set<UUID>) {
        guard session.state != .draggingOut, session.items.contains(where: { ids.contains($0.id) }) else { return }
        rememberUndo(ids)
        session.remove(ids)
        selection.retain(Set(session.items.map(\.id)))
        if session.items.isEmpty { ThumbnailService.shared.clear() }
        message = "Removed from shelf. Original files stay in place."
        saveWorkspace()
        reposition()
        scheduleEmptyDismiss()
    }

    func clearOrClose() {
        hideShelf()
    }

    func clearShelf() { remove(Set(session.items.map(\.id))) }

    func hideShelf() {
        guard session.state != .draggingOut else { return }
        cancelEmptyDismiss()
        closeWork?.cancel()
        animationGeneration += 1
        quickLook.close()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        session.hide()
        saveWorkspace()
    }

    func beginDrag(ids: Set<UUID>) -> [ShelfItem] {
        let selected = session.items.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return [] }
        refreshAvailability()
        guard selected.allSatisfy(\.isAvailable) else {
            message = "A file was moved or removed. Remove its reference and add it again."
            reposition()
            return []
        }
        cancelEmptyDismiss()
        message = nil
        return session.beginDrag(ids: ids)
    }

    func endDrag(operation: NSDragOperation) {
        session.endDrag(
            succeeded: DragPasteboardReader.isSuccessful(operation),
            removeAfterSuccess: preferences.removeAfterSuccessfulDrag
        )
        selection.retain(Set(session.items.map(\.id)))
        refreshAvailability()
        saveWorkspace()
        if session.items.isEmpty { ThumbnailService.shared.clear() }
        reposition()
        scheduleEmptyDismiss()
    }

    func setDropHighlight(_ highlighted: Bool) {
        guard isDropHighlighted != highlighted else { return }
        isDropHighlighted = highlighted
        if highlighted { cancelEmptyDismiss() }
    }

    func externalDragDetected() { session.detectDrag() }

    func externalDragEnded() {
        session.endExternalDrag()
        isDropHighlighted = false
        // Releasing the gesture that summoned the shelf must leave it available
        // for the next drop. Outside clicks and completed transfers own dismissal.
    }

    func scheduleEmptyDismiss() {
        cancelEmptyDismiss()
        guard preferences.autoDismissEmptyShelf, !canUndo, session.items.isEmpty, session.state == .visible else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if NSEvent.pressedMouseButtons & 1 != 0 {
                self.scheduleEmptyDismiss()
                return
            }
            self.dismissEmptyShelf()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.emptyDismissDelay, execute: work)
    }

    func cancelEmptyDismiss() {
        dismissWork?.cancel()
        dismissWork = nil
    }

    func dismissEmptyShelf() {
        guard !isDropHighlighted, let panel, session.beginDismiss() else { return }
        cancelEmptyDismiss()
        animationGeneration += 1
        let generation = animationGeneration
        presentContent(visible: false, fromOpacity: 1, fromScale: 1, animated: true)
        // WindowServer can defer animation completions when a display is asleep.
        // A one-shot deadline keeps the model and window lifecycle deterministic.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.animationGeneration == generation, self.session.state == .dismissing else { return }
            panel.orderOut(nil)
            self.session.finishDismiss()
            panel.contentView = nil
            self.panel = nil
            self.closeWork = nil
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : Constants.closeDuration), execute: work)
    }

    func stop() {
        saveWorkspace()
        flushPersistence()
        cancelEmptyDismiss()
        closeWork?.cancel()
        closeWork = nil
        animationGeneration += 1
        subscriptions.removeAll()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        ThumbnailService.shared.clear()
        quickLook.close()
        contentStorage.cleanUp()
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func reposition() {
        guard let panel, let index = ScreenGeometry.screenIndex(containing: anchor, frames: NSScreen.screens.map(\.frame)) else { return }
        let itemHeight = session.items.isEmpty ? Constants.minimumHeight : 110 + CGFloat(session.items.count) * Constants.rowHeight
        let height = min(Constants.maximumHeight, itemHeight + (message == nil ? 0 : 42))
        panel.setFrame(ShelfPositioner.frame(
            near: anchor,
            size: CGSize(width: Constants.shelfWidth, height: height),
            visibleFrame: NSScreen.screens[index].visibleFrame
        ), display: true)
    }

    var activeShelfName: String { shelves.first(where: { $0.id == activeShelfID })?.name ?? "Shelf" }
    var allItems: [ShelfItem] { shelves.flatMap { $0.id == activeShelfID ? session.items : $0.items } }
    var totalCount: Int { allItems.count }
    var canUndo: Bool { !(undoHistory[activeShelfID]?.isEmpty ?? true) }
    var isDragging: Bool { session.state == .draggingOut }

    private func rememberUndo(_ ids: Set<UUID>) {
        let removed = session.items.enumerated().compactMap { ids.contains($0.element.id) ? RemovedShelfItem(item: $0.element, index: $0.offset) : nil }
        undoHistory[activeShelfID, default: []].append(removed)
        if undoHistory[activeShelfID, default: []].count > 20 { undoHistory[activeShelfID]?.removeFirst() }
        while undoHistory.values.flatMap({ $0 }).flatMap({ $0 }).reduce(0, { $0 + ($1.item.imageData?.count ?? 0) + ($1.item.text?.utf8.count ?? 0) }) > ShelfWorkspace.maximumRichBytes {
            guard let key = undoHistory.keys.first(where: { undoHistory[$0]?.isEmpty == false }) else { break }
            undoHistory[key]?.removeFirst()
        }
    }

    func undoRemoval() {
        guard !isDragging, let removed = undoHistory[activeShelfID]?.last else { return }
        var items = session.items
        var identities = Set(items.map(\.identity))
        for entry in removed where identities.insert(entry.item.identity).inserted {
            items.insert(entry.item, at: min(entry.index, items.count))
        }
        let otherItems = shelves.filter { $0.id != activeShelfID }.flatMap(\.items)
        let richBytes = (otherItems + items).reduce(0) { $0 + ($1.imageData?.count ?? 0) + ($1.text?.utf8.count ?? 0) }
        guard totalCount - session.items.count + items.count <= ShelfWorkspace.maximumItems, richBytes <= ShelfWorkspace.maximumRichBytes else {
            message = "Free space in your shelves before restoring these items."; return
        }
        undoHistory[activeShelfID]?.removeLast()
        session.replaceItems(items)
        message = "Restored removed items."
        refreshAvailability()
        saveWorkspace()
        showShelf(at: anchor, interactive: panel?.allowsKeyboard ?? false)
    }

    func select(_ id: UUID, modifiers: NSEvent.ModifierFlags = []) {
        guard !isDragging else { return }
        panel?.allowsKeyboard = true
        panel?.makeKey()
        if let panel { panel.makeFirstResponder(panel) }
        selection.select(id, ordered: session.items.map(\.id), extending: modifiers.contains(.shift), toggling: modifiers.contains(.command))
    }

    func dragIDs(for id: UUID) -> Set<UUID> { selection.ids.contains(id) ? selection.ids : [id] }

    func selectAll() { guard !isDragging else { return }; selection.selectAll(session.items.map(\.id)) }

    func refreshAvailability() { unavailableIDs = Set(session.items.filter { !$0.isAvailable }.map(\.id)) }

    func shelfMoved(by offset: NSPoint) {
        anchor.x += offset.x
        anchor.y += offset.y
        reposition()
    }

    private func saveWorkspace() {
        if let index = shelves.firstIndex(where: { $0.id == activeShelfID }) { shelves[index].items = session.items }
        guard preferences.persistSession, !persistenceBlocked, let persistence else { return }
        persistenceWork?.cancel()
        let workspace = ShelfWorkspace(shelves: shelves, activeID: activeShelfID)
        let work = DispatchWorkItem { [weak self] in
            do { try persistence.save(workspace) }
            catch {
                Task { @MainActor [weak self] in
                    self?.message = "Session could not be saved. Keep Draglet open and check available disk space and folder access."
                }
            }
        }
        persistenceWork = work
        persistenceQueue.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func flushPersistence() {
        persistenceWork?.cancel()
        guard !persistenceBlocked else { return }
        let workspace = ShelfWorkspace(shelves: shelves, activeID: activeShelfID)
        do {
            let enabled = preferences.persistSession
            let persistence = persistence
            try persistenceQueue.sync {
                if enabled { try persistence?.save(workspace) }
                else { try persistence?.remove() }
            }
        } catch { message = "Session storage could not be updated. Check available disk space and folder access." }
    }

    func switchShelf(_ id: UUID) {
        guard !isDragging, id != activeShelfID, let next = shelves.first(where: { $0.id == id }) else { return }
        saveWorkspace()
        activeShelfID = id
        session.replaceItems(next.items)
        selection.clear()
        message = nil
        quickLook.close()
        showShelf(at: anchor, interactive: true)
        saveWorkspace()
    }

    func createShelf(named name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isDragging, shelves.count < 20, !name.isEmpty else { return }
        let shelf = NamedShelf(name: String(name.prefix(80)))
        shelves.append(shelf)
        switchShelf(shelf.id)
    }

    func renameShelf(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isDragging, !name.isEmpty, let index = shelves.firstIndex(where: { $0.id == activeShelfID }) else { return }
        shelves[index].name = String(name.prefix(80))
        saveWorkspace()
    }

    func deleteEmptyShelf() {
        guard !isDragging, session.items.isEmpty, shelves.count > 1 else { return }
        let previousID = activeShelfID
        guard let next = shelves.first(where: { $0.id != previousID }) else { return }
        switchShelf(next.id)
        shelves.removeAll { $0.id == previousID }
        undoHistory[previousID] = nil
        saveWorkspace()
    }

    func preview(_ ids: Set<UUID>) {
        guard !isDragging else { return }
        refreshAvailability()
        let items = session.items.filter { ids.contains($0.id) && $0.isAvailable }
        guard !items.isEmpty else { message = "This item is no longer available. Add it again from Finder."; return }
        quickLook.show(items, storage: contentStorage)
    }

    func reveal(_ id: UUID) {
        guard let item = session.items.first(where: { $0.id == id }), item.kind == .file, item.isAvailable else {
            refreshAvailability(); message = "The original file is no longer available at this location."; return
        }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func openFavorite(_ url: URL) {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            message = "This favorite folder is unavailable. Update it in Settings."; reposition(); return
        }
        NSWorkspace.shared.open(url)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard !isDragging else { return false }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if event.keyCode == 53 { hideShelf(); return true }
        if event.modifierFlags.contains(.command) {
            if key == "," { openSettings?(); return true }
            if key == "a" { selectAll(); return true }
            if key == "z" { undoRemoval(); return true }
        }
        if event.keyCode == 51 || event.keyCode == 117 { remove(selection.ids); return true }
        if event.keyCode == 49 { preview(selection.ids); return true }
        if event.keyCode == 125 || event.keyCode == 126 {
            let ids = session.items.map(\.id)
            guard !ids.isEmpty else { return true }
            let current = ids.firstIndex(where: { selection.ids.contains($0) }) ?? (event.keyCode == 125 ? -1 : ids.count)
            let next = min(ids.count - 1, max(0, current + (event.keyCode == 125 ? 1 : -1)))
            select(ids[next], modifiers: event.modifierFlags)
            return true
        }
        return false
    }

    private func presentContent(visible: Bool, fromOpacity: Float, fromScale: CGFloat, animated: Bool) {
        guard let layer = panel?.contentView?.layer else { return }
        // Explicit layer animations cannot apply a stale NSWindow alpha mutation
        // after a close/reopen. The model always reflects the latest request.
        layer.removeAnimation(forKey: "shelfOpacity")
        layer.removeAnimation(forKey: "shelfScale")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = visible ? 1 : 0
        CATransaction.commit()
        guard animated, !reduceMotion else { return }
        let duration = visible ? Constants.openDuration : Constants.closeDuration
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = fromOpacity
        opacity.toValue = visible ? 1 : 0
        opacity.duration = duration
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = fromScale
        scale.toValue = visible ? 1 : 0.96
        scale.duration = duration
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(opacity, forKey: "shelfOpacity")
        layer.add(scale, forKey: "shelfScale")
    }
}
