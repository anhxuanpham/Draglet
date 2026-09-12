// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

enum ShelfPositioner {
    static func frame(near cursor: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        var x = cursor.x + 28
        var y = cursor.y - 45
        if x + width > visibleFrame.maxX { x = cursor.x - 28 - width }
        if y + height > visibleFrame.maxY { y = cursor.y - height - 16 }
        x = min(max(x, visibleFrame.minX), visibleFrame.maxX - width)
        y = min(max(y, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
