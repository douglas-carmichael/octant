import Foundation
import Network
import SwiftUI

// MARK: - Host

@MainActor
final class HostDriver: NetSessionDriver {

    private weak var session: MultiplayerSession?
    private var hostService: HostService?
    private var peers: [PeerConnection] = []
    private var roundIndex: Int = 0
    private var roundTargets: [Int] = []
    private var pendingScores: [PlayerScore] = []
    private var startCountdownTimer: Timer?
    private var roundTimer: Timer?
    private var standings: [UUID: (name: String, solved: Int, time: Double, clicks: Int)] = [:]

    init(session: MultiplayerSession) {
        self.session = session
    }

    func bootstrap() {
        guard let session else {
            #if DEBUG
            NSLog("[HostDriver] bootstrap: session is nil!")
            #endif
            return
        }
        let me = NetPlayer(id: session.localPlayerID, name: session.localPlayerName, isHost: true)
        session.players = [me]
        session.config = NetGameConfig()
        session.hostServiceName = HostDriver.makeServiceName(for: session.localPlayerName)
        session.phase = .hostLobby
        #if DEBUG
        NSLog("[HostDriver] bootstrap complete, phase=\(session.phase), players=\(session.players.count)")
        #endif

        let service = HostService(serviceName: session.hostServiceName)
        service.onAccepted = { [weak self] peer in self?.handleNewPeer(peer) }
        service.onError = { [weak self] error in
            self?.session?.errorMessage = error.localizedDescription
        }
        service.start()
        hostService = service
        broadcastLobby()
    }

    private static func makeServiceName(for hostName: String) -> String {
        let trimmed = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        #if os(macOS)
        let fallback = NSUserName()
        #else
        let fallback = MultiplayerSession.defaultPlayerName()
        #endif
        let base = trimmed.isEmpty ? fallback : trimmed
        let format = LanguageManager.localized("host.service.name", value: "%@'s Octant")
        return String(format: format, base)
    }

    private func handleNewPeer(_ peer: PeerConnection) {
        #if DEBUG
        NSLog("[HostDriver] handleNewPeer called, current peers: \(peers.count)")
        #endif
        peers.append(peer)
        peer.onMessage = { [weak self, weak peer] msg in
            guard let self, let peer else { return }
            #if DEBUG
            NSLog("[HostDriver] received message: \(msg)")
            #endif
            self.handleClientMessage(msg, from: peer)
        }
        peer.onClosed = { [weak self, weak peer] _ in
            guard let self, let peer else { return }
            #if DEBUG
            NSLog("[HostDriver] peer closed, playerID: \(String(describing: peer.playerID))")
            #endif
            self.peers.removeAll { $0 === peer }
            if let pid = peer.playerID {
                self.session?.players.removeAll { $0.id == pid }
                self.broadcastLobby()
            }
        }
        peer.start()
    }

    private func handleClientMessage(_ msg: WireMessage, from peer: PeerConnection) {
        guard let session else {
            #if DEBUG
            NSLog("[HostDriver] session is nil!")
            #endif
            return
        }
        switch msg {
        case .hello(let name, let playerID):
            #if DEBUG
            NSLog("[HostDriver] hello from \(name), players: \(session.players.count)/\(session.config.maxPlayers), phase: \(session.phase)")
            #endif
            if session.players.count >= session.config.maxPlayers {
                #if DEBUG
                NSLog("[HostDriver] rejecting: lobby full")
                #endif
                peer.sendAndClose(.error(message: LanguageManager.localized("error.lobbyFull", value: "The lobby is full.")))
                return
            }
            if session.phase != .hostLobby {
                #if DEBUG
                NSLog("[HostDriver] rejecting: not in lobby, phase=\(session.phase)")
                #endif
                peer.sendAndClose(.error(message: LanguageManager.localized("error.gameInProgress", value: "A game is already in progress.")))
                return
            }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanName = trimmed.isEmpty ? LanguageManager.localized("player.guest", value: "Guest") : trimmed
            peer.playerID = playerID
            peer.playerName = cleanName
            let player = NetPlayer(id: playerID, name: cleanName, isHost: false)
            session.players.append(player)
            peer.send(.youAre(playerID: playerID, isAdmin: false))
            broadcastLobby()

        case .finished(let round, let time, let clicks):
            guard session.phase == .playing,
                  round == session.currentRound,
                  let pid = peer.playerID,
                  let name = peer.playerName,
                  !pendingScores.contains(where: { $0.playerID == pid }) else { return }
            pendingScores.append(PlayerScore(playerID: pid, playerName: name, solved: true, time: time, clicks: clicks))
            checkRoundComplete()

        default:
            break
        }
    }

    func updateConfig(_ config: NetGameConfig) {
        session?.config = config
        broadcastLobby()
    }

    func startGame() {
        guard let session, !session.players.isEmpty else { return }
        let upper = 1 << session.config.bitsCount
        roundTargets = (0..<session.config.rounds).map { _ in Int.random(in: 1..<upper) }
        roundIndex = 0
        session.totalRounds = roundTargets.count
        session.roundResults = []
        standings = [:]
        for player in session.players {
            standings[player.id] = (name: player.name, solved: 0, time: 0, clicks: 0)
        }
        session.phase = .countdown
        session.countdownSeconds = 5
        broadcast(.startCountdown(seconds: session.countdownSeconds))
        startCountdownTimer?.invalidate()
        startCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, let session = self.session else { timer.invalidate(); return }
                session.countdownSeconds -= 1
                self.broadcast(.startCountdown(seconds: session.countdownSeconds))
                if session.countdownSeconds > 0 {
                    SoundPlayer.shared.play(.tick)
                }
                if session.countdownSeconds <= 0 {
                    timer.invalidate()
                    self.beginNextRound()
                }
            }
        }
    }

    private func beginNextRound() {
        guard let session else { return }
        if roundIndex >= roundTargets.count {
            finishGame()
            return
        }
        let target = roundTargets[roundIndex]
        pendingScores = []
        session.currentRound = roundIndex + 1
        session.currentTarget = target
        session.currentBitsCount = session.config.bitsCount
        session.bits = Array(repeating: false, count: session.config.bitsCount)
        session.clicks = 0
        session.hasFinishedRound = false
        session.lastSolveTime = 0
        session.isResolving = false
        let deadline = Date().addingTimeInterval(TimeInterval(session.config.secondsPerRound))
        session.deadline = deadline
        session.roundStartTime = Date()
        session.phase = .playing
        broadcast(.round(round: session.currentRound,
                         total: roundTargets.count,
                         target: target,
                         bitsCount: session.config.bitsCount,
                         deadlineEpoch: deadline.timeIntervalSince1970))
        SoundPlayer.shared.play(.start)
        startRoundTimer()
    }

    private func startRoundTimer() {
        roundTimer?.invalidate()
        roundTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, let session = self.session, let deadline = session.deadline else {
                    timer.invalidate(); return
                }
                if Date() >= deadline.addingTimeInterval(1.0) {
                    timer.invalidate()
                    self.timeoutCurrentRound()
                }
            }
        }
    }

    func reportFinished(round: Int, time: Double, clicks: Int) {
        guard let session, round == session.currentRound else { return }
        let me = session.localPlayerID
        if pendingScores.contains(where: { $0.playerID == me }) { return }
        pendingScores.append(PlayerScore(playerID: me, playerName: session.localPlayerName,
                                         solved: true, time: time, clicks: clicks))
        checkRoundComplete()
    }

    private func checkRoundComplete() {
        guard let session else { return }
        if pendingScores.count >= session.players.count {
            commitRound()
        }
    }

    private func timeoutCurrentRound() {
        guard let session else { return }
        let limit = Double(session.config.secondsPerRound)
        let localUnsolved = !pendingScores.contains { $0.playerID == session.localPlayerID }
        for player in session.players where !pendingScores.contains(where: { $0.playerID == player.id }) {
            pendingScores.append(PlayerScore(playerID: player.id, playerName: player.name,
                                             solved: false, time: limit, clicks: 0))
        }
        if localUnsolved {
            SoundPlayer.shared.play(.error)
        }
        commitRound()
    }

    private func commitRound() {
        guard let session else { return }
        roundTimer?.invalidate()
        roundTimer = nil
        let target = session.currentTarget
        let bitsCount = session.currentBitsCount
        let result = NetRoundResult(round: roundIndex + 1, total: roundTargets.count,
                                    target: target, bitsCount: bitsCount, scores: pendingScores)
        session.roundResults.append(result)
        for score in pendingScores {
            var entry = standings[score.playerID] ?? (name: score.playerName, solved: 0, time: 0, clicks: 0)
            entry.name = score.playerName
            if score.solved { entry.solved += 1 }
            entry.time += score.time
            entry.clicks += score.clicks
            standings[score.playerID] = entry
        }
        session.deadline = nil
        session.phase = .roundResults
        roundIndex += 1
        broadcast(.roundResults(round: result.round, total: result.total,
                                target: result.target, bitsCount: result.bitsCount,
                                scores: pendingScores))
    }

    func nextRound() {
        guard let session else { return }
        if roundIndex < roundTargets.count {
            beginNextRound()
        } else {
            finishGame()
        }
        _ = session
    }

    private func finishGame() {
        guard let session else { return }
        let standingsList: [PlayerStanding] = session.players.map { p in
            let s = standings[p.id] ?? (name: p.name, solved: 0, time: 0, clicks: 0)
            return PlayerStanding(playerID: p.id, playerName: s.name,
                                  roundsSolved: s.solved, totalTime: s.time, totalClicks: s.clicks)
        }.sorted { lhs, rhs in
            if lhs.roundsSolved != rhs.roundsSolved { return lhs.roundsSolved > rhs.roundsSolved }
            if lhs.totalTime != rhs.totalTime { return lhs.totalTime < rhs.totalTime }
            return lhs.totalClicks < rhs.totalClicks
        }
        session.finalStandings = standingsList
        session.phase = .finalResults
        broadcast(.gameOver(finalStandings: standingsList))
        SoundPlayer.shared.play(.finish)
    }

    func kick(_ player: NetPlayer) {
        guard let session else { return }
        if player.id == session.localPlayerID { return }
        if let peer = peers.first(where: { $0.playerID == player.id }) {
            peer.send(.kick(playerID: player.id))
            peer.close()
        }
        session.players.removeAll { $0.id == player.id }
        broadcastLobby()
    }

    func leave() {
        startCountdownTimer?.invalidate()
        roundTimer?.invalidate()
        for peer in peers { peer.close() }
        peers = []
        hostService?.stop()
        hostService = nil
    }

    // MARK: - Broadcasting

    private func broadcastLobby() {
        guard let session else { return }
        let msg = WireMessage.lobby(players: session.players, config: session.config, status: phaseString(session.phase))
        for peer in peers { peer.send(msg) }
    }

    private func broadcast(_ msg: WireMessage) {
        for peer in peers { peer.send(msg) }
    }

    private func phaseString(_ phase: NetSessionPhase) -> String {
        switch phase {
        case .menu: return "menu"
        case .hostLobby, .browsing, .clientLobby: return "lobby"
        case .countdown: return "starting"
        case .playing: return "playing"
        case .roundResults, .finalResults: return "results"
        }
    }
}

// MARK: - Client

@MainActor
final class ClientDriver: NetSessionDriver {

    private weak var session: MultiplayerSession?
    private var browser: BrowserService?
    private var endpoints: [String: NWEndpoint] = [:]
    private var peer: PeerConnection?

    init(session: MultiplayerSession) {
        self.session = session
    }

    func bootstrap() {
        guard let session else { return }
        session.phase = .browsing
        session.discoveredHosts = []
        let svc = BrowserService()
        svc.onChange = { [weak self] hosts, eps in
            self?.session?.discoveredHosts = hosts
            self?.endpoints = eps
        }
        svc.start()
        browser = svc
    }

    func connect(to host: DiscoveredHost) {
        guard let endpoint = endpoints[host.id] else { return }
        browser?.stop()
        browser = nil

        let peer = PeerConnection(endpoint: endpoint)
        self.peer = peer
        peer.onReady = { [weak self] in
            guard let self, let session = self.session else { return }
            peer.send(.hello(name: session.localPlayerName, playerID: session.localPlayerID))
            session.phase = .clientLobby
        }
        peer.onMessage = { [weak self] msg in
            self?.handleHostMessage(msg)
        }
        peer.onClosed = { [weak self] error in
            guard let session = self?.session else { return }
            #if DEBUG
            NSLog("[ClientDriver] connection closed, error: \(String(describing: error)), phase: \(session.phase)")
            #endif
            let wasConnected = session.phase != .menu
            session.resetForMenu()
            if wasConnected {
                let fallback = LanguageManager.localized("error.disconnected", value: "Connection to host lost.")
                let msg = error?.localizedDescription ?? fallback
                NotificationCenter.default.post(
                    name: .networkDisconnected,
                    object: nil,
                    userInfo: ["message": msg]
                )
            }
        }
        peer.start()
    }

    private func handleHostMessage(_ msg: WireMessage) {
        guard let session else {
            #if DEBUG
            NSLog("[ClientDriver] session is nil, dropping message")
            #endif
            return
        }
        #if DEBUG
        NSLog("[ClientDriver] received message: \(msg)")
        #endif
        switch msg {
        case .youAre(_, let isAdmin):
            session.isAdmin = isAdmin

        case .lobby(let players, let config, _):
            session.players = players
            session.config = config

        case .startCountdown(let seconds):
            session.countdownSeconds = seconds
            if seconds > 0 {
                session.phase = .countdown
                SoundPlayer.shared.play(.tick)
            }

        case .round(let round, let total, let target, let bitsCount, let deadlineEpoch):
            session.currentRound = round
            session.totalRounds = total
            session.currentTarget = target
            session.currentBitsCount = bitsCount
            session.bits = Array(repeating: false, count: bitsCount)
            session.clicks = 0
            session.hasFinishedRound = false
            session.lastSolveTime = 0
            session.isResolving = false
            session.deadline = Date(timeIntervalSince1970: deadlineEpoch)
            session.roundStartTime = Date()
            session.phase = .playing
            SoundPlayer.shared.play(.start)

        case .roundResults(let round, let total, let target, let bitsCount, let scores):
            let result = NetRoundResult(round: round, total: total, target: target, bitsCount: bitsCount, scores: scores)
            if let existing = session.roundResults.firstIndex(where: { $0.round == round }) {
                session.roundResults[existing] = result
            } else {
                session.roundResults.append(result)
            }
            session.deadline = nil
            session.phase = .roundResults

        case .gameOver(let standings):
            session.finalStandings = standings
            session.phase = .finalResults
            SoundPlayer.shared.play(.finish)

        case .kick(let pid):
            if pid == session.localPlayerID {
                let msg = LanguageManager.localized("error.kicked", value: "You were removed by the host.")
                session.resetForMenu()
                NotificationCenter.default.post(
                    name: .networkDisconnected,
                    object: nil,
                    userInfo: ["message": msg]
                )
            }

        case .error(let m):
            session.errorMessage = m
            SoundPlayer.shared.play(.error)

        default:
            break
        }
    }

    func reportFinished(round: Int, time: Double, clicks: Int) {
        peer?.send(.finished(round: round, time: time, clicks: clicks))
    }

    func leave() {
        browser?.stop()
        browser = nil
        peer?.close()
        peer = nil
    }
}
