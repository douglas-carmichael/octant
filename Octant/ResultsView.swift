import SwiftUI

struct ResultsView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("DONE")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .tracking(10)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentBright, Color.accent],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.accent.opacity(0.4), radius: 14, y: 2)

                Text("^[\(model.results.count) rounds completed](inflect: true)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.top, 28)

            HStack(spacing: 14) {
                StatCard(
                    title: "AVG TIME",
                    value: String(format: "%.2fs", model.averageTime),
                    icon: "clock.fill"
                )
                StatCard(
                    title: "AVG CLICKS",
                    value: String(format: "%.1f", model.averageClicks),
                    icon: "hand.tap.fill"
                )
            }

            VStack(spacing: 8) {
                HStack {
                    Text(verbatim: "#")
                        .frame(width: 28, alignment: .leading)
                    Text("TARGET")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("TIME")
                        .frame(width: 78, alignment: .trailing)
                    Text("CLICKS")
                        .frame(width: 64, alignment: .trailing)
                }
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 16)
                .padding(.top, 4)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.results) { r in
                            ResultRow(
                                result: r,
                                isBestTime: r.time == bestTime,
                                isFewestClicks: r.clicks == fewestClicks
                            )
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
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, y: 8)

            Spacer(minLength: 0)

            Button {
                model.playAgain()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("PLAY AGAIN").tracking(3)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var bestTime: Double {
        model.results.map(\.time).min() ?? .infinity
    }

    private var fewestClicks: Int {
        model.results.map(\.clicks).min() ?? Int.max
    }
}

private struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
            }
            .foregroundStyle(.white.opacity(0.5))

            Text(verbatim: value)
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.accent)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }
}

private struct ResultRow: View {
    let result: RoundResult
    let isBestTime: Bool
    let isFewestClicks: Bool

    var body: some View {
        HStack {
            Text(verbatim: "\(result.round)")
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(.white.opacity(0.4))

            Text(verbatim: "\(result.target)")
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)

            HStack(spacing: 5) {
                if isBestTime {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accent)
                }
                Text(verbatim: String(format: "%.1fs", result.time))
                    .foregroundStyle(isBestTime ? Color.accent : .white.opacity(0.85))
            }
            .frame(width: 78, alignment: .trailing)

            HStack(spacing: 5) {
                if isFewestClicks {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accent)
                }
                Text(verbatim: "\(result.clicks)")
                    .foregroundStyle(isFewestClicks ? Color.accent : .white.opacity(0.85))
            }
            .frame(width: 64, alignment: .trailing)
        }
        .font(.system(.body, design: .monospaced).weight(.semibold))
        .monospacedDigit()
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.surface2.opacity(0.5))
        )
    }
}
