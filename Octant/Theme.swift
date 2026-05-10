import SwiftUI

extension Color {
    static let accentBright = Color(red: 0x6E / 255, green: 0xE8 / 255, blue: 0x8E / 255)
    static let accentDim = Color(red: 0x14 / 255, green: 0x6B / 255, blue: 0x2C / 255)

    static let surface0 = Color(red: 0x07 / 255, green: 0x09 / 255, blue: 0x0E / 255)
    static let surface0Top = Color(red: 0x12 / 255, green: 0x16 / 255, blue: 0x1F / 255)
    static let surface1 = Color(red: 0x14 / 255, green: 0x18 / 255, blue: 0x21 / 255)
    static let surface2 = Color(red: 0x1C / 255, green: 0x21 / 255, blue: 0x2C / 255)
    static let surfaceInset = Color(red: 0x05 / 255, green: 0x07 / 255, blue: 0x0B / 255)

    static let hairline = Color.white.opacity(0.06)
}

struct Panel: ViewModifier {
    var padding: CGFloat = 22
    var cornerRadius: CGFloat = 16

    #if os(tvOS)
    private let borderWidth: CGFloat = 0.5
    #else
    private let borderWidth: CGFloat = 1
    #endif

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }
}

extension View {
    func panel(padding: CGFloat = 22, cornerRadius: CGFloat = 16) -> some View {
        modifier(Panel(padding: padding, cornerRadius: cornerRadius))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    @State private var pulsing = false
    #endif

    var body: some View {
        configuration.label
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color.accent, Color.accentDim]
                                : [Color.accentBright, Color.accent],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.accent.opacity(configuration.isPressed ? 0.15 : 0.4),
                    radius: configuration.isPressed ? 6 : 16,
                    y: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8),
                       value: configuration.isPressed)
            #if os(tvOS)
            .scaleEffect(pulsing ? 1.03 : 1.0)
            .shadow(color: Color.accent.opacity(pulsing ? 0.6 : 0), radius: 20)
            .animation(
                pulsing
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.3),
                value: pulsing
            )
            .onChange(of: isFocused) { _, focused in
                pulsing = focused
            }
            #endif
    }
}

#if os(tvOS)
struct TVFocusRing: ViewModifier {
    var cornerRadius: CGFloat = 12
    @Environment(\.isFocused) private var isFocused
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: Color.accent.opacity(pulsing ? 0.7 : 0), radius: pulsing ? 12 : 0)
            .animation(
                pulsing
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.3),
                value: pulsing
            )
            .onChange(of: isFocused) { _, focused in
                pulsing = focused
            }
    }
}

extension View {
    func tvFocusRing(cornerRadius: CGFloat = 12) -> some View {
        modifier(TVFocusRing(cornerRadius: cornerRadius))
    }
}
#else
extension View {
    func tvFocusRing(cornerRadius: CGFloat = 12) -> some View { self }
}
#endif

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .foregroundStyle(Color.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accent.opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8),
                       value: configuration.isPressed)
    }
}
