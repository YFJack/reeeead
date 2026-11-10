import AppKit
import SwiftUI

enum FocusCue: String, CaseIterable, Identifiable {
    case glass = "Glass", ping = "Ping", pop = "Pop", submarine = "Submarine", silent = "silent"
    var id: String { rawValue }
    var title: String { self == .silent ? L("静音") : rawValue }
}

enum FocusSoundPlayer {
    private static var current: NSSound?
    static func play(_ cue: FocusCue) {
        current?.stop()
        guard cue != .silent else { current = nil; return }
        current = NSSound(named: NSSound.Name(cue.rawValue))
        current?.volume = 0.65
        current?.play()
    }
}

enum FocusEnergy {
    static let arrival = 1.45
    static let duration = 2.3
    static let count = 40
    static let origin = CGPoint(x: 132, y: 35)
    static func position(index: Int, elapsed: Double, destination: CGPoint) -> CGPoint {
        let angle = Double(index) * 2.39996323
        let radius = 14 + Double((index * 17) % 21)
        let burst = CGPoint(x: origin.x + cos(angle) * radius, y: origin.y + sin(angle) * radius)
        if elapsed < 0.38 {
            let t = max(0, min(1, elapsed / 0.38))
            let ease = 1 - pow(1 - t, 3)
            return CGPoint(x: origin.x + (burst.x-origin.x)*ease, y: origin.y + (burst.y-origin.y)*ease)
        }
        let delay = Double(index % 5) * 0.025
        let t = max(0, min(1, (elapsed - 0.38 - delay) / (arrival - 0.38 - delay)))
        let eased = t*t*(3-2*t)
        let bend = CGPoint(x: 30 + Double((index * 23) % 130), y: 65 + Double(index % 7) * 8)
        let u = 1-eased
        return CGPoint(x: u*u*burst.x + 2*u*eased*bend.x + eased*eased*destination.x,
                       y: u*u*burst.y + 2*u*eased*bend.y + eased*eased*destination.y)
    }
}

struct FocusCelebrationOverlay: View {
    let startedAt: Date?
    let completed: Int
    let goal: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: startedAt == nil || reduceMotion)) { timeline in
            Canvas { context, _ in
                let elapsed = startedAt.map { timeline.date.timeIntervalSince($0) } ?? 10
                let animate = !reduceMotion && elapsed >= 0 && elapsed < FocusEnergy.duration
                let target = min(goal - 1, max(0, completed - 1))
                func point(_ index: Int) -> CGPoint {
                    let columns = goal <= 10 ? 5 : 10
                    return CGPoint(x: 20 + Double(index % columns) * (columns == 5 ? 30 : 15), y: 116 + Double(index / columns) * 18)
                }
                let destination = point(target)
                let green = Color(red: 0.25, green: 1, blue: 0.53)
                for index in 0..<goal {
                    let justLit = index == target && animate
                    let lit = index < completed && (!justLit || elapsed >= FocusEnergy.arrival)
                    let impact = max(0, min(1, (elapsed - FocusEnergy.arrival) / 0.7))
                    let radius = 3.3 + (justLit ? sin(impact * .pi) * 3 : 0)
                    let center = point(index)
                    var dot = context
                    if lit { dot.addFilter(.shadow(color: green.opacity(0.6), radius: 5)) }
                    dot.fill(Path(ellipseIn: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2)), with: .color(lit ? green : .primary.opacity(0.14)))
                }
                guard animate else { return }
                var energy = context
                energy.blendMode = .plusLighter
                energy.addFilter(.shadow(color: green.opacity(0.85), radius: 4))
                if elapsed < 0.5 {
                    let t = elapsed / 0.5
                    let radius = 5 + 30*t
                    energy.stroke(Path(ellipseIn: CGRect(x: FocusEnergy.origin.x-radius, y: FocusEnergy.origin.y-radius, width: radius*2, height: radius*2)), with: .color(green.opacity(1-t)), lineWidth: 2.5*(1-t))
                }
                if elapsed < FocusEnergy.arrival {
                    for index in 0..<FocusEnergy.count {
                        for tail in (0..<4).reversed() {
                            let p = FocusEnergy.position(index: index, elapsed: max(0, elapsed-Double(tail)*0.025), destination: destination)
                            let radius = (index % 4 == 0 ? 2.1 : 1.3) * (1-Double(tail)*0.18)
                            energy.fill(Path(ellipseIn: CGRect(x: p.x-radius, y: p.y-radius, width: radius*2, height: radius*2)), with: .color((index % 5 == 0 ? Color.white : green).opacity(1-Double(tail)*0.22)))
                        }
                    }
                } else {
                    let t = (elapsed-FocusEnergy.arrival)/(FocusEnergy.duration-FocusEnergy.arrival)
                    for ring in 0..<2 {
                        let radius = 4 + t * Double(15 + ring*10)
                        energy.stroke(Path(ellipseIn: CGRect(x: destination.x-radius, y: destination.y-radius, width: radius*2, height: radius*2)), with: .color(green.opacity((1-t)*0.8)), lineWidth: 2*(1-t))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
