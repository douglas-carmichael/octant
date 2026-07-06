import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @ObservedObject private var language = LanguageManager.shared
    @State private var showNewGameConfirm = false
    @State private var pendingErrorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            Group {
                switch coordinator.mode {
                case .mainMenu:
                    MainMenuView(coordinator: coordinator)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .singlePlayer:
                    singlePlayerFlow
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .multiplayer:
                    multiplayerFlow
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 90)
            .padding(.vertical, 40)
            .focusEffectDisabled()
            .hoverEffectDisabled()
            #else
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            #endif
        }
        #if os(macOS)
        .focusedValue(\.appMode, coordinator.mode)
        .focusedValue(\.gamePhase, coordinator.gameModel.phase)
        .focusedValue(\.netSessionPhase, coordinator.session.phase)
        #endif
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: coordinator.mode)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: coordinator.gameModel.phase)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: coordinator.session.phase)
        .onReceive(NotificationCenter.default.publisher(for: .newGameRequested)) { _ in
            switch coordinator.mode {
            case .mainMenu:
                break
            case .singlePlayer:
                if coordinator.gameModel.phase == .playing {
                    showNewGameConfirm = true
                } else {
                    coordinator.gameModel.playAgain()
                }
            case .multiplayer:
                coordinator.goToMainMenu()
            }
        }
        .alert("Start a new game?", isPresented: $showNewGameConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Start New Game") { coordinator.gameModel.playAgain() }
        } message: {
            Text("Your current progress will be lost.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .playAgainRequested)) { _ in
            if coordinator.mode == .singlePlayer {
                coordinator.gameModel.playAgain()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToMenuRequested)) { _ in
            coordinator.goToMainMenu()
        }
        .onReceive(NotificationCenter.default.publisher(for: .networkDisconnected)) { note in
            if let msg = note.userInfo?["message"] as? String, !msg.isEmpty {
                pendingErrorMessage = msg
            }
            coordinator.goToMainMenu()
        }
        .onChange(of: coordinator.session.errorMessage) { _, msg in
            if let msg, !msg.isEmpty {
                pendingErrorMessage = msg
                coordinator.session.errorMessage = nil
            }
        }
        .alert("Network", isPresented: Binding(
            get: { pendingErrorMessage != nil },
            set: { if !$0 { pendingErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { pendingErrorMessage = nil }
        } message: {
            Text(pendingErrorMessage ?? "")
        }
        #if os(macOS)
        .onAppear {
            DispatchQueue.main.async {
                guard let window = NSApplication.shared.windows.first,
                      let visible = window.screen?.visibleFrame else { return }
                let maxHeight = visible.height - 10
                if window.frame.height > maxHeight {
                    var frame = window.frame
                    frame.size.height = maxHeight
                    frame.origin.y = visible.origin.y + (visible.height - maxHeight)
                    window.setFrame(frame, display: true)
                }
            }
        }
        #endif
        // Drive UI localization from the in-app language toggle rather than the
        // system language, so switching EN/FR re-localizes without a restart.
        .environment(\.locale, language.language.locale)
    }

    @ViewBuilder
    private var singlePlayerFlow: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { coordinator.goToMainMenu() }
                Spacer()
            }
            .focusSection()
            .padding(.bottom, 8)

            switch coordinator.gameModel.phase {
            case .setup:
                SetupView(model: coordinator.gameModel)
            case .playing:
                GameView(model: coordinator.gameModel)
            case .results:
                ResultsView(model: coordinator.gameModel)
            }
        }
    }

    @ViewBuilder
    private var multiplayerFlow: some View {
        let leave = { coordinator.goToMainMenu() }
        switch coordinator.session.phase {
        case .menu:
            MainMenuView(coordinator: coordinator)
        case .hostLobby:
            HostLobbyView(session: coordinator.session, onLeave: leave)
        case .browsing:
            BrowseView(session: coordinator.session, onLeave: leave)
        case .clientLobby:
            ClientLobbyView(session: coordinator.session, onLeave: leave)
        case .countdown:
            CountdownView(session: coordinator.session)
        case .playing:
            MultiplayerGameView(session: coordinator.session, onLeave: leave)
        case .roundResults:
            RoundResultsView(session: coordinator.session, onLeave: leave)
        case .finalResults:
            FinalResultsView(session: coordinator.session, onLeave: leave)
        }
    }
}

private struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.surface0Top, Color.surface0],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accent.opacity(0.07))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: 140, y: -200)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 560, height: 840)
}
