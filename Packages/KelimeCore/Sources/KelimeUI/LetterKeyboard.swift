import SwiftUI

/// Custom English A–Z keyboard with backspace, used by Quick Review and the crossword.
///
/// Never use the system keyboard for answers: with a Turkish locale it turns "i" into "İ".
public struct LetterKeyboard: View {
    public static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

    let keyHeight: CGFloat
    let onLetter: (Character) -> Void
    let onDelete: () -> Void

    /// `keyHeight` 44 fits Quick Review; the crossword has room for taller keys.
    public init(keyHeight: CGFloat = 44, onLetter: @escaping (Character) -> Void, onDelete: @escaping () -> Void) {
        self.keyHeight = keyHeight
        self.onLetter = onLetter
        self.onDelete = onDelete
    }

    public var body: some View {
        GeometryReader { proxy in
            // 10 keys + 9 gaps fill the width of the top row.
            let gap: CGFloat = 5
            let keyWidth = min((proxy.size.width - 8 - gap * 9) / 10, 44)
            VStack(spacing: 9) {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: gap) {
                        ForEach(Array(row), id: \.self) { letter in
                            key(width: keyWidth, label: Text(String(letter)), accessibility: String(letter)) {
                                onLetter(letter)
                            }
                        }
                        if index == 2 {
                            key(width: keyWidth * 1.5, label: Text(Image(systemName: "delete.left")), accessibility: "Sil") {
                                onDelete()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: keyHeight * 3 + 9 * 2)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .padding(.horizontal, 4)
        .background(Palette.surface2)
    }

    private func key(width: CGFloat, label: Text, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(KelimeFont.ui(keyHeight > 44 ? 22 : 19))
                .foregroundStyle(Palette.ink)
                .frame(width: width, height: keyHeight)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(accessibility)
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
