import Combine
import Foundation
import Testing
@testable import PoindexterCore

/// Mimics SPUUpdater: automatic downloads are only allowed while automatic checks are on.
@MainActor
private final class MockUpdater: UpdaterControlling {
    var storedChecks: Bool?
    var storedDownloads: Bool?
    var storedInterval: TimeInterval?
    var writes: [String] = []
    var checks = 0
    var lastUpdateCheckDate: Date?
    var canCheckForUpdates = true

    var automaticallyChecksForUpdates: Bool {
        get { storedChecks ?? false }
        set { writes.append("checks"); storedChecks = newValue }
    }
    var automaticallyDownloadsUpdates: Bool {
        get { storedDownloads ?? false }
        set { writes.append("downloads"); storedDownloads = newValue }
    }
    var allowsAutomaticUpdates: Bool { automaticallyChecksForUpdates }
    var updateCheckInterval: TimeInterval {
        get { storedInterval ?? 86_400 }
        set { writes.append("interval"); storedInterval = newValue }
    }
    func checkForUpdates() { checks += 1 }
}

@MainActor
private func makeModel(_ updater: MockUpdater, changes: PassthroughSubject<Void, Never> = .init())
    -> UpdateSettingsModel {
    UpdateSettingsModel(updater: updater, changes: changes)
}

@MainActor @Test func showingSettingsNeverStoresAPreference() {
    let updater = MockUpdater()
    let model = makeModel(updater)
    _ = (model.checksAutomatically, model.downloadsAutomatically, model.canChangeAutomaticDownloads,
         model.interval, model.lastCheck, model.canCheckNow)
    #expect(updater.writes.isEmpty)
    #expect(updater.storedChecks == nil)
}

@MainActor @Test func togglesWriteThroughToTheUpdater() {
    let updater = MockUpdater()
    let model = makeModel(updater)
    model.checksAutomatically = true
    model.downloadsAutomatically = true
    model.interval = .weekly
    #expect(updater.storedChecks == true)
    #expect(updater.storedDownloads == true)
    #expect(updater.storedInterval == 604_800)
    #expect(updater.writes == ["checks", "downloads", "interval"])
}

@MainActor @Test func automaticDownloadsAreOffAndLockedWhileChecksAreOff() {
    let updater = MockUpdater()
    updater.storedDownloads = true
    let model = makeModel(updater)
    #expect(!model.canChangeAutomaticDownloads)
    #expect(!model.downloadsAutomatically)
    model.checksAutomatically = true
    #expect(model.canChangeAutomaticDownloads)
    #expect(model.downloadsAutomatically)
}

@MainActor @Test func checkNowAsksTheUpdaterAndReflectsAvailability() {
    let updater = MockUpdater()
    let model = makeModel(updater)
    model.checkNow()
    #expect(updater.checks == 1)
    updater.canCheckForUpdates = false
    #expect(!model.canCheckNow)
}

@MainActor @Test func updaterChangesRefreshTheViews() {
    let changes = PassthroughSubject<Void, Never>()
    let model = makeModel(MockUpdater(), changes: changes)
    var refreshes = 0
    let observer = model.objectWillChange.sink { refreshes += 1 }
    changes.send()
    model.checksAutomatically = true
    #expect(refreshes == 2)
    observer.cancel()
}

@Test func intervalsSnapToTheNearestChoice() {
    #expect(UpdateCheckInterval(closestTo: 3_600) == .daily)
    #expect(UpdateCheckInterval(closestTo: 86_400) == .daily)
    #expect(UpdateCheckInterval(closestTo: 5 * 86_400) == .weekly)
    #expect(UpdateCheckInterval(closestTo: 90 * 86_400) == .monthly)
    #expect(UpdateCheckInterval.allCases.map(\.title) == ["Daily", "Weekly", "Monthly"])
}
