import Foundation

/// Pure, dependency-free bracket math so it can be unit-tested and reasoned
/// about without touching the SwiftData layer (and without any Xcode-Project
/// edits). Generics keep it independent of the `Player` model — the CLI harness
/// compiles this file alone with `xcrun swiftc` and feeds it `Int` seed labels.
enum DrawEngine {

    /// Smallest power of two >= `n` (clamped to a minimum of 2).
    static func bracketSize(for entryCount: Int) -> Int {
        var size = 1
        let target = max(entryCount, 2)
        while size < target { size <<= 1 }
        return size
    }

    /// Number of knockout rounds required by a bracket of `size` leaves.
    static func depth(for size: Int) -> Int {
        Int(log2(Double(max(size, 1))))
    }

    /// Number of byes required in the first round for a `size` bracket with
    /// `entries` real players. Byes pair with the lowest seeds.
    static func byeCount(entries: Int, size: Int) -> Int {
        max(0, size - entries)
    }

    /// Classic alternating seed placement so the top two seeds can only meet in
    /// the final. Returns each slot's seed label (index 0 => the player who
    /// must be a 1-seed, etc.). Size must be a power of two.
    ///
    /// Example for size 8: [1, 8, 4, 5, 2, 7, 3, 6]
    static func seedOrder(size: Int) -> [Int] {
        let order = seedOrderSlow(size: size)
        return order
    }

    static func seedOrderSlow(size: Int) -> [Int] {
        var order = [1]
        var half = 1
        while half < size {
            let nextHalf = half * 2
            var expanded: [Int] = []
            for seed in order {
                expanded.append(seed)
                expanded.append(nextHalf + 1 - seed)
            }
            order = expanded
            half = nextHalf
        }
        return order
    }

    /// Places entries into a seeded (rank-ordered) bracket. Returns pairs for
    /// the first round. `Player` is opaque via the generic `T`; `T?` allows a
    /// bye to be expressed as `nil`.
    static func seededPairs<T>(entries: [T], size: Int) -> [(T?, T?)] {
        let order = seedOrder(size: size)
        var slots: [T?] = Array(repeating: nil, count: size)
        for (index, seedLabel) in order.enumerated() {
            let entryIndex = seedLabel - 1
            if entryIndex < entries.count {
                slots[seedLabel - 1] = entries[entryIndex]
            }
        }
        // Slots that never received a real entry become byes (nil).
        return stride(from: 0, to: size, by: 2).map { i in
            (slots[i], slots[i + 1])
        }
    }

    /// Unseeded (shuffled) first round for a bracket: fill in order then any
    /// leftover slots become byes.
    static func shuffledPairs<T>(entries: [T], size: Int) -> [(T?, T?)] {
        var slots: [T?] = entries
        slots.append(contentsOf: Array(repeating: nil, count: max(0, size - entries.count)))
        return stride(from: 0, to: size, by: 2).map { i in
            (slots[i], slots[i + 1])
        }
    }

    /// Standard Round-Robin circle method. Produces all rounds of play for
    /// `count` entrants; with an odd count one "bye" (the `nil` side) rests
    /// each round. Returns per-round pairs as (indexA, indexB?).
    static func roundRobinRounds(count: Int) -> [[(Int, Int?)]] {
        let n = count
        let total = n % 2 == 0 ? n : n + 1
        var labels: [Int?] = (0..<n).map { $0 }
        labels.append(contentsOf: Array(repeating: nil, count: total - n))

        var allRounds: [[(Int, Int?)]] = []
        for _ in 0..<(total - 1) {
            var roundPairs: [(Int, Int?)] = []
            for i in 0..<(total / 2) {
                let a = labels[i]
                let b = labels[total - 1 - i]
                roundPairs.append((a!, b))
            }
            allRounds.append(roundPairs)

            // Rotate: keep [0] fixed, move last to position 1.
            guard let last = labels.last else { break }
            labels.removeLast()
            labels.insert(last, at: 1)
        }
        return allRounds
    }

    /// Deterministic helper for tests: does a bracket place the two strongest
    /// seeds in opposite halves (so they only meet in the final)?
    static func topSeedsInOppositeHalves(size: Int) -> Bool {
        let order = seedOrder(size: size)
        guard let slot1 = order.firstIndex(of: 1),
              let slot2 = order.firstIndex(of: 2) else { return false }
        let half = size / 2
        return (slot1 < half) != (slot2 < half)
    }
}
