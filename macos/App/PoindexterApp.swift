import AppKit
import Sparkle
import SwiftUI

@main
struct PoindexterApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let updater = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        Window("Poindexter", id: "main") {
            ContentView(queue: appDelegate.queue)
        }
        .defaultSize(width: 560, height: 460)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updater.updater)
            }
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

/// Receives PDFs dropped on the Dock icon or opened via Finder's "Open With".
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let queue = ConversionQueue()

    func application(_ application: NSApplication, open urls: [URL]) {
        queue.add(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var model: UpdaterModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        model = UpdaterModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!model.canCheckForUpdates)
    }
}

@MainActor
final class UpdaterModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }
}
