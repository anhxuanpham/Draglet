# Privacy

Draglet has no account, analytics SDK, server, or application network client. It does not upload files or monitor clipboard history.

Shelves hold file references and any explicitly dropped text, links or image bytes. Original files are never copied, moved, renamed or deleted by Draglet. The destination app handles the copy/link requested by a drag out. Text and image items create private temporary backing files for previews and file-oriented destinations. Those backing files last until normal app termination; an abnormal termination can leave temporary files for OS cleanup. Undo keeps removed references and rich content in memory for a bounded number of actions during the session.

Settings and favorite folder paths are stored locally in macOS preferences. **Restore shelves after quitting** is off by default. When enabled, the current named shelves, file paths, text, links and image content are saved in `~/Library/Application Support/Draglet/workspace.json`. Original file contents are not included. This is a local snapshot, not an encrypted vault or historical archive; OS account and disk protections apply. Turning the option off deletes the snapshot and keeps the current in-memory session. Missing original files remain marked unavailable on restore. Storage owners: [WorkspacePersistence](../Draglet/Services/WorkspacePersistence.swift), [ContentStorage](../Draglet/Services/ContentStorage.swift).

File presentation uses metadata and system icons. For thumbnails and explicit previews, Draglet uses macOS Quick Look. Quick Look may read file contents and use its system-managed cache. Draglet's thumbnail cache is bounded and kept in memory. Link previews display the URL as text, without fetching the website.

Draglet observes left mouse down/drag/up events to recognize the gesture. It registers the configured shortcut without monitoring typing or recording pointer history. The shortcut recorder accepts keys only while explicitly recording in Settings. Launch at Login is registered only when you enable it and can be disabled in Settings or macOS Login Items.

Crash-reporting decision: no third-party crash SDK or automatic report upload. Local unified logs contain lifecycle messages and item counts, not file paths or names. macOS may collect its own diagnostics according to your system settings.
