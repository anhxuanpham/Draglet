// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 William

import Foundation

struct MouseSample {
    let position: CGPoint
    let timestamp: TimeInterval
}

struct ShakeConfiguration {
    var window: TimeInterval = 0.45
    var minimumReversals = 3
    var minimumTravel: CGFloat = 140
    var minimumDelta: CGFloat = 12
    var cooldown: TimeInterval = 0.8

    static func preset(_ sensitivity: ShakeSensitivity) -> ShakeConfiguration {
        switch sensitivity {
        case .low: return ShakeConfiguration(minimumReversals: 2, minimumTravel: 100)
        case .medium: return ShakeConfiguration()
        case .high: return ShakeConfiguration(minimumReversals: 4, minimumTravel: 200)
        }
    }
}

struct ShakeDetector {
    var configuration = ShakeConfiguration()
    private(set) var samples: [MouseSample] = []
    private var lastTrigger: TimeInterval?
    static let maximumSamples = 512

    mutating func reset() { samples.removeAll(keepingCapacity: true) }

    mutating func add(_ sample: MouseSample, isDragging: Bool) -> Bool {
        guard isDragging, sample.timestamp.isFinite,
              sample.position.x.isFinite, sample.position.y.isFinite else { reset(); return false }
        if let previous = samples.last, sample.timestamp <= previous.timestamp { return false }
        samples.removeAll { sample.timestamp - $0.timestamp > configuration.window }
        samples.append(sample)
        if samples.count > Self.maximumSamples { samples.removeFirst(samples.count - Self.maximumSamples) }
        if let lastTrigger, sample.timestamp - lastTrigger < configuration.cooldown { return false }
        guard let first = samples.first else { return false }

        var anchorX = first.position.x
        var direction = 0
        var reversals = 0
        var travel: CGFloat = 0
        for current in samples.dropFirst() {
            let delta = current.position.x - anchorX
            // Accumulate sub-threshold samples: smooth high-frequency pointer movement
            // must work even when no single event moves by 12 points.
            guard abs(delta) >= configuration.minimumDelta else { continue }
            let nextDirection = delta > 0 ? 1 : -1
            if direction != 0 && direction != nextDirection { reversals += 1 }
            direction = nextDirection
            travel += abs(delta)
            anchorX = current.position.x
        }
        guard reversals >= configuration.minimumReversals, travel >= configuration.minimumTravel else { return false }
        lastTrigger = sample.timestamp
        samples = [sample]
        return true
    }
}
