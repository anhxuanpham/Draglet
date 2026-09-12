# Architecture and decisions

AppKit owns the OS integration. SwiftUI owns presentation. This keeps the original Finder drag intact and lets the shelf remain non-activating.

| Boundary | Owning source |
|---|---|
| App lifecycle and monitor cleanup | [AppDelegate](../Draglet/App/AppDelegate.swift) |
| Shelf state and window lifecycle | [ShelfController](../Draglet/Shelf/ShelfController.swift), [ShelfSession](../Draglet/Shelf/ShelfState.swift) |
| Named shelves, selection, undo and optional restore | [ShelfWorkspace](../Draglet/Shelf/ShelfWorkspace.swift), [WorkspacePersistence](../Draglet/Services/WorkspacePersistence.swift) |
| Rich content backing and native representations | [ContentStorage](../Draglet/Services/ContentStorage.swift), [ShelfItem](../Draglet/Shelf/ShelfItem.swift) |
| Registered hotkey and native preview | [GlobalShortcutService](../Draglet/Services/GlobalShortcutService.swift), [QuickLookController](../Draglet/Services/QuickLookController.swift) |
| Native destination/source | [ShelfDropView](../Draglet/Views/ShelfDropView.swift), [FileDragSourceView](../Draglet/Views/FileDragSourceView.swift) |
| Gesture observation and filtering | [DragMonitor](../Draglet/Drag/DragMonitor.swift), [DragSessionState](../Draglet/Drag/DragSessionState.swift), [ShakeDetector](../Draglet/Drag/ShakeDetector.swift) |
| Coordinates and Spaces configuration | [ShelfPositioner](../Draglet/Shelf/ShelfPositioner.swift), [ShelfPanel](../Draglet/Shelf/ShelfPanel.swift) |
| Preferences and system login service | [PreferencesService](../Draglet/Services/PreferencesService.swift), [LaunchAtLoginService](../Draglet/Services/LaunchAtLoginService.swift) |
| Metadata and thumbnails | [FileMetadataService](../Draglet/Services/FileMetadataService.swift), [ThumbnailService](../Draglet/Services/ThumbnailService.swift) |

File items keep original URLs because the shelf is a continuation of a drag. Rich items need Draglet-owned temporary files for file-oriented destinations and Quick Look; text and image data also remain available in native pasteboard formats. A cancelled or rejected destination must never discard references. Only a completed copy/link operation can trigger single-use removal. Self-drops and shelf switching are rejected while a shelf drag is active.

Hidden window state is separate from held content. Undo stores only manually removed entries so it cannot resurrect unrelated items already transferred. Named shelves share one panel; this keeps the working area uncluttered. Persistence is an explicit opt-in because it changes the lifetime and privacy of held content. Versioned snapshots use an ordered, debounced background writer and atomic replacement; shutdown flushes pending state. An unreadable snapshot blocks subsequent writes until an explicit reset, preserving recovery evidence.

The global monitor uses mouse events only. macOS does not expose a public global dragging-session object: a fresh supported drag pasteboard inside an observed left-button drag distinguishes a supported drag from stale data. Payloads are decoded only upon drop. Starting Draglet mid-gesture abstains until the next mouse-down. See [Apple event-monitor documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html). A registered hotkey receives only that shortcut; there is no global key monitor. The panel accepts keyboard focus only after intentional interaction, preserving source-app focus during shake activation.

All placement uses Cocoa screen points, including negative display origins. Hardware behavior still needs the [manual acceptance matrix](manual-testing.md); geometry tests cannot prove fullscreen or external-display behavior.

The distribution target is a Developer ID utility with Hardened Runtime, outside the App Store sandbox. This follows the plan's native global drag workflow; no security-scoped bookmarks or persistent access grants are stored. Swift strict concurrency and warnings-as-errors are enabled in the [project manifest](../project.yml).
