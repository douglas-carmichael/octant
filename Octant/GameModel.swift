import SwiftUI

enum GamePhase {
    case setup
    case playing
    case results
}

struct RoundResult: Identifiable {
    let id = UUID()
    let round: Int
    let target: Int
    let time: Double
    let clicks: Int
}

@MainActor
final class GameModel: ObservableObject {
    @Published var phase: GamePhase = .setup
    @Published var roundsCount: Int = 5
    @Published var bitsCount: Int = 8

    @Published var currentRound: Int = 0
    @Published var targetNumber: Int = 0
    @Published var bits: [Bool] = []
    @Published var clicks: Int = 0
    @Published var results: [RoundResult] = []
    @Published var roundStartTime: Date = .init()
    @Published var isResolving: Bool = false
    @Published var winFlash: Int = 0

    var maxNumber: Int { (1 << bitsCount) - 1 }

    var currentValue: Int {
        var sum = 0
        for (i, on) in bits.enumerated() where on {
            sum += 1 << i
        }
        return sum
    }

    var binaryString: String {
        guard bitsCount > 0, bits.count == bitsCount else { return "" }
        return (0..<bitsCount).reversed().map { bits[$0] ? "1" : "0" }.joined()
    }

    var averageTime: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.time).reduce(0, +) / Double(results.count)
    }

    var averageClicks: Double {
        guard !results.isEmpty else { return 0 }
        return Double(results.map(\.clicks).reduce(0, +)) / Double(results.count)
    }

    func startGame() {
        results = []
        currentRound = 1
        bits = Array(repeating: false, count: bitsCount)
        targetNumber = randomTarget()
        clicks = 0
        roundStartTime = .init()
        isResolving = false
        phase = .playing
    }

    func toggleBit(_ index: Int) {
        guard !isResolving, index < bits.count else { return }
        clicks += 1
        bits[index].toggle()
        SoundPlayer.shared.play(.click)
        checkWin()
    }

    func playAgain() {
        phase = .setup
    }

    private func checkWin() {
        guard currentValue == targetNumber else { return }
        let elapsed = Date().timeIntervalSince(roundStartTime)
        results.append(RoundResult(
            round: currentRound,
            target: targetNumber,
            time: elapsed,
            clicks: clicks
        ))
        winFlash &+= 1
        isResolving = true
        SoundPlayer.shared.play(.win)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard let self else { return }
            if self.currentRound < self.roundsCount {
                self.advanceRound()
            } else {
                self.phase = .results
                SoundPlayer.shared.play(.finish)
            }
            self.isResolving = false
        }
    }

    private func advanceRound() {
        currentRound += 1
        bits = Array(repeating: false, count: bitsCount)
        targetNumber = randomTarget()
        clicks = 0
        roundStartTime = .init()
    }

    private func randomTarget() -> Int {
        let upper = 1 << bitsCount
        return Int.random(in: 1..<upper)
    }
}
