import Foundation
import Testing

/// The app's Info.plist, read from the source tree (the app target has no test bundle of its own).
private func appInfoPlist() throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Info.plist")
    let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
    return try #require(plist as? [String: Any])
}

/// Sparkle only asks the user about automatic update checks when the Info.plist leaves the choice open.
@Test func infoPlistLeavesAutomaticUpdateChecksToTheUser() throws {
    let plist = try appInfoPlist()
    #expect(plist["SUFeedURL"] != nil)
    #expect(plist["SUEnableAutomaticChecks"] == nil)
    #expect(plist["SUAllowsAutomaticUpdates"] as? Bool != false)
}
