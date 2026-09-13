// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesService
    @ObservedObject var login: LaunchAtLoginService
    var shortcutService: GlobalShortcutService? = nil
    var onPracticeRecognized: (() -> Void)? = nil
    var onShowAbout: (() -> Void)? = nil
    @State private var recording = false
    @State private var practiceCount = 0

    var body: some View {
        TabView {
            Form {
                Section("Open the shelf") {
                    HStack {
                        Text("Keyboard shortcut")
                        Spacer()
                        Button(recording ? "Press shortcut…" : (preferences.shortcut?.label ?? "Set Shortcut")) { recording = true }
                        if preferences.shortcut != nil {
                            Button("Clear") { preferences.shortcut = nil; recording = false }.buttonStyle(.link)
                        }
                    }
                    if recording {
                        Text("Use Command, Control or Option with a key. Escape cancels.").font(.caption).foregroundStyle(.secondary)
                        ShortcutRecorder { shortcut in
                            if let shortcut { preferences.shortcut = shortcut }
                            recording = false
                        }.frame(height: 1)
                    }
                    if let shortcutService { ShortcutStatus(service: shortcutService) }
                    Text("The shortcut opens the shelf for keyboard use. Shaking a drag keeps focus in the source app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Shelf behavior") {
                    Toggle("Auto-dismiss empty shelf", isOn: $preferences.autoDismissEmptyShelf)
                    Toggle("Remove items after successful drag", isOn: $preferences.removeAfterSuccessfulDrag)
                    Text("× hides the shelf and keeps its items. Clear All removes references; Undo restores them.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Restore shelves after quitting", isOn: $preferences.persistSession)
                    Text(preferences.persistSession
                         ? "Names, file paths, text, links and images are saved on this Mac. Turning this off deletes the saved session; current shelves stay open."
                         : "Shelves last for this app session. Original files are never copied into saved sessions.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("General") {
                    Toggle("Launch at Login", isOn: Binding(get: { login.isEnabled }, set: { login.setEnabled($0) }))
                        .disabled(login.isUpdating)
                    if login.needsApproval { Button("Allow Draglet in Login Items…", action: login.openSystemSettings) }
                    if let error = login.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                }
                Section("About Draglet") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created by William").fontWeight(.medium)
                            Link("@anhxuanpham", destination: URL(string: "https://github.com/anhxuanpham/Draglet")!)
                            Text("GNU GPL v3 · No account, uploads or clipboard monitoring.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let onShowAbout { Button("About Draglet", action: onShowAbout) }
                    }
                }
            }.formStyle(.grouped).tabItem { Label("General", systemImage: "gearshape") }
            Form {
                Section("Shake gesture") {
                    Picker("Shake effort", selection: $preferences.sensitivity) {
                        ForEach(ShakeSensitivity.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    Text("Low needs a gentler shake. High requires a stronger, more deliberate gesture.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Try it here") {
                    Text("Click and hold in the pad, then shake sideways. In Finder, click a file, keep the mouse button down, and shake the same way — the shelf appears next to the cursor.")
                        .font(.callout)
                    ShakePracticeView(sensitivity: preferences.sensitivity) {
                        practiceCount += 1
                        onPracticeRecognized?()
                    }
                        .frame(height: 160)
                        .overlay { Text("←  Hold and shake  →").foregroundStyle(.secondary).allowsHitTesting(false) }
                    Label(
                        practiceCount == 0
                            ? "Waiting for a shake"
                            : "Shake recognized · \(practiceCount). In Finder: hold a file and shake the same way.",
                        systemImage: practiceCount == 0 ? "hand.draw" : "checkmark.circle.fill"
                    )
                        .foregroundStyle(practiceCount == 0 ? Color.secondary : Color.accentColor)
                        .lineLimit(3)
                }
                Section("Keyboard tips") {
                    Text("Click an item to select it. Cmd-click adds individual items; Shift-click selects a range. Space previews, Delete removes from the shelf, Cmd-Z restores, and Escape hides.")
                        .font(.callout)
                }
            }.formStyle(.grouped).tabItem { Label("Shake", systemImage: "hand.draw") }
            Form {
                Section("Favorite destination folders") {
                    Text("Open a destination from the shelf’s ••• menu, then drag your items into Finder.")
                        .font(.callout).foregroundStyle(.secondary)
                    ForEach(preferences.favoriteFolders, id: \.self) { url in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent).fontWeight(.medium)
                                Text((url.path as NSString).abbreviatingWithTildeInPath).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") { preferences.favoriteFolders.removeAll { $0 == url } }.buttonStyle(.link)
                        }
                    }
                    Button("Add Folder…", action: addFavorite)
                }
            }.formStyle(.grouped).tabItem { Label("Folders", systemImage: "folder.badge.plus") }
        }
        .padding(12)
        .frame(width: Constants.settingsSize.width, height: Constants.settingsSize.height)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }

    private func addFavorite() {
        let chooser = NSOpenPanel()
        chooser.title = "Choose Favorite Folders"
        chooser.canChooseDirectories = true
        chooser.canChooseFiles = false
        chooser.allowsMultipleSelection = true
        if chooser.runModal() == .OK {
            for url in chooser.urls where !preferences.favoriteFolders.contains(url.standardizedFileURL) {
                preferences.favoriteFolders.append(url.standardizedFileURL)
            }
        }
    }
}

private struct ShortcutStatus: View {
    @ObservedObject var service: GlobalShortcutService
    var body: some View {
        if let error = service.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
    }
}
