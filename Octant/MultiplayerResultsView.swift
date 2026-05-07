import SwiftUI

struct RoundResultsView: View {
    @ObservedObject var session: MultiplayerSession
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                BackButton(action: onLeave)
                Spacer()
                Text("ROUND \(session.currentRound) / \(session.totalRounds)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Color.accent)
                Spacer()
                Color.clear.frame(width: 80)
            }

            if let result = session.roundResults.last {
                TargetSummary(target: result.target, bitsCount: result.bitsCount)
                ScoreList(scores: sorted(result.scores), localID: session.localPlayerID)
            }

            Spacer(minLength: 0)

            if session.isAdmin {
                Button { session.nextRound() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: hasMoreRounds ? "arrow.right.circle.fill" : "flag.checkered")
                        Text(hasMoreRounds ? "NEXT ROUND" : "FINISH").tracking(3)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                WaitingForHostBar()
            }
        }
    }

    private var hasMoreRounds: Bool {
        session.currentRound < session.totalRounds
    }

    private func sorted(_ scores: [PlayerScore]) -> [PlayerScore] {
        scores.sorted { lhs, rhs in
            if lhs.solved != rhs.solved { return lhs.solved && !rhs.solved }
            if lhs.time != rhs.time { return lhs.time < rhs.time }
            return lhs.clicks < rhs.clicks
        }
    }
}

struct FinalResultsView: View {
    @ObservedObject var session: MultiplayerSession
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                BackButton(action: onLeave)
                Spacer()
                Color.clear.frame(width: 80)
            }

            VStack(spacing: 10) {
                Text("FINAL")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .tracking(10)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentBright, Color.accent],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.accent.opacity(0.4), radius: 14, y: 2)

                if let winner = session.finalStandings.first {
                    Text("\(winner.playerName) wins!")
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.top, 6)

            StandingsList(standings: session.finalStandings, localID: session.localPlayerID)

            Spacer(minLength: 0)

            Button(action: onLeave) {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                    Text("MAIN MENU").tracking(3)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

private struct TargetSummary: View {
    let target: Int
    let bitsCount: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("TARGET")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
            Text(verbatim: "\(target)")
                .font(.system(size: 56, weight: .black, design: .monospaced))
                .foregroundStyle(Color.accent)
                .monospacedDigit()
            Text(verbatim: binaryString(target, bits: bitsCount))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(2)
        }
        .panel(padding: 18)
    }

    private func binaryString(_ value: Int, bits: Int) -> String {
        guard bits > 0 else { return "" }
        return (0..<bits).reversed().map { (value >> $0) & 1 == 1 ? "1" : "0" }.joined()
    }
}

private struct ScoreList: View {
    let scores: [PlayerScore]
    let localID: UUID

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(verbatim: "#").frame(width: 28, alignment: .leading)
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("TIME").frame(width: 78, alignment: .trailing)
                Text("CLICKS").frame(width: 64, alignment: .trailing)
            }
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(scores.enumerated()), id: \.element.id) { idx, score in
                        ScoreRow(rank: idx + 1, score: score, isLocal: score.playerID == localID)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: 320)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ScoreRow: View {
    let rank: Int
    let score: PlayerScore
    let isLocal: Bool

    var body: some View {
        HStack {
            Text(verbatim: "\(rank)")
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(rank == 1 ? Color.accent : .white.opacity(0.4))
            Text(verbatim: score.playerName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
            if score.solved {
                Text(verbatim: String(format: "%.1fs", score.time))
                    .frame(width: 78, alignment: .trailing)
                    .foregroundStyle(rank == 1 ? Color.accent : .white.opacity(0.85))
                Text(verbatim: "\(score.clicks)")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text(verbatim: "—")
                    .frame(width: 78, alignment: .trailing)
                    .foregroundStyle(.white.opacity(0.35))
                Text(verbatim: "—")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .font(.system(.body, design: .monospaced).weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isLocal ? Color.accentDim.opacity(0.35) : Color.surface2.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isLocal ? Color.accent.opacity(0.4) : .clear, lineWidth: 1)
        )
    }
}

private struct StandingsList: View {
    let standings: [PlayerStanding]
    let localID: UUID

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(verbatim: "#").frame(width: 28, alignment: .leading)
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("WINS").frame(width: 60, alignment: .trailing)
                Text("TIME").frame(width: 78, alignment: .trailing)
                Text("CLICKS").frame(width: 64, alignment: .trailing)
            }
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { idx, s in
                        StandingRow(rank: idx + 1, standing: s, isLocal: s.playerID == localID)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: 360)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct StandingRow: View {
    let rank: Int
    let standing: PlayerStanding
    let isLocal: Bool

    var body: some View {
        HStack {
            Text(verbatim: "\(rank)")
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(rank == 1 ? Color.accent : .white.opacity(0.4))
            HStack(spacing: 6) {
                if rank == 1 {
                    Image(systemName: "crown.fill").foregroundStyle(Color.accent).font(.caption)
                }
                Text(verbatim: standing.playerName)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "\(standing.roundsSolved)")
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.85))
            Text(verbatim: String(format: "%.1fs", standing.totalTime))
                .frame(width: 78, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.85))
            Text(verbatim: "\(standing.totalClicks)")
                .frame(width: 64, alignment: .trailing)
                .foregroundStyle(.white.opacity(0.85))
        }
        .font(.system(.body, design: .monospaced).weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isLocal ? Color.accentDim.opacity(0.35) : Color.surface2.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isLocal ? Color.accent.opacity(0.4) : .clear, lineWidth: 1)
        )
    }
}

private struct WaitingForHostBar: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(Color.accent)
            Text("Waiting for host…")
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
