import XCTest
import AppKit
@testable import Reeeead

final class FocusFeedbackTests: XCTestCase {
    func testParticlesBurstThenConvergeExactlyOnProgressDot() {
        let destination = CGPoint(x: 20, y: 116)
        for index in 0..<FocusEnergy.count {
            XCTAssertEqual(FocusEnergy.position(index: index, elapsed: 0, destination: destination), FocusEnergy.origin)
            let burst = FocusEnergy.position(index: index, elapsed: 0.38, destination: destination)
            XCTAssertGreaterThan(hypot(burst.x-FocusEnergy.origin.x, burst.y-FocusEnergy.origin.y), 10)
            XCTAssertEqual(FocusEnergy.position(index: index, elapsed: FocusEnergy.arrival, destination: destination), destination)
            for tick in 0...145 {
                let p = FocusEnergy.position(index: index, elapsed: Double(tick)/100, destination: destination)
                XCTAssertTrue(p.x.isFinite && p.y.isFinite)
                XCTAssertTrue(CGRect(x: 0, y: 0, width: 176, height: 154).contains(p))
            }
        }
    }
    func testSelectableSystemSoundsExistWithoutPlayingThem() {
        for cue in FocusCue.allCases where cue != .silent {
            XCTAssertNotNil(NSSound(named: NSSound.Name(cue.rawValue)))
            XCTAssertEqual(FocusCue(rawValue: cue.rawValue), cue)
        }
    }
}
