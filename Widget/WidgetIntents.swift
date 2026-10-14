import AppIntents
import KelimeCore
import WidgetKit

/// Display mode picked per widget instance; "Uygulama ayarı" follows the app's setting.
enum WidgetModeOption: String, AppEnum {
    case appSetting
    case card
    case sentence
    case selfTest

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Görünüm modu"
    static let caseDisplayRepresentations: [WidgetModeOption: DisplayRepresentation] = [
        .appSetting: "Uygulama ayarı",
        .card: "Kart",
        .sentence: "Cümle",
        .selfTest: "Kendini sına",
    ]

    var mode: WidgetMode? {
        switch self {
        case .appSetting: nil
        case .card: .card
        case .sentence: .sentence
        case .selfTest: .selfTest
        }
    }
}

struct WordWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Kelime widget'ı"
    static let description = IntentDescription("Widget'ın görünüm modunu seç.")

    @Parameter(title: "Görünüm modu", default: .appSetting)
    var mode: WidgetModeOption

    init() {}

    init(mode: WidgetModeOption) {
        self.mode = mode
    }
}

/// "Biliyorum" on the medium widget.
struct MarkKnownIntent: AppIntent {
    static let title: LocalizedStringResource = "Biliyorum"
    static let isDiscoverable = false

    @Parameter(title: "Kelime")
    var cardID: String

    init() {}

    init(cardID: String) {
        self.cardID = cardID
    }

    func perform() async throws -> some IntentResult {
        let db = try AppDatabase.openShared()
        try await db.writer.write { [cardID] db in
            try WidgetActions.markKnown(cardID: cardID, db: db, clock: .system)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// "Zorlanıyorum" on the medium widget.
struct MarkStrugglingIntent: AppIntent {
    static let title: LocalizedStringResource = "Zorlanıyorum"
    static let isDiscoverable = false

    @Parameter(title: "Kelime")
    var cardID: String

    init() {}

    init(cardID: String) {
        self.cardID = cardID
    }

    func perform() async throws -> some IntentResult {
        let db = try AppDatabase.openShared()
        try await db.writer.write { [cardID] db in
            try WidgetActions.markStruggling(cardID: cardID, db: db, clock: .system)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// An option tapped in the medium quiz widget. The answer stays visible until the next slot.
struct AnswerQuizIntent: AppIntent {
    static let title: LocalizedStringResource = "Cevapla"
    static let isDiscoverable = false

    @Parameter(title: "Kelime")
    var cardID: String

    @Parameter(title: "Seçenek")
    var option: String

    init() {}

    init(cardID: String, option: String) {
        self.cardID = cardID
        self.option = option
    }

    func perform() async throws -> some IntentResult {
        let db = try AppDatabase.openShared()
        try await db.writer.write { [cardID, option] db in
            _ = try WidgetActions.answerQuiz(cardID: cardID, option: option, db: db, clock: .system)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
