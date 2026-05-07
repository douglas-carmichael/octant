import Foundation
import SwiftUI

struct NetPlayer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isHost: Bool

    init(id: UUID = UUID(), name: String, isHost: Bool = false) {
        self.id = id
        self.name = name
        self.isHost = isHost
    }
}

struct NetGameConfig: Codable, Hashable {
    var rounds: Int = 5
    var bitsCount: Int = 8
    var secondsPerRound: Int = 30
    var maxPlayers: Int = 8
}

struct PlayerScore: Codable, Hashable, Identifiable {
    var id: UUID { playerID }
    let playerID: UUID
    let playerName: String
    let solved: Bool
    let time: Double
    let clicks: Int
}

struct PlayerStanding: Codable, Hashable, Identifiable {
    var id: UUID { playerID }
    let playerID: UUID
    let playerName: String
    let roundsSolved: Int
    let totalTime: Double
    let totalClicks: Int
}

struct NetRoundResult: Identifiable, Hashable {
    let id = UUID()
    let round: Int
    let total: Int
    let target: Int
    let bitsCount: Int
    let scores: [PlayerScore]
}

enum NetSessionPhase: Hashable {
    case menu
    case hostLobby
    case browsing
    case clientLobby
    case countdown
    case playing
    case roundResults
    case finalResults
}

enum NetSessionMode: Hashable {
    case none
    case host
    case client
}

struct DiscoveredHost: Identifiable, Hashable {
    let id: String
    let name: String
}
