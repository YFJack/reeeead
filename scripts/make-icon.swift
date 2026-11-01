import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 100
    NSColor(calibratedRed: 0.97, green: 0.965, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 4 * scale, y: 4 * scale, width: 92 * scale, height: 92 * scale), xRadius: 22 * scale, yRadius: 22 * scale).fill()
    NSGraphicsContext.current?.shouldAntialias = false
    let rows = ["0111", "1000", "1111", "1000", "0111"]
    for layer in 0..<3 {
        NSColor(calibratedWhite: 0.145, alpha: [0.18, 0.42, 1.0][layer]).setFill()
        for (y, row) in rows.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "1" {
                NSRect(x: (22 + CGFloat(x + layer * 2) * 7) * scale,
                       y: (74.5 - CGFloat(y + layer + 1) * 7) * scale,
                       width: 7 * scale, height: 7 * scale).fill()
            }
        }
    }
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size/2)x\(size/2)@2x.png")) }
}
