// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import XCTest
@testable import Draglet

final class ShelfPositionerTests: XCTestCase {
    func testDefaultOffset() {
        let frame = ShelfPositioner.frame(near: CGPoint(x: 300, y: 300), size: CGSize(width: 280, height: 82), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 800))
        XCTAssertEqual(frame.origin, CGPoint(x: 328, y: 255))
    }

    func testEdgesAndNegativeDisplayOrigins() {
        for visible in [CGRect(x: 0, y: 24, width: 1440, height: 850), CGRect(x: -1920, y: -300, width: 1920, height: 1080)] {
            for x in [visible.minX, visible.midX, visible.maxX] {
                for y in [visible.minY, visible.midY, visible.maxY] {
                    let frame = ShelfPositioner.frame(near: CGPoint(x: x, y: y), size: CGSize(width: 280, height: 320), visibleFrame: visible)
                    XCTAssertTrue(visible.contains(frame), "\(frame) must fit \(visible)")
                }
            }
        }
    }

    func testSmallScreenClampsSize() {
        let visible = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertEqual(ShelfPositioner.frame(near: .zero, size: CGSize(width: 280, height: 320), visibleFrame: visible), visible)
    }

    func testDisplaySelectionAndGap() {
        let frames = [CGRect(x: -1200, y: 0, width: 1000, height: 800), CGRect(x: 0, y: 0, width: 1440, height: 900)]
        XCTAssertEqual(ScreenGeometry.screenIndex(containing: CGPoint(x: -500, y: 300), frames: frames), 0)
        XCTAssertEqual(ScreenGeometry.screenIndex(containing: CGPoint(x: -50, y: 300), frames: frames), 1)
        XCTAssertNil(ScreenGeometry.screenIndex(containing: .zero, frames: []))
    }
}
