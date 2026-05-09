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

    var body: some View {
        VStack(spacing: 28) {
            Wordmark()
                .padding(.top, 36)

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
    var body: some View {
        VStack(spacing: 12) {
            Text(verbatim: "OCTANT")
                .font(.system(size: 56, weight: .black, design: .monospaced))
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
                    .frame(width: 24, height: 2)
                Text("binary speed trainer")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.accent.opacity(0.85))
                Rectangle()
                    .fill(Color.accent)
                    .frame(width: 24, height: 2)
            }
        }
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
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .tvFocusRing(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}
