// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

enum FileMetadataService {
    struct Result {
        var items: [ShelfItem] = []
        var rejectedCount = 0
        var duplicateCount = 0
    }

    static func read(_ urls: [URL]) -> Result {
        var result = Result()
        var seen = Set<URL>()
        for input in urls {
            guard isLocalFileURL(input) else { result.rejectedCount += 1; continue }
            let url = input.standardizedFileURL
            guard seen.insert(url).inserted else { result.duplicateCount += 1; continue }
            do {
                let values = try url.resourceValues(forKeys: [.nameKey, .fileSizeKey, .isDirectoryKey])
                guard FileManager.default.fileExists(atPath: url.path) else {
                    result.rejectedCount += 1
                    continue
                }
                result.items.append(ShelfItem(
                    url: url,
                    name: values.name,
                    fileSize: values.fileSize.map(Int64.init),
                    isDirectory: values.isDirectory ?? false
                ))
            } catch {
                result.rejectedCount += 1
            }
        }
        return result
    }

    static func isLocalFileURL(_ url: URL) -> Bool {
        url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost")
    }
}
