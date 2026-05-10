import SwiftUI

struct MultiplayerGameView: View {
    @ObservedObject var session: MultiplayerSession
    let onLeave: () -> Void

    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton(action: onLeave)
                Spacer()
                if let deadline = session.deadline {
                    let remaining = max(0, deadline.timeIntervalSinceNow)
                    Text(verbatim: String(format: "%.0fs left", remaining))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(remaining < 5 ? Color.red.opacity(0.9) : Color.accent)
                        .monospacedDigit()
                }
                Spacer()
                Color.clear.frame(width: 80)
            }
            .focusSection()
            .padding(.bottom, 18)

            VStack(spacing: 18) {
                HeaderRow(
                    roundCurrent: session.currentRound,
                    roundTotal: session.totalRounds,
                    elapsed: elapsed
                )

                TargetPanel(
                    target: session.currentTarget,
                    current: session.currentValue,
                    progress: progressFraction
                )

                if session.hasFinishedRound {
                    FinishedBanner(time: session.lastSolveTime, clicks: session.clicks)
                }

                BitRow(
                    bitsCount: session.currentBitsCount,
                    bits: session.bits,
                    isResolving: session.isResolving || session.hasFinishedRound,
                    onToggle: { session.toggleBit($0) }
                )

                BinaryReadout(text: session.binaryString)

                Spacer(minLength: 0)
            }
            .focusSection()
        }
        .onReceive(timer) { _ in
            if session.phase == .playing && !session.isResolving && !session.hasFinishedRound {
                elapsed = Date().timeIntervalSince(session.roundStartTime)
            }
        }
        .onChange(of: session.roundStartTime) { _, _ in
            elapsed = 0
        }
        .onChange(of: session.currentRound) { _, _ in
            elapsed = 0
        }
        .sensoryFeedback(.success, trigger: session.winFlash)
        .sensoryFeedback(.selection, trigger: session.clicks)
    }

    private var progressFraction: Double {
        guard session.currentTarget > 0 else { return 0 }
        return min(1.0, Double(session.currentValue) / Double(session.currentTarget))
    }
}

private struct HeaderRow: View {
    let roundCurrent: Int
    let roundTotal: Int
    let elapsed: TimeInterval

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROUND")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Text(verbatim: "\(roundCurrent) / \(roundTotal)")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Spacer()

            ProgressDots(current: roundCurrent, total: roundTotal)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("TIME")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Text(verbatim: String(format: "%.1fs", elapsed))
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.accent)
                    .monospacedDigit()
            }
        }
    }
}

private struct TargetPanel: View {
    let target: Int
    let current: Int
    let progress: Double

    private var matched: Bool { current == target }

    var body: some View {
        VStack(spacing: 16) {
            ValueRow(label: "TARGET", value: target, color: .white, big: true)

            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1)

            ValueRow(
                label: "CURRENT",
                value: current,
                color: matched ? Color.accent : .white.opacity(0.85),
                big: true
            )

            ProgressBar(progress: progress, matched: matched)
                .frame(height: 6)
                .padding(.top, 4)
        }
        .panel(padding: 24)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accent, lineWidth: matched ? 2 : 0)
                .shadow(color: Color.accent.opacity(matched ? 0.6 : 0), radius: 12)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: matched)
        )
    }
}

private struct FinishedBanner: View {
    let time: Double
    let clicks: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.accentBright)
            VStack(alignment: .leading, spacing: 3) {
                Text("SOLVED")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Color.accentBright)
                Text(verbatim: String(format: "%.1fs · %d clicks", time, clicks))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("Waiting for others…")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentDim.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accent.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct BitRow: View {
    let bitsCount: Int
    let bits: [Bool]
    let isResolving: Bool
    let onToggle: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("BITS")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))

            ViewThatFits(in: .horizontal) {
                bitsRow
                ScrollView(.horizontal, showsIndicators: false) {
                    bitsRow.padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .focusSection()
        }
    }

    private var bitsRow: some View {
        HStack(spacing: 10) {
            ForEach((0..<bitsCount).reversed(), id: \.self) { i in
                BitToggleView(
                    value: 1 << i,
                    isOn: bits.indices.contains(i) ? bits[i] : false,
                    disabled: isResolving
                ) {
                    onToggle(i)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct BinaryReadout: View {
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Text("BINARY CODE")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            Text(verbatim: text)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .tracking(2)
                .shadow(color: Color.accent.opacity(0.4), radius: 10)
        }
        .panel(padding: 20)
    }
}

private struct ValueRow: View {
    let label: LocalizedStringKey
    let value: Int
    let color: Color
    let big: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(verbatim: "\(value)")
                .font(.system(size: big ? 46 : 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
                .monospacedDigit()
        }
    }
}

private struct ProgressDots: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...max(1, total), id: \.self) { i in
                let isComplete = i < current
                let isCurrent = i == current
                Circle()
                    .fill(isComplete || isCurrent ? Color.accent : Color.white.opacity(0.18))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isCurrent ? 1.4 : 1.0)
                    .shadow(color: isCurrent ? Color.accent.opacity(0.6) : .clear, radius: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: current)
            }
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let matched: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.surfaceInset)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: matched
                                ? [Color.accentBright, Color.accent]
                                : [Color.accentDim, Color.accent],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
            }
        }
    }
}
