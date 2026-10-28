import AppKit
import Combine
import PoindexterCore
import Sparkle
import SwiftUI

@main
struct PoindexterApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let updaterDelegate = UpdaterDelegate()
    private let updater: SPUStandardUpdaterController
    private let updates: UpdateSettingsModel

    init() {
        updater = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: updaterDelegate, userDriverDelegate: nil)
        updates = UpdateSettingsModel(updater: updater.updater, changes: updater.updater.settingsChanges)
    }

    var body: some Scene {
        Window("Poindexter", id: "main") {
            ContentView(queue: appDelegate.queue)
        }
        .defaultSize(width: 560, height: 460)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(model: updates)
            }
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(updates: updates)
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
    @ObservedObject var model: UpdateSettingsModel

    var body: some View {
        Button("Check for Updates…", action: model.checkNow)
            .disabled(!model.canCheckNow)
    }
}

/// Asks about automatic update checks on the first launch instead of Sparkle's default second
/// launch. Sparkle stops asking once the user answers, or changes the setting in Settings.
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool { true }
}

extension SPUUpdater: @retroactive UpdaterControlling {
    /// Fires when any setting or state shown in Settings changes, including from Sparkle itself.
    var settingsChanges: AnyPublisher<Void, Never> {
        Publishers.MergeMany(
            publisher(for: \.automaticallyChecksForUpdates).map { _ in () }.eraseToAnyPublisher(),
            publisher(for: \.automaticallyDownloadsUpdates).map { _ in () }.eraseToAnyPublisher(),
            publisher(for: \.allowsAutomaticUpdates).map { _ in () }.eraseToAnyPublisher(),
            publisher(for: \.updateCheckInterval).map { _ in () }.eraseToAnyPublisher(),
            publisher(for: \.lastUpdateCheckDate).map { _ in () }.eraseToAnyPublisher(),
            publisher(for: \.canCheckForUpdates).map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
