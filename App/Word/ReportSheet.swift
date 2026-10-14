import KelimeCore
import KelimeUI
import MessageUI
import SwiftUI

/// "Hata bildir": pick a reason, then compose an email with the card id prefilled.
struct ReportSheet: View {
    enum Reason: String, CaseIterable, Identifiable {
        case meaning = "Anlam yanlış"
        case sentence = "Cümle yanlış"
        case translation = "Çeviri doğal değil"
        case other = "Diğer"
        var id: String { rawValue }
    }

    let card: Card
    /// Called with true once the report was handed to Mail.
    let done: (Bool) -> Void

    @Environment(\.openURL) private var openURL
    @State private var composing: Reason?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ne yanlış?")
                .font(KelimeFont.ui(20, weight: .bold, relativeTo: .title3))
                .padding(.bottom, 6)
            ForEach(Reason.allCases) { reason in
                Button {
                    send(reason)
                } label: {
                    Text(reason.rawValue)
                        .font(KelimeFont.ui(15, relativeTo: .body))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .background(Palette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.ignoresSafeArea())
        .sheet(item: $composing) { reason in
            MailComposer(subject: subject(reason), body: body(reason)) { sent in
                composing = nil
                done(sent)
            }
            .ignoresSafeArea()
        }
    }

    private func send(_ reason: Reason) {
        if MFMailComposeViewController.canSendMail() {
            composing = reason
        } else {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = AppConfig.reportEmail
            components.queryItems = [
                URLQueryItem(name: "subject", value: subject(reason)),
                URLQueryItem(name: "body", value: body(reason)),
            ]
            if let url = components.url {
                openURL(url) { accepted in done(accepted) }
            } else {
                done(false)
            }
        }
    }

    private func subject(_ reason: Reason) -> String {
        "Hata bildirimi: \(card.word) (\(reason.rawValue))"
    }

    private func body(_ reason: Reason) -> String {
        """
        Kart: \(card.id)
        Sorun: \(reason.rawValue)

        Açıklama:

        """
    }
}

/// `MFMailComposeViewController` wrapper. Reports whether the mail was sent or saved.
struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let finished: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([AppConfig.reportEmail])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let finished: (Bool) -> Void

        init(finished: @escaping (Bool) -> Void) {
            self.finished = finished
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            finished(result == .sent || result == .saved)
        }
    }
}
