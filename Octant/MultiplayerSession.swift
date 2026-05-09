import Foundation
import SwiftUI
import Combine
import Network
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MultiplayerSession: ObservableObject {

    // MARK: - Published state

    @Published var phase: NetSessionPhase = .menu
    @Published var mode: NetSessionMode = .none

    @Published var localPlayerName: String = MultiplayerSession.defaultPlayerName()
    @Published var localPlayerID: UUID = UUID()

    @Published var players: [NetPlayer] = []
    @Published var config: NetGameConfig = NetGameConfig()
    @Published var hostServiceName: String = ""

    @Published var discoveredHosts: [DiscoveredHost] = []

    // Active round (shared across host & client)
    @Published var currentRound: Int = 0
    @Published var totalRounds: Int = 0
    @Published var currentTarget: Int = 0
    @Published var currentBitsCount: Int = 0
    @Published var deadline: Date?

    // Per-round local state
    @Published var bits: [Bool] = []
    @Published var clicks: Int = 0
    @Published var roundStartTime: Date = .init()
    @Published var hasFinishedRound: Bool = false
    @Published var lastSolveTime: Double = 0
    @Published var winFlash: Int = 0
    @Published var isResolving: Bool = false

    // Round / final results
    @Published var roundResults: [NetRoundResult] = []
    @Published var finalStandings: [PlayerStanding] = []

    // Status
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var countdownSeconds: Int = 0
    @Published var isAdmin: Bool = false

    private(set) var driver: NetSessionDriver?

    // MARK: - Lifecycle

    func resetForMenu() {
        driver?.leave()
        driver = nil
        mode = .none
        players = []
        currentRound = 0
        totalRounds = 0
        currentTarget = 0
        currentBitsCount = 0
        deadline = nil
        bits = []
        clicks = 0
        hasFinishedRound = false
        lastSolveTime = 0
        isResolving = false
        roundResults = []
        finalStandings = []
        errorMessage = nil
        statusMessage = nil
        countdownSeconds = 0
        discoveredHosts = []
        isAdmin = false
        phase = .menu
    }

    // MARK: - Mode entry points

    func startHosting() {
        resetForMenu()
        mode = .host
        let driver = HostDriver(session: self)
        self.driver = driver
        isAdmin = true
        driver.bootstrap()
    }

    func startBrowsing() {
        resetForMenu()
        mode = .client
        let driver = ClientDriver(session: self)
        self.driver = driver
        isAdmin = false
        driver.bootstrap()
    }

    // MARK: - Forwarded actions

    func joinHost(_ host: DiscoveredHost) {
        (driver as? ClientDriver)?.connect(to: host)
    }

    func startGame() { driver?.startGame() }
    func nextRound() { driver?.nextRound() }
    func kick(_ player: NetPlayer) { driver?.kick(player) }
    func leave() { resetForMenu() }

    func updateConfig(_ new: NetGameConfig) {
        config = new
        driver?.updateConfig(new)
    }

    // MARK: - Round play

    var currentValue: Int {
        var sum = 0
        for (i, on) in bits.enumerated() where on {
            sum += 1 << i
        }
        return sum
    }

    var binaryString: String {
        guard currentBitsCount > 0, bits.count == currentBitsCount else { return "" }
        return (0..<currentBitsCount).reversed().map { bits[$0] ? "1" : "0" }.joined()
    }

    func toggleBit(_ index: Int) {
        guard phase == .playing,
              !isResolving, !hasFinishedRound,
              index < bits.count else { return }
        clicks += 1
        bits[index].toggle()
        if currentValue == currentTarget {
            let elapsed = Date().timeIntervalSince(roundStartTime)
            lastSolveTime = elapsed
            hasFinishedRound = true
            isResolving = true
            winFlash &+= 1
            driver?.reportFinished(round: currentRound, time: elapsed, clicks: clicks)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                self?.isResolving = false
            }
        }
    }

    // MARK: - Helpers

    static func defaultPlayerName() -> String {
        #if os(macOS)
        let host = Host.current().localizedName ?? NSUserName()
        #elseif canImport(UIKit)
        let host = UIDevice.current.name
        #else
        let host = ProcessInfo.processInfo.hostName
        #endif
        let trimmed = host
            .replacingOccurrences(
                of: "[\u{2018}\u{2019}\u{02BC}']s\\s.*$",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s+(Mac|Apple TV|iPhone|iPad).*$",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
        let cleaned = trimmed.isEmpty ? "Player" : trimmed
        return String(cleaned.prefix(20))
    }
}

@MainActor
protocol NetSessionDriver: AnyObject {
    func bootstrap()
    func startGame()
    func reportFinished(round: Int, time: Double, clicks: Int)
    func nextRound()
    func kick(_ player: NetPlayer)
    func updateConfig(_ config: NetGameConfig)
    func leave()
}

extension NetSessionDriver {
    func startGame() {}
    func reportFinished(round: Int, time: Double, clicks: Int) {}
    func nextRound() {}
    func kick(_ player: NetPlayer) {}
    func updateConfig(_ config: NetGameConfig) {}
    func leave() {}
}
