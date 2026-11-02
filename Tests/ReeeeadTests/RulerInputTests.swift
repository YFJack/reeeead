import XCTest
import AppKit
@testable import Reeeead

final class RulerInputTests: XCTestCase {
    @MainActor func testTransparentPlacementAreaReceivesWindowHitTesting() throws {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main)
        let frame = NSRect(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY, width: 240, height: 160)
        let panel = RulerPanel(screenFrame: frame)
        XCTAssertFalse(panel.isMovable)
        XCTAssertFalse(panel.canBecomeKey)
        let canvas = RulerCanvas(frame: NSRect(origin: .zero, size: frame.size), preferences: Preferences())
        panel.contentView = canvas
        panel.orderFrontRegardless()
        func flushDrawing() {
            panel.display()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        flushDrawing()
        defer { panel.orderOut(nil); panel.contentView = nil }
        // Away from both the line and hint: this was fully transparent in 0.4.1.
        let point = NSPoint(x: frame.minX + 4, y: frame.minY + 30)
        XCTAssertEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), panel.windowNumber)
        XCTAssertFalse(canvas.mouseDownCanMoveWindow)

        var locks = 0
        canvas.onLock = { locks += 1; panel.ignoresMouseEvents = true }
        func mouse(_ type: NSEvent.EventType, y: CGFloat) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: canvas.convert(NSPoint(x: 4, y: y), to: nil),
                modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        canvas.mouseDown(with: try mouse(.leftMouseDown, y: 30))
        canvas.mouseUp(with: try mouse(.leftMouseUp, y: 30))
        XCTAssertEqual(canvas.geometry.phase, .extending)
        canvas.mouseMoved(with: try mouse(.mouseMoved, y: 145))
        flushDrawing()
        // The undimmed band must still receive the second click.
        XCTAssertEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), panel.windowNumber)
        canvas.mouseDown(with: try mouse(.leftMouseDown, y: 145))
        flushDrawing()
        XCTAssertEqual(locks, 0)
        XCTAssertFalse(panel.ignoresMouseEvents)
        XCTAssertEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), panel.windowNumber)
        canvas.mouseUp(with: try mouse(.leftMouseUp, y: 145))
        flushDrawing()
        XCTAssertEqual(locks, 1)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertNotEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), panel.windowNumber)
        canvas.mouseMoved(with: try mouse(.mouseMoved, y: 150))
        XCTAssertEqual(canvas.geometry.anchor, 30)
        XCTAssertEqual(canvas.geometry.cursor, 145)
    }
}
