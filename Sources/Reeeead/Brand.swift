import AppKit
import CoreText

enum Brand {
    static let fontName = "OpenDyslexic-Regular"
    static let wordmark: NSImage? = {
        guard let url = resources.url(forResource: "wordmark", withExtension: "png", subdirectory: "Brand") else { return nil }
        return NSImage(contentsOf: url)
    }()
    static var resources: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("Reeeead_Reeeead.bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }
    static func registerFont() {
        guard let url = resources.url(forResource: "OpenDyslexic-Regular", withExtension: "otf", subdirectory: "Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

// Three pixel e's settle into focus. Coordinates use a top-left origin.
enum PixelMark {
    static let rows = ["0111", "1000", "1111", "1000", "0111"]
    static let shades: [CGFloat] = [0.18, 0.42, 1]
    static func rectangles(in bounds: CGRect, layer: Int) -> [CGRect] {
        let unit = min(bounds.width / 8, bounds.height / 7)
        let origin = CGPoint(x: bounds.midX - unit * 4, y: bounds.midY - unit * 3.5)
        return rows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, pixel in
                pixel == "1" ? CGRect(x: origin.x + CGFloat(x + layer * 2) * unit,
                                      y: origin.y + CGFloat(y + layer) * unit,
                                      width: unit, height: unit) : nil
            }
        }
    }
    static func image(size: NSSize, template: Bool = false) -> NSImage {
        let image = NSImage(size: size, flipped: true) { bounds in
            NSGraphicsContext.current?.shouldAntialias = false
            for layer in 0..<3 {
                NSColor(calibratedWhite: template ? 0 : 0.145, alpha: shades[layer]).setFill()
                for rect in rectangles(in: bounds, layer: layer) { rect.fill() }
            }
            return true
        }
        image.isTemplate = template
        return image
    }
}
