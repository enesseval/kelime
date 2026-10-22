import KelimeUI
import SwiftUI

/// How often testers use each feature, to decide what Pro should hold. Counted on the device
/// only, in Debug and TestFlight builds (never in App Store builds), and never sent anywhere.
enum UsageCounter: String, CaseIterable {
    case quickReview = "Hızlı Tekrar başlatıldı"
    case puzzle = "Günün Bulmacası açıldı"
    case wordDetail = "Kelime detayı açıldı"
    case units = "Bölümler açıldı"
    case filter = "Tümü filtresi kullanıldı"
    case sort = "Sıralama değiştirildi"
    case examCountdown = "Sınav geri sayımı açıldı"

    private var key: String { "usage." + String(describing: self) }

    static func count(_ counter: UsageCounter) {
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
                Text("Yalnızca bu cihazda, TestFlight ve geliştirme sürümlerinde sayılır; hiçbir yere gönderilmez.")
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
