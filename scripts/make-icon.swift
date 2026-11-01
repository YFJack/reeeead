import AppKit

// Deterministic pixel mark, separate from the generated landscape illustration.
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let unit = CGFloat(size) / 32
    NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.87, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: unit, y: unit, width: CGFloat(size) - 2 * unit, height: CGFloat(size) - 2 * unit), xRadius: 6 * unit, yRadius: 6 * unit).fill()
    NSGraphicsContext.current?.shouldAntialias = false
    let rows = ["0000000000000000", "0111110011111100", "1100011100000110", "1000001000000010", "1011101011110010", "1000001000000010", "1011101011110010", "1000001000000010", "1011101011000010", "1000001000000010", "1100011100000110", "0111110011111100", "0000000000000000"]
    NSColor(calibratedRed: 0.14, green: 0.29, blue: 0.21, alpha: 1).setFill()
    for (y, row) in rows.enumerated() { for (x, p) in row.enumerated() where p == "1" { NSRect(x: CGFloat(x + 8) * unit, y: CGFloat(22 - y) * unit, width: unit, height: unit).fill() } }
    NSColor(calibratedRed: 0.76, green: 0.36, blue: 0.19, alpha: 1).setFill()
    NSRect(x: 21 * unit, y: 20 * unit, width: 2 * unit, height: 6 * unit).fill()
    NSRect(x: 8 * unit, y: 7 * unit, width: 16 * unit, height: unit).fill()
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size/2)x\(size/2)@2x.png")) }
}
