import SwiftUI

struct GameView: View {
    @ObservedObject var model: GameModel
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 22) {
            HeaderRow(
                roundCurrent: model.currentRound,
                roundTotal: model.roundsCount,
                elapsed: elapsed
            )

            TargetPanel(
                target: model.targetNumber,
                current: model.currentValue,
                progress: progressFraction
            )

            BitRow(
                bitsCount: model.bitsCount,
                bits: model.bits,
                isResolving: model.isResolving,
                onToggle: { model.toggleBit($0) }
            )

            BinaryReadout(text: model.binaryString)

            Spacer(minLength: 0)
        }
        .onReceive(timer) { _ in
            if model.phase == .playing && !model.isResolving {
                elapsed = Date().timeIntervalSince(model.roundStartTime)
            }
        }
        .onChange(of: model.roundStartTime) { _, _ in
            elapsed = 0
        }
        .sensoryFeedback(.success, trigger: model.winFlash)
        .sensoryFeedback(.selection, trigger: model.clicks)
    }

    private var progressFraction: Double {
        guard model.targetNumber > 0 else { return 0 }
        return min(1.0, Double(model.currentValue) / Double(model.targetNumber))
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
                    bitsRow
                        .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity)
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

struct BitToggleView: View {
    let value: Int
    let isOn: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(verbatim: "\(value)")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
                    .tracking(0.5)

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isOn
                            ? LinearGradient(colors: [Color.accentBright, Color.accent],
                                             startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.surface2, Color.surfaceInset],
                                             startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 56, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isOn
                                        ? Color.white.opacity(0.25)
                                        : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: isOn ? Color.accent.opacity(0.6) : .black.opacity(0.4),
                                radius: isOn ? 12 : 6,
                                y: isOn ? 4 : 2)

                    Text(verbatim: isOn ? "1" : "0")
                        .font(.system(size: 36, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isOn ? Color.black.opacity(0.85) : .white.opacity(0.32))
                }
                .scaleEffect(isOn ? 1.04 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isOn)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1.0)
    }
}
