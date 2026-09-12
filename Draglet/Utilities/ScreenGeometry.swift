// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

enum ScreenGeometry {
    static func screenIndex(containing point: CGPoint, frames: [CGRect]) -> Int? {
        if let index = frames.firstIndex(where: { $0.contains(point) }) { return index }
        // A cursor can briefly lie in a display gap or on a disconnected screen.
        return frames.indices.min { distanceSquared(point, to: frames[$0]) < distanceSquared(point, to: frames[$1]) }
    }

    private static func distanceSquared(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
