import XCTest
import AppKit
import QuartzCore
@testable import Reeeead

final class FocusSessionTests: XCTestCase {
    func testSharedCycleTransitionsAtExactBoundariesAndRepeats() {
        var clock = FocusCycle()
        XCTAssertEqual(clock.snapshot(at: 100).phase, .idle)
        clock.start(at: 100)
        XCTAssertEqual(clock.snapshot(at: 100).label, "25:00")
        XCTAssertEqual(clock.snapshot(at: 1599.2).label, "00:01")
        XCTAssertEqual(clock.snapshot(at: 1600).phase, .rest)
        XCTAssertEqual(clock.snapshot(at: 1600).label, "05:00")
        XCTAssertEqual(clock.snapshot(at: 1899.2).label, "00:01")
        XCTAssertEqual(clock.snapshot(at: 1900).phase, .focus)
        XCTAssertEqual(clock.snapshot(at: 1900).label, "25:00")
        XCTAssertEqual(clock.snapshot(at: 100 + 1800 * 4 + 1510).phase, .rest)
        XCTAssertEqual(clock.snapshot(at: 100 + 1800 * 4 + 1510).remaining, 290)
        clock.stop()
        XCTAssertEqual(clock.snapshot(at: 99999).phase, .idle)
        clock.start(at: 100000)
        XCTAssertEqual(clock.snapshot(at: 100000).remaining, 1500)
    }
    func testCountdownProgressUsesElapsedTimeRatherThanTickCount() {
        var clock = FocusCycle()
        clock.start(at: 0)
        XCTAssertEqual(clock.snapshot(at: 750).progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(clock.snapshot(at: 1650).progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(clock.snapshot(at: 1800 * 8 + 12).remaining, 1488)
    }
    @MainActor func testOverlappingSelectedWindowsRemainClearAndUnselectedCoverStaysDim() {
        let front = FocusWindowInfo(id: 1, pid: 1, rect: CGRect(x: 10, y: 10, width: 50, height: 50))
        let back = FocusWindowInfo(id: 2, pid: 2, rect: CGRect(x: 30, y: 30, width: 60, height: 60))
        let canvas = WindowFocusCanvas(frame: CGRect(x: 0, y: 0, width: 120, height: 120), opacity: 1)
        canvas.cornerRadius = 0
        canvas.regions = FocusWindowInfo.regions(selected: [1, 2], windows: [front, back])
        XCTAssertFalse(canvas.maskPath().contains(CGPoint(x: 40, y: 40), using: .evenOdd), "Overlapping selected holes must be unioned, not XORed")
        XCTAssertFalse(canvas.maskPath().contains(CGPoint(x: 80, y: 80), using: .evenOdd))
        canvas.regions = FocusWindowInfo.regions(selected: [2], windows: [front, back])
        XCTAssertTrue(canvas.maskPath().contains(CGPoint(x: 40, y: 40), using: .evenOdd), "An unselected window covering a locked one must remain dark")
        XCTAssertFalse(canvas.maskPath().contains(CGPoint(x: 80, y: 80), using: .evenOdd))
        XCTAssertTrue(FocusWindowInfo.regions(selected: [2], windows: [front]).isEmpty, "Off-Space/minimized/closed windows cannot leave stale holes")
    }
    func testLiveWindowMatchRequiresOwnerAndFullGeometry() {
        let rect = CGRect(x: -500, y: 200, width: 400, height: 300)
        let wrongOwner = FocusWindowInfo(id: 1, pid: 99, rect: rect)
        let wrongSize = FocusWindowInfo(id: 2, pid: 7, rect: CGRect(x: -500, y: 200, width: 500, height: 300))
        let target = FocusWindowInfo(id: 3, pid: 7, rect: rect.offsetBy(dx: 0.5, dy: 0.5))
        XCTAssertEqual(FocusWindowInfo.matching(pid: 7, rect: rect, windows: [wrongOwner, wrongSize, target])?.id, 3)
        XCTAssertNil(FocusWindowInfo.matching(pid: 7, rect: rect, windows: [wrongOwner, wrongSize]))
    }
    func testSelectedWindowsKeepIdentityAcrossMovementAndReordering() {
        let original = FocusWindowInfo(id: 1, pid: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        let moved = FocusWindowInfo(id: 1, pid: 1, rect: CGRect(x: 500, y: 300, width: 100, height: 100))
        let other = FocusWindowInfo(id: 2, pid: 2, rect: CGRect(x: 900, y: 300, width: 100, height: 100))
        XCTAssertEqual(FocusWindowInfo.regions(selected: [1], windows: [original]).first?.rect, original.rect)
        let result = FocusWindowInfo.regions(selected: [1], windows: [other, moved])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.rect, moved.rect)
    }
    func testFloatingControlsStayOutsideWindowWhenSpaceExistsAndOnScreenOtherwise() {
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        for window in [CGRect(x: -1200, y: 150, width: 800, height: 500), CGRect(x: -1000, y: 250, width: 1000, height: 500)] {
            let controls = FocusControlsPlacement.frame(window: window, screen: screen)
            XCTAssertTrue(screen.contains(controls))
            XCTAssertFalse(window.intersects(controls))
        }
        XCTAssertTrue(screen.contains(FocusControlsPlacement.frame(window: screen, screen: screen)))
    }
    @MainActor func testRestBreathingOnlyChangesMaskAndStopsCleanly() throws {
        let canvas = WindowFocusCanvas(frame: CGRect(x: 0, y: 0, width: 200, height: 200), opacity: 0.7)
        canvas.cutout = CGRect(x: 30, y: 30, width: 100, height: 100)
        canvas.updateShape()
        let before = canvas.maskPath()
        canvas.setResting(true)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let animation = try XCTUnwrap(canvas.layer?.animation(forKey: "restBreathing") as? CABasicAnimation)
            XCTAssertEqual(animation.keyPath, "fillColor")
            XCTAssertEqual(animation.duration, 4)
            XCTAssertTrue(animation.autoreverses)
        }
        XCTAssertEqual(canvas.maskPath(), before)
        canvas.setResting(false)
        XCTAssertNil(canvas.layer?.animation(forKey: "restBreathing"))
        XCTAssertEqual(try XCTUnwrap((canvas.layer as? CAShapeLayer)?.fillColor).alpha, 0.7, accuracy: 0.001)
    }
}
