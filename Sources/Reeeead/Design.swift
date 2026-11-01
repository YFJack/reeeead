import SwiftUI

enum Ink {
    static let paper = Color(hex: 0xFAF9F6)
    static let card = Color.white
    static let dark = Color(hex: 0x252523)
    static let muted = Color(hex: 0x777772)
    static let faint = Color(hex: 0xE9E8E3)
    static let field = Color(hex: 0xF0EFEB)
    static let accent = Color(hex: 0x7568C7)
}
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}
struct ReaderMark: View {
    var body: some View {
        Canvas { c, s in
            for layer in 0..<3 {
                for rect in PixelMark.rectangles(in: CGRect(origin: .zero, size: s), layer: layer) {
                    c.fill(Path(rect), with: .color(Ink.dark.opacity(PixelMark.shades[layer])), style: FillStyle(antialiased: false))
                }
            }
        }.accessibilityHidden(true)
    }
}
struct ReaderWordmark: View {
    var width: CGFloat = 166
    var body: some View {
        Text("Reeeead")
            .font(.custom(Brand.fontName, size: width * 0.205))
            .tracking(-0.9)
            .fixedSize()
            .accessibilityLabel("Reeeead")
    }
}
struct ReaderButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 17).padding(.vertical, 10)
            .foregroundStyle(primary ? Color.white : Ink.dark)
            .background(primary ? Ink.dark : Ink.field, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.38)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isPressed)
    }
}
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Ink.dark).padding(.horizontal, 9).padding(.vertical, 5)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.faint))
    }
}
struct SettingGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Ink.muted)
            content
        }
    }
}
struct QuietField: ViewModifier {
    func body(content: Content) -> some View {
        content.textFieldStyle(.plain).font(.system(size: 13)).padding(11)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Ink.faint))
    }
}
