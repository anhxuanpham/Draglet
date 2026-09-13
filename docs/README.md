# Draglet

**Drop it here. Finish the drag later.**

A native macOS menu bar shelf for holding files, text, links and images while you switch Finder windows, apps, or Spaces. Requires macOS 14 or later. Created by [William](https://github.com/anhxuanpham), licensed under [GPL-3.0-only](../LICENSE). See the [project overview](../README.md).

## Use

1. Launch Draglet; its tray icon appears in the menu bar.
2. Drag a file or folder from Finder, keep the mouse button down, and shake horizontally. The shelf appears next to the cursor. Or choose **Show Shelf** from the tray menu. The default keyboard shortcut is **Control–Option–Space**; change it in Settings.
3. Drop into the shelf and release the mouse.
4. Switch to your destination. Drag a row or **Drag all** out of the shelf. Cmd-click selects individual items; Shift-click selects a range; the bottom handle then drags that selection.

A successful destination copy/link removes the corresponding references by default. Cancelled drags keep them. **×** and **Escape** hide the shelf without clearing it; **Clear All** lives in the **•••** menu. **Undo** or **Cmd-Z** restores manually removed references, not operations performed by destination apps. A moved/deleted source must be added again.

Double-click an item, or select it and press **Space**, for Quick Look. Right-click a file to reveal its original in Finder. Drag the tray icon in the shelf header to move the shelf out of the way. The shelf-name menu creates, renames and switches independent shelves; a shelf must be empty before removing it.

Author and license information is visible in **Settings → General → About Draglet**. The **About Draglet** button opens the app's version and full credits; it is also available in the menu bar menu.

Settings includes a local shake practice pad that previews the shelf; holding files still requires shaking while a Finder drag is in progress. Favorite folders open a destination in Finder; drag items there using the normal workflow. The **Restore shelves after quitting** option is off by default. Enabling it stores names, file paths and rich content on this Mac; disabling it deletes the saved snapshot while keeping the open session. See [privacy](privacy.md).

Text is exported as native text with a text-file representation; images offer PNG plus a file representation; links offer URL and text. Destination apps choose the format they accept. Remote image links are held as links, without downloading their contents. Content limits are owned by [ContentStorage](../Draglet/Services/ContentStorage.swift) and [ShelfWorkspace](../Draglet/Shelf/ShelfWorkspace.swift).

**Low** needs less shake effort; **High** needs more. Launch at Login is opt-in and may need approval in macOS Login Items. Manually opened empty shelves stay available until an outside interaction; automatic dismissal follows an ended drag. Pending Undo keeps an emptied shelf available. Shake invocation stays nonactivating; deliberate item selection, menu invocation or the keyboard shortcut permits keyboard interaction.

## Develop

Open [Draglet.xcodeproj](../Draglet.xcodeproj) in Xcode and run the Draglet scheme. No external runtime packages are required. [project.yml](../project.yml) owns project configuration; regenerate after adding source files. XcodeGen is needed only to regenerate the project, not to build the included project.

The supported build interface is [scripts/draglet.sh](../scripts/draglet.sh):

```sh
bash scripts/draglet.sh help
bash scripts/draglet.sh generate
bash scripts/draglet.sh build
bash scripts/draglet.sh test
bash scripts/draglet.sh package
```

Builds use a temporary output directory scoped to this checkout. The script prints the app/package paths. Xcode may print an App Intents metadata-skipped warning because this utility intentionally has no App Intents integration.

Debug builds accept `--show-shelf` to exercise the real panel at launch. This flag does not load sample items and is absent from Release behavior. Tests create their own temporary files and clean them up.

## Maintainer routes

- [Architecture and decisions](architecture.md)
- [Privacy](privacy.md)
- [Release procedure](release.md)
- [Manual acceptance](manual-testing.md)
