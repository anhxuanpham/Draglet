<p align="center">
  <img src="Draglet/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="96" height="96" alt="Draglet icon">
</p>

# Draglet

**Drop it here. Finish the drag later.**

A native macOS menu bar shelf for moving things between Finder windows and apps. Hold files, folders, text, links and images while you find their destination.

Built by **[William](https://github.com/anhxuanpham)**. Requires **macOS 14 or later**. Written in Swift with AppKit and SwiftUI; no external runtime dependencies.

## How it works

1. Start dragging a file in Finder and shake sideways, or open the shelf with **Control–Option–Space**.
2. Drop your items into Draglet, then switch to another window or app.
3. Drag a row or a selected group from the shelf to the destination.

Draglet holds references to original files. The destination app performs the copy or link. Cancelled drags keep your items in the shelf.

## Features

- **A shelf that stays out of the way:** shake activation, configurable shortcut, movable panel and menu-bar item count.
- **Group transfers:** Cmd-click or Shift-click to select items, then drag the group.
- **Quick inspection:** Space or double-click for Quick Look; reveal originals in Finder.
- **Keep your place:** hiding preserves items; Undo restores manually removed entries.
- **Named shelves:** separate groups of items and optionally restore them after quitting.
- **Favorite folders:** open a destination in Finder from the shelf menu.
- **Rich content:** hold text, web links and images as well as files and folders.
- **Local by design:** no account, uploads, analytics or clipboard-history monitoring.

[Usage and keyboard controls](docs/README.md) · [Privacy](docs/privacy.md) · [Architecture](docs/architecture.md)

## Build and test

Install Xcode with the macOS SDK, then open `Draglet.xcodeproj` and run the **Draglet** scheme. The generated Xcode project is included; XcodeGen is needed only when changing `project.yml`.

```sh
git clone https://github.com/anhxuanpham/Draglet.git
cd Draglet
bash scripts/draglet.sh build
bash scripts/draglet.sh test
bash scripts/draglet.sh package
```

The package command produces a universal Intel/Apple Silicon app, ZIP and DMG under `artifacts/`. Local packages are ad-hoc signed and are **not Apple-notarized**. See the [release procedure](docs/release.md) for Developer ID distribution and the [manual checklist](docs/manual-testing.md) for native drag, Spaces and display acceptance.

## Contributing

[Open an issue](https://github.com/anhxuanpham/Draglet/issues) for bugs or feature ideas. For drag issues, include macOS version, source/destination apps and reproducible steps using disposable files. Run the tests for code changes; changes to the project manifest also require regenerating the Xcode project.

## Author and license

Copyright © 2026 **William** ([@anhxuanpham](https://github.com/anhxuanpham)).

Draglet's source code, documentation and included artwork are licensed under the **GNU General Public License, version 3 only** (`GPL-3.0-only`). See [LICENSE](LICENSE) for the full terms. Draglet is provided without warranty.

## Website

The public landing page is in [`site/`](site/). Submission copy for Unikorn is in [`docs/unikorn-submission.md`](docs/unikorn-submission.md).
