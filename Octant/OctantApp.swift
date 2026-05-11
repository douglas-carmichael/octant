import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#endif

extension Notification.Name {
    static let newGameRequested = Notification.Name("NewGameRequested")
    static let playAgainRequested = Notification.Name("PlayAgainRequested")
    static let returnToMenuRequested = Notification.Name("ReturnToMenuRequested")
    static let networkDisconnected = Notification.Name("NetworkDisconnected")
}

#if os(macOS)
struct GamePhaseFocusedKey: FocusedValueKey { typealias Value = GamePhase }
struct AppModeFocusedKey: FocusedValueKey { typealias Value = AppMode }
struct NetSessionPhaseFocusedKey: FocusedValueKey { typealias Value = NetSessionPhase }
extension FocusedValues {
    var gamePhase: GamePhase? {
        get { self[GamePhaseFocusedKey.self] }
        set { self[GamePhaseFocusedKey.self] = newValue }
    }
    var appMode: AppMode? {
        get { self[AppModeFocusedKey.self] }
        set { self[AppModeFocusedKey.self] = newValue }
    }
    var netSessionPhase: NetSessionPhase? {
        get { self[NetSessionPhaseFocusedKey.self] }
        set { self[NetSessionPhaseFocusedKey.self] = newValue }
    }
}

struct GameCommands: Commands {
    @FocusedValue(\.gamePhase) private var gamePhase: GamePhase?
    @FocusedValue(\.appMode) private var appMode: AppMode?
    @AppStorage(UserDefaults.audioMutedKey) private var audioMuted: Bool = false

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Play Again") {
                NotificationCenter.default.post(name: .playAgainRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(appMode != .singlePlayer || gamePhase != .results)

            Button("Main Menu") {
                NotificationCenter.default.post(name: .returnToMenuRequested, object: nil)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(appMode == .mainMenu)
        }
        CommandMenu("Audio") {
            Button(audioMuted ? "Unmute" : "Mute") {
                audioMuted.toggle()
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }
}
#endif

@main
struct OctantApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    private var screenSize: CGSize {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        return CGSize(width: visible.width - 40, height: visible.height - 20)
    }
    #endif

    #if os(tvOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: min(850, screenSize.width),
                       idealWidth: min(900, screenSize.width),
                       minHeight: min(660, screenSize.height),
                       idealHeight: min(780, screenSize.height))
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .windowList) { }
            CommandGroup(replacing: .newItem) {
                Button("New Game…") {
                    NotificationCenter.default.post(name: .newGameRequested, object: nil)
                }
                .keyboardShortcut("n")
            }
            GameCommands()
        }
        #else
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        #if os(tvOS)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                exit(0)
            }
        }
        #endif
        #endif
    }
}
