import SwiftUI

enum Assets {
    static let bundle: Bundle = {
        if let root = Bundle.main.resourceURL,
           let bundle = Bundle(url: root.appendingPathComponent("Luma_Luma.bundle")) { return bundle }
        return Bundle.module
    }()
    static let garden: NSImage = {
        guard let url = bundle.url(forResource: "reading-garden", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return NSImage(size: NSSize(width: 1, height: 1)) }
        return image
    }()
}

enum Ink {
    static let paper = Color(hex: 0xF6F3EB)
    static let sidebar = Color(hex: 0xEDEEE4)
    static let card = Color(hex: 0xFFFEF9)
    static let dark = Color(hex: 0x243E32)
    static let muted = Color(hex: 0x677166)
    static let sage = Color(hex: 0xDEE7D5)
    static let orange = Color(hex: 0xB6532E)
    static let faint = Color(hex: 0xE5E6DA)
}
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}
struct PixelIcon: View {
    var kind: String = "book"
    var color: Color = Ink.dark
    static let patterns: [String: [String]] = [
        "book": ["000000000000", "011110111100", "110011100110", "100001000010", "101101011010", "100001000010", "101101011010", "100001000010", "110011100110", "011110111100", "000001000000", "000000000000"],
        "home": ["000000000000", "000001100000", "000011110000", "000110011000", "001100001100", "011000000110", "001011110100", "001010010100", "001010010100", "001111111100", "000000000000", "000000000000"],
        "voice": ["000000000000", "000001001000", "000011000100", "001111010010", "011001001010", "011001001010", "011001001010", "001111010010", "000011000100", "000001001000", "000000000000", "000000000000"],
        "ruler": ["000000000000", "011111111110", "000000000000", "000000000000", "001111111100", "001000000100", "001111111100", "000000000000", "000000000000", "011111111110", "000000000000", "000000000000"],
        "keys": ["000000000000", "011111111110", "010000000010", "010101010010", "010000000010", "010101010010", "010000000010", "010111110010", "010000000010", "011111111110", "000000000000", "000000000000"],
        "spark": ["000001000000", "000001000000", "000011100000", "000011100000", "001111111000", "111111111110", "001111111000", "000011100000", "000011100000", "000001000000", "000001000000", "000000000000"]
    ]
    var body: some View {
        Canvas { context, size in
            let pattern = Self.patterns[kind] ?? Self.patterns["book"]!
            let unit = min(size.width, size.height) / 12
            for (y, row) in pattern.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "1" {
                    context.fill(Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit)), with: .color(color))
                }
            }
        }.accessibilityHidden(true)
    }
}
struct PixelWord: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array([ ["1000","1000","1000","1000","1111"], ["1001","1001","1001","1001","1111"], ["10001","11011","10101","10001","10001"], ["0110","1001","1111","1001","1001"] ].enumerated()), id: \.offset) { _, rows in
                Canvas { c, _ in
                    for (y, row) in rows.enumerated() { for (x, p) in row.enumerated() where p == "1" { c.fill(Path(CGRect(x: x * 3, y: y * 3, width: 3, height: 3)), with: .color(Ink.dark)) } }
                }.frame(width: CGFloat(rows[0].count * 3), height: 15)
            }
        }.accessibilityLabel("Luma")
    }
}
struct LumaButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .foregroundStyle(primary ? Color.white : Ink.dark)
            .background(primary ? Ink.dark : Ink.sage, in: RoundedRectangle(cornerRadius: 7))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.08)).frame(height: 2).padding(.horizontal, 5) }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(Ink.dark)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Ink.dark.opacity(0.14)))
            .shadow(color: Ink.dark.opacity(0.10), radius: 0, x: 0, y: 2)
    }
}
struct Surface<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: 12))
            .padding(3).background(Ink.faint.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Ink.muted) }
}
struct PageTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: 28, weight: .semibold)).tracking(-0.8).foregroundStyle(Ink.dark)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Ink.muted).lineSpacing(4)
        }.padding(.bottom, 9)
    }
}
