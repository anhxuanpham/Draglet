# Native acceptance

Use disposable test files with known contents. Record outcomes and machine details under `plans/reports/`. Keep untested rows explicitly unverified. Never use sending a message/email as a drag destination test without authorization to send it; staging an attachment is sufficient.

## Product loop

Open Finder and Draglet. Drag a file, shake horizontally, and drop it into the shelf. Release the mouse, switch Finder windows or Spaces, drag the held row to the destination, and confirm the shelf disappears. Check the original and destination contents. Verify that summoning the shelf did not change the active app.

Repeat using the menu's **Show Shelf**, multi-selection, a folder containing files, and **Drag all**. Try Escape/cancel and an invalid destination; all references must remain. Return a drag to the shelf itself; it must not consume its own references. Move/delete a source externally, then attempt to drag its old reference; confirm the error and no silent removal.

## Sources and destinations

- Sources: Finder list view, Finder icon view, Desktop, external drive.
- Destinations: another Finder window, Desktop, Messages attachment area, Mail draft attachment area, browser upload input.
- Include spaces, Unicode, long names, duplicate drops, and several dozen files. Scroll to the last item and drag it.

## Gesture and desktop

- Fast straight movement, vertical movement, small jitter and slow wandering must not summon the shelf.
- Deliberate horizontal shake during a fresh supported file, text, link or image drag should summon the shelf; idle movement and stale pasteboards must not.
- After a successful file drag, repeat an ordinary non-file mouse drag to check stale pasteboard rejection.
- Try every sensitivity preset and two gestures separated by the cooldown.
- Summon an empty shelf by shaking, release the mouse and wait at least five seconds: it must stay visible. Repeat with the shortcut. An outside click may dismiss the empty shelf when automatic dismissal is enabled; dragging the last held items out successfully should still dismiss it.
- Test each screen edge on built-in and external displays, left/right and vertical arrangements, mixed scaling, and display disconnect while holding files.
- Test normal Spaces, switching Space while holding files, and a fullscreen destination. macOS policies may constrain overlays; record the OS and exact behavior.

## Preferences and accessibility

Verify persistence after restart. Disable automatic dismissal and single-use removal separately. Enable then disable Launch at Login on an installed signed app, check the actual macOS Login Items state, and test login once. Do not infer registration from a saved toggle.

Check light/dark appearance, Increase Contrast, Reduce Transparency, Reduce Motion, and VoiceOver labels/actions. Confirm a file row's remove button changes only the shelf, not the filesystem.

## Shelf experience

Hide a populated shelf with × and Escape, then reopen using the menu and shortcut. Verify the same items remain. Remove one item, transfer another, add a new drop, then Undo: only the manually removed item should return. Clear All followed by Undo must preserve the original order.

Use Cmd/Shift-click to select a subset; drag a selected row and the bottom handle separately. Cancel, reject and complete each drag. Check exact source and destination contents. Move the shelf by its header tray icon, add more items and confirm the position remains usable.

Create two named shelves, rename them, switch repeatedly and test separate selection/Undo. Enable session restore only with disposable data, quit normally, relaunch and check both shelves. Include text, a PNG image, a link, and a source moved externally. Disable restore, quit and verify no saved workspace remains. Confirm registration failures for a conflicting shortcut are shown in Settings.

Preview files, text and images via double-click and Space; link previews should show the URL without browsing. Reveal an original file in Finder. Add/remove a favorite folder, open it from the shelf, then drag there. Test browser image drops both as actual PNG/TIFF data and as remote URLs: the latter stay links.

Exercise long names and repeated names from different directories; inspect 1, 20 and 100 items in both appearances and scroll to the final row. The practice pad should preview the empty shelf. In Finder, hold a file (mouse button down) and shake; the shelf must appear next to the cursor even before a drop target is entered. Test every preset. Verify source-app focus during shake separately from deliberate keyboard invocation.

## Performance and distribution

Measure an optimized Release build before opening the shelf and again after clearing it: idle CPU approximately zero, idle memory below the plan's 50 MB target. Measure actual time to first visible shelf separately from animation completion (target below 100 ms perceived). Test the minimum supported macOS version on hardware or an appropriate VM.

For public release, install the Developer ID signed/notarized artifact on a separate Mac and verify Gatekeeper, launch, Finder workflow and Launch at Login. Record Apple submission IDs and artifact checksums from the release script.
