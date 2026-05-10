import SwiftUI

struct SetupView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 28) {
            Wordmark()
                .padding(.top, 36)

            Spacer(minLength: 0)

            VStack(spacing: 20) {
                ParameterRow(
                    label: "ROUNDS",
                    sublabel: "1 – 10",
                    value: $model.roundsCount,
                    range: 1...10
                )
                hairline()
                ParameterRow(
                    label: "BITS",
                    sublabel: "2 – 14",
                    value: $model.bitsCount,
                    range: 2...14
                )
                hairline()
                MaxRow(value: model.maxNumber)
            }
            .panel()
            .focusSection()

            Spacer(minLength: 0)

            Button {
                model.startGame()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                    Text("START").tracking(3)
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            CreditsFooter()
                .padding(.top, 4)
        }
    }

    private func hairline() -> some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
    }
}

private struct Wordmark: View {
    #if os(tvOS)
    private let titleSize: CGFloat = 76
    private let subtitleSize: CGFloat = 16
    private let dashWidth: CGFloat = 32
    #else
    private let titleSize: CGFloat = 56
    private let subtitleSize: CGFloat = 11
    private let dashWidth: CGFloat = 24
    #endif

    var body: some View {
        VStack(spacing: 12) {
            Text(verbatim: "OCTANT")
                .font(.system(size: titleSize, weight: .black, design: .monospaced))
                .tracking(10)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: Color.accent.opacity(0.35), radius: 18, y: 2)

            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.accent)
                    .frame(width: dashWidth, height: 2)
                Text("binary speed trainer")
                    .font(.system(size: subtitleSize, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accent.opacity(0.85))
                Rectangle()
                    .fill(Color.accent)
                    .frame(width: dashWidth, height: 2)
            }
        }
    }
}

private struct ParameterRow: View {
    let label: LocalizedStringKey
    let sublabel: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                Text(verbatim: sublabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Text(verbatim: "\(value)")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accent)
                .frame(minWidth: 48, alignment: .center)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
                .monospacedDigit()

            HStack(spacing: 8) {
                StepButton(systemName: "minus") {
                    if value > range.lowerBound { value -= 1 }
                }
                .opacity(value <= range.lowerBound ? 0.3 : 1)
                .disabled(value <= range.lowerBound)

                StepButton(systemName: "plus") {
                    if value < range.upperBound { value += 1 }
                }
                .opacity(value >= range.upperBound ? 0.3 : 1)
                .disabled(value >= range.upperBound)
            }
        }
    }
}

private struct MaxRow: View {
    let value: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("MAX")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                Text("target value")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Text(verbatim: "\(value)")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accent)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
                .monospacedDigit()
        }
    }
}

private struct StepButton: View {
    let systemName: String
    let action: () -> Void

    #if os(tvOS)
    private let buttonSize: CGFloat = 48
    private let iconSize: CGFloat = 18
    #else
    private let buttonSize: CGFloat = 36
    private let iconSize: CGFloat = 14
    #endif

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle().fill(Color.surface2)
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .tvFocusRing(cornerRadius: buttonSize / 2)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

struct CreditsFooter: View {
    #if os(tvOS)
    private let portRoleLabel: LocalizedStringKey = "tvOS port"
    #else
    private let portRoleLabel: LocalizedStringKey = "macOS port"
    #endif

    var body: some View {
        VStack(spacing: 6) {
            CreditLine(
                role: "Original",
                name: "Amaury Crocquefer",
                githubHandle: "lapatatedouce59",
                email: "amaury@crocque.fr"
            )
            CreditLine(
                role: portRoleLabel,
                name: "Douglas Carmichael",
                githubHandle: "douglas-carmichael",
                email: "dcarmich@dcarmichael.net"
            )
        }
        .padding(.top, 6)
    }
}

private struct CreditLine: View {
    let role: LocalizedStringKey
    let name: String
    let githubHandle: String
    let email: String

    var body: some View {
        HStack(spacing: 8) {
            Text(role)
                .foregroundStyle(.white.opacity(0.32))
                .textCase(.uppercase)
                .tracking(1.5)
                #if os(tvOS)
                .frame(width: 120, alignment: .trailing)
                #else
                .frame(width: 76, alignment: .leading)
                #endif

            Text(verbatim: name)
                .foregroundStyle(.white.opacity(0.55))

            #if !os(tvOS)
            Spacer()

            Link(destination: URL(string: "https://github.com/\(githubHandle)")!) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(Color.accent.opacity(0.7))
            }
            .help("@\(githubHandle)")

            Link(destination: URL(string: "mailto:\(email)")!) {
                Image(systemName: "envelope")
                    .foregroundStyle(Color.accent.opacity(0.7))
            }
            .help(email)
            #endif
        }
        #if os(tvOS)
        .font(.system(size: 16, weight: .medium, design: .monospaced))
        .frame(maxWidth: .infinity)
        #else
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        #endif
        .padding(.horizontal, 4)
    }
}
