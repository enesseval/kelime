import KelimeUI
import SwiftUI

/// The app's usage events. Each one goes to TelemetryDeck as an anonymous signal (see
/// `Analytics`); Debug and TestFlight builds also count them on the device for Geliştirici ›
/// Kullanım sayaçları.
enum UsageCounter: String, CaseIterable {
    case onboardingDone = "Tanıtım tamamlandı"
    case widgetInstalled = "Widget eklendi (ilk görülüş)"
    case quickReview = "Hızlı Tekrar başlatıldı"
    case puzzle = "Günün Bulmacası açıldı"
    case wordDetail = "Kelime detayı açıldı"
    case units = "Bölümler açıldı"
    case filter = "Tümü filtresi kullanıldı"
    case sort = "Sıralama değiştirildi"
    case examCountdown = "Sınav geri sayımı açıldı"
    case listCreated = "Kendi listesi oluşturuldu"
    case listShared = "Liste paylaşıldı"
    case listImported = "Liste içe aktarıldı"
    case paywallShown = "Pro ekranı açıldı"
    case purchase = "Pro satın alındı"
    case placementTest = "Seviye testi bitti"

    private var key: String { "usage." + String(describing: self) }

    static func count(_ counter: UsageCounter) {
        Analytics.send(counter)
        guard DevTools.isAvailable else { return }
        UserDefaults.standard.set(counter.value + 1, forKey: counter.key)
    }

    var value: Int { UserDefaults.standard.integer(forKey: key) }

    static func reset() {
        for counter in allCases { UserDefaults.standard.removeObject(forKey: counter.key) }
    }
}

/// Geliştirici › Kullanım sayaçları.
struct UsageCountersView: View {
    @State private var version = 0

    var body: some View {
        List {
            Section {
                ForEach(UsageCounter.allCases, id: \.self) { counter in
                    LabeledContent(counter.rawValue, value: "\(counter.value)")
                }
            } footer: {
                Text("Bu sayılar yalnızca bu cihazda, TestFlight ve geliştirme sürümlerinde tutulur. Olaylar ayrıca kimliksiz olarak TelemetryDeck'e gider (geliştirme sürümünden gitmez).")
            }
            Button("Sıfırla", role: .destructive) {
                UsageCounter.reset()
                version += 1
            }
        }
        .id(version)
        .navigationTitle("Kullanım sayaçları")
    }
}
