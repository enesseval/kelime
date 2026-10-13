import Foundation

/// Identifiers shared by the app and the widget extension.
///
/// The bundle id prefix also lives in `Config/Shared.xcconfig` (`APP_BUNDLE_ID`), which drives
/// the targets' bundle ids and entitlements. `AppConfigTests` keeps the two in sync.
public enum AppConfig {
    public static let appBundleID = "com.enesseval.kelime"
    public static let widgetBundleID = appBundleID + ".widget"
    public static let appGroupID = "group." + appBundleID

    /// Address used by "Hata bildir". Placeholder until the real support address exists.
    public static let reportEmail = "destek@example.com"

    /// File name of the shared SQLite database inside the App Group container.
    public static let databaseFileName = "kelime.sqlite"

    /// Directory that holds the shared database.
    public static func sharedContainerURL(fileManager: FileManager = .default) throws -> URL {
        guard let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw AppConfigError.appGroupUnavailable(appGroupID)
        }
        return url
    }
}

public enum AppConfigError: Error, CustomStringConvertible {
    case appGroupUnavailable(String)

    public var description: String {
        switch self {
        case .appGroupUnavailable(let id):
            "App Group container \(id) is unavailable. Check both targets' entitlements."
        }
    }
}
