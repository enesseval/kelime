import AppIntents
import KelimeCore
import WidgetKit

/// Display mode picked per widget instance; "Uygulama ayarı" follows the app's setting.
enum WidgetModeOption: String, AppEnum {
    case appSetting
    case card
    case dictionary
    case wordAndSentence
    case sentence
    case selfTest

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Görünüm"
    static let caseDisplayRepresentations: [WidgetModeOption: DisplayRepresentation] = [
        .appSetting: DisplayRepresentation(title: "Uygulamadaki seçim", subtitle: "Ayarlar › Görünüm"),
        .card: DisplayRepresentation(title: "Kart", subtitle: "Kelime, türü ve Türkçe anlamı"),
        .dictionary: DisplayRepresentation(title: "Sözlük", subtitle: "Arka plansız: KELİME (tür) ve anlamı"),
        .wordAndSentence: DisplayRepresentation(title: "Kelime ve cümle", subtitle: "Kelime ve İngilizce örnek cümle"),
        .sentence: DisplayRepresentation(title: "Örnek cümle", subtitle: "İngilizce cümle ve Türkçesi"),
        .selfTest: DisplayRepresentation(title: "Kendini sına", subtitle: "Önce soru, sonra cevap"),
    ]

    var mode: WidgetMode? {
        switch self {
        case .appSetting: nil
        case .card: .card
        case .dictionary: .dictionary
        case .wordAndSentence: .wordAndSentence
        case .sentence: .sentence
        case .selfTest: .selfTest
        }
    }
}

struct WordWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Kilit Kelime widget'ı"
    static let description = IntentDescription("Widget'ın görünüm modunu seç.")

    @Parameter(title: "Görünüm", default: .appSetting)
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
            try WidgetLog.recordTap(kind: .button, source: "home", cardID: cardID, slot: nil, detail: "Biliyorum", db: db, clock: .system)
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
            try WidgetLog.recordTap(kind: .button, source: "home", cardID: cardID, slot: nil, detail: "Zorlanıyorum", db: db, clock: .system)
            try WidgetActions.markStruggling(cardID: cardID, db: db, clock: .system)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// An option tapped in the medium quiz widget. The result stays a minute, then the next question comes.
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
            try WidgetLog.recordTap(kind: .button, source: "quiz", cardID: cardID, slot: nil, detail: "Cevap: \(option)", db: db, clock: .system)
            _ = try WidgetActions.answerQuiz(cardID: cardID, option: option, db: db, clock: .system)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
