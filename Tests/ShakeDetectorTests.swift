// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import XCTest
@testable import Draglet

final class ShakeDetectorTests: XCTestCase {
    private func sample(_ x: CGFloat, _ time: TimeInterval) -> MouseSample {
        MouseSample(position: CGPoint(x: x, y: 100), timestamp: time)
    }

    private func gesture(_ detector: inout ShakeDetector, start: TimeInterval = 1, interval: TimeInterval = 0.07) -> [Bool] {
        [0, 40, 0, 40, 0].enumerated().map { detector.add(sample(CGFloat($0.element), start + Double($0.offset) * interval), isDragging: true) }
    }

    func testThreeStrongReversalsTrigger() {
        var detector = ShakeDetector()
        XCTAssertEqual(gesture(&detector), [false, false, false, false, true])
    }

    func testFastOneDirectionNeverTriggers() {
        var detector = ShakeDetector()
        for i in 0..<15 { XCTAssertFalse(detector.add(sample(CGFloat(i * 60), Double(i) * 0.01), isDragging: true)) }
    }

    func testSlowMovementOutsideWindowNeverTriggers() {
        var detector = ShakeDetector()
        XCTAssertFalse(gesture(&detector, interval: 0.2).contains(true))
    }

    func testTinyJitterNeverTriggers() {
        var detector = ShakeDetector()
        for i in 0..<100 { XCTAssertFalse(detector.add(sample(i.isMultiple(of: 2) ? 5 : -5, Double(i) * 0.004), isDragging: true)) }
    }

    func testVerticalMovementNeverTriggers() {
        var detector = ShakeDetector()
        for i in 0..<20 {
            XCTAssertFalse(detector.add(MouseSample(position: CGPoint(x: 0, y: i * 50), timestamp: Double(i) * 0.01), isDragging: true))
        }
    }

    func testCooldownSurvivesResetAndExpires() {
        var detector = ShakeDetector()
        XCTAssertTrue(gesture(&detector).last!)
        detector.reset()
        XCTAssertFalse(gesture(&detector, start: 1.4).contains(true))
        detector.reset()
        XCTAssertTrue(gesture(&detector, start: 2.2).last!)
    }

    func testGestureRequiresDragging() {
        var detector = ShakeDetector()
        for (i, x) in [0, 40, 0, 40, 0].enumerated() {
            XCTAssertFalse(detector.add(sample(CGFloat(x), Double(i) * 0.07), isDragging: false))
        }
        XCTAssertTrue(detector.samples.isEmpty)
    }

    func testSmoothHighFrequencyMovementAccumulatesSmallDeltas() {
        var detector = ShakeDetector()
        var triggered = false
        for i in 0...160 {
            let leg = i / 40
            let x = leg.isMultiple(of: 2) ? i % 40 : 40 - i % 40
            triggered = detector.add(sample(CGFloat(x), 1 + Double(i) * 0.002), isDragging: true) || triggered
        }
        XCTAssertTrue(triggered)
    }

    func testExpiredTravelCannotCombineWithNewGesture() {
        var detector = ShakeDetector()
        _ = detector.add(sample(0, 1), isDragging: true)
        _ = detector.add(sample(40, 1.1), isDragging: true)
        _ = detector.add(sample(0, 1.2), isDragging: true)
        XCTAssertFalse(detector.add(sample(40, 2), isDragging: true))
        XCTAssertFalse(detector.add(sample(0, 2.1), isDragging: true))
    }

    func testSampleBufferIsBoundedAndRejectsInvalidInput() {
        var detector = ShakeDetector()
        for i in 0..<10000 { _ = detector.add(sample(CGFloat(i), Double(i) / 100000), isDragging: true) }
        XCTAssertLessThanOrEqual(detector.samples.count, ShakeDetector.maximumSamples)
        XCTAssertFalse(detector.add(sample(.nan, 1), isDragging: true))
        XCTAssertTrue(detector.samples.isEmpty)
    }

    func testPresetMappingMatchesProductPlan() {
        let low = ShakeConfiguration.preset(.low), medium = ShakeConfiguration.preset(.medium), high = ShakeConfiguration.preset(.high)
        XCTAssertLessThan(low.minimumTravel, medium.minimumTravel)
        XCTAssertLessThan(low.minimumReversals, medium.minimumReversals)
        XCTAssertGreaterThan(high.minimumTravel, medium.minimumTravel)
        XCTAssertGreaterThan(high.minimumReversals, medium.minimumReversals)
        XCTAssertEqual(medium.window, 0.45)
        XCTAssertEqual(medium.cooldown, 0.8)
    }
}
