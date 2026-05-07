import SwiftUI

private func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    if m > 0 && s > 0 { return "\(m)m \(s)s" }
    if m > 0 { return "\(m)m" }
    return "\(seconds)s"
}

struct HostLobbyView: View {
    @ObservedObject var session: MultiplayerSession
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                BackButton(action: onLeave)
                Spacer()
                Text("HOSTING")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Color.accent)
                Spacer()
                Color.clear.frame(width: 80)
            }

            VStack(spacing: 6) {
                Text(verbatim: session.hostServiceName)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                Text("Players on your network can join from their Octant.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .panel(padding: 16)

            ConfigPanel(session: session)

            PlayersPanel(session: session, kickEnabled: true)

            Spacer(minLength: 0)

            Button { session.startGame() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                    Text("START GAME").tracking(3)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(session.players.count < 2)
            .opacity(session.players.count < 2 ? 0.5 : 1)
        }
    }
}

struct BrowseView: View {
    @ObservedObject var session: MultiplayerSession
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                BackButton(action: onLeave)
                Spacer()
                Text("BROWSING")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Color.accent)
                Spacer()
                Color.clear.frame(width: 80)
            }

            VStack(spacing: 6) {
                Text("Looking for hosts…")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.accent)
                    .padding(.top, 4)
            }
            .panel(padding: 18)

            VStack(spacing: 8) {
                if session.discoveredHosts.isEmpty {
                    Text("No hosts found yet.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(28)
                } else {
                    ForEach(session.discoveredHosts) { host in
                        Button { session.joinHost(host) } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(Color.accent)
                                Text(verbatim: host.name)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .panel(padding: 14)

            Spacer(minLength: 0)
        }
    }
}

struct ClientLobbyView: View {
    @ObservedObject var session: MultiplayerSession
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                BackButton(action: onLeave)
                Spacer()
                Text("WAITING")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Color.accent)
                Spacer()
                Color.clear.frame(width: 80)
            }

            VStack(spacing: 6) {
                Text("Connected.")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                Text("Waiting for the host to start.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .panel(padding: 16)

            ConfigSummary(config: session.config)

            PlayersPanel(session: session, kickEnabled: false)

            Spacer(minLength: 0)
        }
    }
}

private struct ConfigPanel: View {
    @ObservedObject var session: MultiplayerSession

    var body: some View {
        VStack(spacing: 14) {
            ConfigRow(
                label: "ROUNDS",
                value: session.config.rounds,
                range: 1...10
            ) { newValue in
                var c = session.config; c.rounds = newValue
                session.updateConfig(c)
            }
            hairline()
            ConfigRow(
                label: "BITS",
                value: session.config.bitsCount,
                range: 2...14
            ) { newValue in
                var c = session.config; c.bitsCount = newValue
                session.updateConfig(c)
            }
            hairline()
            ConfigRow(
                label: "TIME PER ROUND",
                value: session.config.secondsPerRound,
                range: 10...120,
                step: 5,
                format: formatTime
            ) { newValue in
                var c = session.config; c.secondsPerRound = newValue
                session.updateConfig(c)
            }
        }
        .panel()
    }

    private func hairline() -> some View {
        Rectangle().fill(Color.hairline).frame(height: 1)
    }
}

private struct ConfigSummary: View {
    let config: NetGameConfig

    var body: some View {
        HStack(spacing: 14) {
            Stat(label: "ROUNDS", value: "\(config.rounds)")
            Stat(label: "BITS", value: "\(config.bitsCount)")
            Stat(label: "TIME", value: formatTime(config.secondsPerRound))
        }
        .panel(padding: 14)
    }

    private struct Stat: View {
        let label: LocalizedStringKey
        let value: String
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Text(verbatim: value)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.accent)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ConfigRow: View {
    let label: LocalizedStringKey
    let value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var suffix: String = ""
    var format: ((Int) -> String)?
    let onChange: (Int) -> Void

    var displayText: String {
        if let format { return format(value) }
        return "\(value)\(suffix)"
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
                .tracking(1.5)

            Spacer()

            Text(verbatim: displayText)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accent)
                .frame(minWidth: 56, alignment: .center)
                .monospacedDigit()

            HStack(spacing: 8) {
                StepButton(systemName: "minus") {
                    let next = max(range.lowerBound, value - step)
                    if next != value { onChange(next) }
                }
                .opacity(value <= range.lowerBound ? 0.3 : 1)
                .disabled(value <= range.lowerBound)

                StepButton(systemName: "plus") {
                    let next = min(range.upperBound, value + step)
                    if next != value { onChange(next) }
                }
                .opacity(value >= range.upperBound ? 0.3 : 1)
                .disabled(value >= range.upperBound)
            }
        }
    }
}

private struct StepButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.surface2))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct PlayersPanel: View {
    @ObservedObject var session: MultiplayerSession
    let kickEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PLAYERS")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(verbatim: "\(session.players.count) / \(session.config.maxPlayers)")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }

            VStack(spacing: 6) {
                ForEach(session.players) { player in
                    HStack {
                        Image(systemName: player.isHost ? "crown.fill" : "person.fill")
                            .foregroundStyle(player.isHost ? Color.accent : .white.opacity(0.6))
                            .frame(width: 24)
                        Text(verbatim: player.name)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.white)
                        if player.id == session.localPlayerID {
                            Text("you")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.surface2))
                        }
                        Spacer()
                        if kickEnabled && !player.isHost {
                            Button { session.kick(player) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .help("Remove from lobby")
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.surface2.opacity(0.5))
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
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

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("MENU")
            }
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(width: 80, alignment: .leading)
    }
}

struct CountdownView: View {
    @ObservedObject var session: MultiplayerSession

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("STARTING IN")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))
            Text(verbatim: "\(max(0, session.countdownSeconds))")
                .font(.system(size: 140, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentBright, Color.accent],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: Color.accent.opacity(0.5), radius: 24, y: 4)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: session.countdownSeconds)
                .monospacedDigit()
            Spacer()
        }
    }
}
