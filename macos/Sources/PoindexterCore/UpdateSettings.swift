import Combine
import Foundation

/// How often to check for updates automatically; the choices offered in Settings.
public enum UpdateCheckInterval: TimeInterval, CaseIterable, Identifiable, Sendable {
    case daily = 86_400
    case weekly = 604_800
    case monthly = 2_592_000

    public var id: Self { self }

    public var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    /// The choice nearest to any interval, such as Sparkle's default or a value set elsewhere.
    public init(closestTo seconds: TimeInterval) {
        self = Self.allCases.min { abs($0.rawValue - seconds) < abs($1.rawValue - seconds) } ?? .daily
    }
}

/// What the Updates settings need from the updater. Sparkle's `SPUUpdater` conforms in the app.
@MainActor
public protocol UpdaterControlling: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    /// Whether automatic downloads can be turned on (Sparkle ties this to automatic checks).
    var allowsAutomaticUpdates: Bool { get }
    var updateCheckInterval: TimeInterval { get set }
    var lastUpdateCheckDate: Date? { get }
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

/// Backs the Updates settings and the Check for Updates command.
///
/// Every property reads straight from the updater, and writes only when the user changes a
/// control: Sparkle treats a stored preference as the user's answer, so writing on display
/// would suppress the first-launch permission prompt.
@MainActor
public final class UpdateSettingsModel: ObservableObject {
    private let updater: any UpdaterControlling
    private var subscription: AnyCancellable?

    /// `changes` fires whenever the updater changes state by itself (a check finishing, the
    /// permission prompt being answered) so the views refresh.
    public init(updater: any UpdaterControlling, changes: some Publisher<Void, Never>) {
        self.updater = updater
        subscription = changes.sink { [weak self] in
            MainActor.assumeIsolated { self?.objectWillChange.send() }
        }
    }

    public var checksAutomatically: Bool {
        get { updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    public var canChangeAutomaticDownloads: Bool { updater.allowsAutomaticUpdates }

    public var downloadsAutomatically: Bool {
        get { updater.allowsAutomaticUpdates && updater.automaticallyDownloadsUpdates }
        set {
            objectWillChange.send()
            updater.automaticallyDownloadsUpdates = newValue
        }
    }

    public var interval: UpdateCheckInterval {
        get { UpdateCheckInterval(closestTo: updater.updateCheckInterval) }
        set {
            objectWillChange.send()
            updater.updateCheckInterval = newValue.rawValue
        }
    }

    public var lastCheck: Date? { updater.lastUpdateCheckDate }

    public var canCheckNow: Bool { updater.canCheckForUpdates }

    public func checkNow() { updater.checkForUpdates() }
}
