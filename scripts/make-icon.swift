import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 100
    NSColor(calibratedRed: 0.97, green: 0.965, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 4 * scale, y: 4 * scale, width: 92 * scale, height: 92 * scale), xRadius: 22 * scale, yRadius: 22 * scale).fill()
    NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.13, alpha: 1).setFill()
    for (index, width) in [34.0, 54.0, 42.0].enumerated() {
        NSBezierPath(roundedRect: NSRect(x: 24 * scale, y: (64 - CGFloat(index) * 17) * scale, width: width * scale, height: 8 * scale), xRadius: 4 * scale, yRadius: 4 * scale).fill()
    }
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: URL(fileURLWithPath: destination + "/icon_\(size/2)x\(size/2)@2x.png")) }
}
