// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Combine
import Foundation

enum ShakeSensitivity: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@MainActor
final class PreferencesService: ObservableObject {
    private let defaults: UserDefaults
    @Published var persistSession: Bool {
        didSet { defaults.set(persistSession, forKey: "persistSession") }
    }
    @Published var favoriteFolders: [URL] {
        didSet { defaults.set(favoriteFolders.map(\.absoluteString), forKey: "favoriteFolders") }
    }
    @Published var shortcut: KeyboardShortcut? {
        didSet {
            if let shortcut, let data = try? JSONEncoder().encode(shortcut) { defaults.set(data, forKey: "shelfShortcut") }
            else { defaults.set(Data(), forKey: "shelfShortcut") }
        }
    }
    @Published var sensitivity: ShakeSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: "shakeSensitivity") }
    }
    @Published var autoDismissEmptyShelf: Bool {
        didSet { defaults.set(autoDismissEmptyShelf, forKey: "autoDismissEmptyShelf") }
    }
    @Published var removeAfterSuccessfulDrag: Bool {
        didSet { defaults.set(removeAfterSuccessfulDrag, forKey: "removeAfterSuccessfulDrag") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        persistSession = defaults.bool(forKey: "persistSession")
        favoriteFolders = (defaults.stringArray(forKey: "favoriteFolders") ?? []).compactMap(URL.init(string:)).filter(FileMetadataService.isLocalFileURL)
        if let data = defaults.data(forKey: "shelfShortcut") { shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) }
        else { shortcut = .defaultShortcut }
        defaults.register(defaults: [
            "shakeSensitivity": ShakeSensitivity.medium.rawValue,
            "autoDismissEmptyShelf": true,
            "removeAfterSuccessfulDrag": true
        ])
        sensitivity = ShakeSensitivity(rawValue: defaults.string(forKey: "shakeSensitivity") ?? "") ?? .medium
        autoDismissEmptyShelf = defaults.bool(forKey: "autoDismissEmptyShelf")
        removeAfterSuccessfulDrag = defaults.bool(forKey: "removeAfterSuccessfulDrag")
    }
}
