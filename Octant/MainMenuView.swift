import SwiftUI
import Combine

enum AppMode: Hashable {
    case mainMenu
    case singlePlayer
    case multiplayer
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var mode: AppMode = .mainMenu
    @Published var gameModel = GameModel()
    @Published var session = MultiplayerSession()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        gameModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    func goToMainMenu() {
        gameModel.phase = .setup
        session.resetForMenu()
        mode = .mainMenu
    }

    func startSinglePlayer() {
        gameModel.phase = .setup
        mode = .singlePlayer
    }

    func startHosting() {
        session.startHosting()
        mode = .multiplayer
    }

    func startBrowsing() {
        session.startBrowsing()
        mode = .multiplayer
    }
}

struct MainMenuView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var language = LanguageManager.shared
    @AppStorage(UserDefaults.audioMutedKey) private var audioMuted: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                LanguageButton(language: language)
                Spacer()
                MuteButton(muted: $audioMuted)
            }
            .padding(.top, 6)

            Wordmark()

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                MenuButton(
                    title: "SINGLE PLAYER",
                    subtitle: "Race the clock solo",
                    icon: "person.fill"
                ) { coordinator.startSinglePlayer() }

                MenuButton(
                    title: "HOST GAME",
                    subtitle: "Open a lobby on your network",
                    icon: "antenna.radiowaves.left.and.right"
                ) { coordinator.startHosting() }

                MenuButton(
                    title: "JOIN GAME",
                    subtitle: "Find a host on your network",
                    icon: "magnifyingglass"
                ) { coordinator.startBrowsing() }
            }
            .focusEffectDisabled()
            .padding(.horizontal, 4)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Text("YOUR NAME")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                TextField("", text: $coordinator.session.localPlayerName)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .panel(padding: 16)

            CreditsFooter()
                .padding(.top, 4)
        }
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

private struct LanguageButton: View {
    @ObservedObject var language: LanguageManager

    var body: some View {
        Button {
            language.toggle()
            SoundPlayer.shared.play(.nav)
        } label: {
            HStack(spacing: 8) {
                FlagIcon(language: language.language, height: flagHeight)
                Text(verbatim: language.language.shortName)
                    .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.accent)
            }
            #if os(tvOS)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(Capsule().fill(Color.surface2))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            .tvFocusRing(cornerRadius: 28)
            #else
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule().fill(Color.surface2))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            .tvFocusRing(cornerRadius: 18)
            #endif
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Language")
        .accessibilityValue(language.language.shortName)
    }

    #if os(tvOS)
    private let flagHeight: CGFloat = 24
    private let labelSize: CGFloat = 22
    #else
    private let flagHeight: CGFloat = 15
    private let labelSize: CGFloat = 13
    #endif
}

private struct MuteButton: View {
    @Binding var muted: Bool

    var body: some View {
        Button {
            muted.toggle()
            if !muted { SoundPlayer.shared.play(.nav) }
        } label: {
            Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                #if os(tvOS)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(muted ? .white.opacity(0.5) : Color.accent)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.surface2))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                .tvFocusRing(cornerRadius: 28)
                #else
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(muted ? .white.opacity(0.5) : Color.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.surface2))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                .tvFocusRing(cornerRadius: 18)
                #endif
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(muted ? "Unmute audio" : "Mute audio")
    }
}

private struct MenuButton: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.surface1)
            )
            #if !os(tvOS)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            #endif
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .tvFocusRing(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

// MARK: - Language

/// The languages the UI can be displayed in. Raw values match the `.lproj`
/// language codes bundled with the app.
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case french = "fr"

    /// Locale used to drive SwiftUI's `\.locale` environment value.
    var locale: Locale { Locale(identifier: rawValue) }

    /// Short label shown next to the flag (e.g. "EN" / "FR").
    var shortName: String {
        switch self {
        case .english: return "EN"
        case .french: return "FR"
        }
    }

    /// The language the toggle switches to next.
    var next: AppLanguage {
        switch self {
        case .english: return .french
        case .french: return .english
        }
    }
}

/// Owns the user's chosen UI language and persists it across launches.
///
/// Changing `language` re-publishes so any view observing this object (and the
/// root `ContentView`, which feeds `language.locale` into the environment)
/// re-localizes immediately, without an app restart.
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    static let storageKey = "octant.app.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        language = LanguageManager.resolvedInitialLanguage()
    }

    func toggle() {
        language = language.next
    }

    /// Resolves the starting language: a previously saved choice, otherwise the
    /// system preference (French if the device prefers French, else English).
    private static func resolvedInitialLanguage() -> AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("fr") ? .french : .english
    }

    /// Looks up a localized string in the currently selected language's bundle.
    ///
    /// `Text` uses the `\.locale` environment automatically, but code paths that
    /// resolve strings manually (e.g. networking) must go through here so they
    /// honor the in-app toggle rather than the system language. Safe to call
    /// from any actor.
    nonisolated static func localized(_ key: String, value: String) -> String {
        let code = UserDefaults.standard.string(forKey: storageKey)
            ?? ((Locale.preferredLanguages.first ?? "en").hasPrefix("fr") ? "fr" : "en")
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main.localizedString(forKey: key, value: value, table: nil)
        }
        return bundle.localizedString(forKey: key, value: value, table: nil)
    }
}

// MARK: - Flag icons

/// A small vector flag for the given language. Vector-drawn (rather than emoji)
/// so it renders identically on macOS and tvOS, where flag emoji don't display.
struct FlagIcon: View {
    let language: AppLanguage
    var height: CGFloat = 16

    var body: some View {
        Group {
            switch language {
            case .french: FrenchFlag()
            case .english: UnionJack()
            }
        }
        .frame(width: height * 1.5, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
        )
    }
}

private struct FrenchFlag: View {
    var body: some View {
        HStack(spacing: 0) {
            Color(red: 0x00 / 255, green: 0x55 / 255, blue: 0xA4 / 255)
            Color.white
            Color(red: 0xEF / 255, green: 0x41 / 255, blue: 0x35 / 255)
        }
    }
}

/// A simplified but recognizable Union Jack used to represent English.
private struct UnionJack: View {
    private let blue = Color(red: 0x01 / 255, green: 0x21 / 255, blue: 0x69 / 255)
    private let red = Color(red: 0xC8 / 255, green: 0x10 / 255, blue: 0x2E / 255)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                blue
                // White diagonal saltire.
                diagonals(w: w, h: h).stroke(Color.white, lineWidth: h * 0.30)
                // Red diagonal saltire (thinner, on top).
                diagonals(w: w, h: h).stroke(red, lineWidth: h * 0.12)
                // White upright cross.
                cross(w: w, h: h).stroke(Color.white, lineWidth: h * 0.34)
                // Red upright cross (thinner, on top).
                cross(w: w, h: h).stroke(red, lineWidth: h * 0.20)
            }
            .clipped()
        }
    }

    private func diagonals(w: CGFloat, h: CGFloat) -> Path {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: w, y: h))
            p.move(to: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: 0, y: h))
        }
    }

    private func cross(w: CGFloat, h: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: w / 2, y: 0))
            p.addLine(to: CGPoint(x: w / 2, y: h))
            p.move(to: CGPoint(x: 0, y: h / 2))
            p.addLine(to: CGPoint(x: w, y: h / 2))
        }
    }
}
