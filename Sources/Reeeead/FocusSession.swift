import AppKit
import SwiftUI

struct FocusCycle {
    enum Phase { case idle, focus, rest }
    struct Snapshot: Equatable {
        var phase: Phase = .idle
        var remaining: Int = 25 * 60
        var progress: Double = 1
        var label: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    }
    private(set) var startedAt: TimeInterval?
    mutating func start(at time: TimeInterval) { startedAt = time }
    mutating func stop() { startedAt = nil }
    func completions(at time: TimeInterval) -> Int {
        guard let startedAt, time >= startedAt + 1500 else { return 0 }
        return Int((time - startedAt - 1500) / 1800) + 1
    }
    func snapshot(at time: TimeInterval) -> Snapshot {
        guard let startedAt else { return Snapshot() }
        let elapsed = max(0, time - startedAt).truncatingRemainder(dividingBy: 30 * 60)
        let resting = elapsed >= 25 * 60
        let duration: Double = resting ? 5 * 60 : 25 * 60
        let remaining = resting ? 30 * 60 - elapsed : 25 * 60 - elapsed
        return Snapshot(phase: resting ? .rest : .focus, remaining: Int(ceil(remaining)), progress: remaining / duration)
    }
}

struct FocusRegion: Equatable {
    var rect: CGRect
    var occluders: [CGRect] = []
    func local(to screen: CGRect) -> FocusRegion {
        FocusRegion(rect: rect.offsetBy(dx: -screen.minX, dy: -screen.minY), occluders: occluders.map { $0.offsetBy(dx: -screen.minX, dy: -screen.minY) })
    }
    func visiblePath(radius: CGFloat) -> CGPath {
        let r = min(max(0, radius), min(rect.width, rect.height) / 2)
        var path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        for occluder in occluders where rect.intersects(occluder) {
            path = path.subtracting(CGPath(rect: occluder, transform: nil))
        }
        return path
    }
}

struct FocusWindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let rect: CGRect
    static func visibleWindows(primaryHeight: CGFloat) -> [FocusWindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard (item[kCGWindowLayer as String] as? Int) == 0,
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let id = item[kCGWindowNumber as String] as? UInt32,
                  let pid = item[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = item[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  let converted = WindowFocusGeometry.appKitRect(rect, primaryHeight: primaryHeight) else { return nil }
            return FocusWindowInfo(id: id, pid: pid, rect: converted)
        }
    }
    static func matching(pid: pid_t, rect: CGRect, windows: [FocusWindowInfo]) -> FocusWindowInfo? {
        windows.first {
            $0.pid == pid && abs($0.rect.minX - rect.minX) < 2 && abs($0.rect.minY - rect.minY) < 2
                && abs($0.rect.width - rect.width) < 2 && abs($0.rect.height - rect.height) < 2
        }
    }
    // WindowServer supplies current stacking order and geometry without reading
    // window contents. Higher unselected windows stay dim even over a locked one.
    static func regions(selected: Set<CGWindowID>, windows: [FocusWindowInfo]) -> [FocusRegion] {
        var above: [CGRect] = []
        var result: [FocusRegion] = []
        for window in windows {
            if selected.contains(window.id) { result.append(FocusRegion(rect: window.rect, occluders: above)) }
            above.append(window.rect)
        }
        return result
    }
}

enum FocusControlsPlacement {
    static let size = CGSize(width: 176, height: 154)
    static func frame(window: CGRect, screen: CGRect) -> CGRect {
        let gap: CGFloat = 8
        let candidates = [
            CGRect(x: window.maxX + gap, y: window.maxY - size.height, width: size.width, height: size.height),
            CGRect(x: window.maxX - size.width, y: window.maxY + gap, width: size.width, height: size.height),
            CGRect(x: window.minX - size.width - gap, y: window.maxY - size.height, width: size.width, height: size.height),
            CGRect(x: window.maxX - size.width, y: window.minY - gap - size.height, width: size.width, height: size.height)
        ]
        if let fit = candidates.first(where: { screen.contains($0) }) { return fit }
        // A maximized/full-screen window leaves no outside space; keep controls reachable.
        return CGRect(x: max(screen.minX, screen.maxX - size.width - gap), y: max(screen.minY, screen.maxY - size.height - gap), width: size.width, height: size.height)
    }
}

final class FocusControlsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init() {
        super.init(contentRect: CGRect(origin: .zero, size: FocusControlsPlacement.size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = L("窗口聚焦控制")
        setAccessibilityLabel(L("窗口聚焦控制"))
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        isMovable = false; hidesOnDeactivate = false; isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
}

struct FocusFloatingControls: View {
    @ObservedObject var controller: WindowFocusController
    @State private var hovering = false
    @State private var celebration: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
      VStack(spacing: 8) {
        HStack(spacing: 7) {
            circleButton(controller.locked ? "lock.fill" : "lock.open", label: controller.locked ? L("解锁并跟随当前窗口") : L("锁定高亮窗口"), selected: controller.locked) { controller.toggleLock() }
            circleButton(controller.addingWindow ? "xmark" : "plus", label: controller.addingWindow ? L("取消添加窗口") : L("添加下一个窗口"), selected: controller.addingWindow) { controller.toggleAdding() }
            Button { controller.toggleCycle() } label: {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.7)
                    if controller.cycleState.phase != .idle {
                        Circle().stroke(color.opacity(0.18), lineWidth: 2.5).padding(3)
                        Circle().trim(from: 0, to: controller.cycleState.progress)
                            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90)).padding(3)
                        Text(controller.cycleState.label).font(.system(size: 10, weight: .medium, design: .monospaced)).monospacedDigit()
                    } else {
                        VStack(spacing: 1) { Text("25").font(.system(size: 15, weight: .medium)); Text("Focus").font(.system(size: 8, weight: .medium)) }
                    }
                }.frame(width: 52, height: 52)
            }.buttonStyle(.plain).help(controller.cycleState.phase == .idle ? L("开始 25 分钟专注") : L("停止专注循环"))
                .accessibilityLabel(controller.cycleState.phase == .idle ? L("开始 25 分钟专注") : L("停止专注循环"))
                .accessibilityValue(controller.cycleState.phase == .rest ? L("休息 %@", controller.cycleState.label) : controller.cycleState.label)
        }
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.12)).frame(height: 2)
                Capsule().fill(.primary.opacity(0.45)).frame(width: max(2, geometry.size.width * controller.brightness), height: 2)
                Circle().fill(.white).shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .frame(width: 8, height: 8).offset(x: (geometry.size.width - 8) * controller.brightness)
                    .opacity(hovering ? 1 : 0)
            }.frame(height: 16).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    controller.setBrightness(value.location.x / geometry.size.width)
                }).onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: hovering)
                .accessibilityElement().accessibilityLabel(L("背景亮度"))
                .accessibilityValue("\(Int(controller.brightness * 100))%")
                .accessibilityAdjustableAction { direction in
                    controller.setBrightness(controller.brightness + (direction == .increment ? 0.05 : -0.05))
                }
        }.frame(height: 16).padding(.horizontal, 12)
        HStack {
            Text("\(controller.completedToday) / \(controller.dailyGoal)").monospacedDigit()
            Spacer()
            Menu {
                ForEach(1...20, id: \.self) { count in
                    Button("\(count)") { controller.setDailyGoal(count) }
                }
            } label: { Text(L("每日目标")) }
            .menuStyle(.borderlessButton).fixedSize().help(L("设置每天完成的专注次数"))
        }.font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 12)
        Color.clear.frame(height: 32)
      }.padding(5).foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: celebration == nil)) { timeline in
                Canvas { context, _ in
                    let elapsed = celebration.map { timeline.date.timeIntervalSince($0) } ?? 10
                    let arrival = 0.68
                    let target = min(controller.dailyGoal - 1, max(0, controller.completedToday - 1))
                    func point(_ index: Int) -> CGPoint {
                        let columns = controller.dailyGoal <= 10 ? 5 : 10
                        let spacing: Double = columns == 5 ? 30 : 15
                        return CGPoint(x: 20 + Double(index % columns) * spacing, y: 116 + Double(index / columns) * 18)
                    }
                    let destination = point(target)
                    for index in 0..<controller.dailyGoal {
                        let justLit = index == target && elapsed < 1.7 && !reduceMotion
                        let lit = index < controller.completedToday && (!justLit || elapsed >= arrival)
                        let pop = justLit && elapsed >= arrival ? sin(min(1, (elapsed - arrival) / 0.55) * .pi) * 2 : 0
                        let radius = 3.3 + pop
                        let center = point(index)
                        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        var dotContext = context
                        if lit { dotContext.addFilter(.shadow(color: Color.green.opacity(0.25), radius: 3)) }
                        dotContext.fill(Path(ellipseIn: rect), with: .color(lit ? Color(red: 0.3, green: 0.78, blue: 0.46) : .primary.opacity(0.14)))
                    }
                    if elapsed < arrival && !reduceMotion {
                        for tail in 0..<14 {
                            let t = max(0, min(1, elapsed / arrival - Double(tail) * 0.018))
                            let start = CGPoint(x: 132, y: 35)
                            let x = (1-t)*(1-t)*start.x + 2*(1-t)*t*174 + t*t*destination.x
                            let y = (1-t)*(1-t)*start.y + 2*(1-t)*t*88 + t*t*destination.y
                            let r = 3.5 * (1 - Double(tail) / 18)
                            context.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)), with: .color(.green.opacity(1 - Double(tail)/15)))
                        }
                    }
                    if elapsed >= arrival && elapsed < 1.5 && !reduceMotion {
                        let t = (elapsed - arrival) / 0.82
                        for index in 0..<10 {
                            let angle = Double(index) * .pi * 2 / 10
                            let x = destination.x + cos(angle) * 20 * t
                            let y = destination.y + sin(angle) * 15 * t + 9*t*t
                            let rect = CGRect(x: x, y: y, width: 2, height: index % 2 == 0 ? 4 : 2)
                            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color((index % 3 == 0 ? Color.yellow : Color.green).opacity(1-t)))
                        }
                    }
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .task(id: controller.completionEvent) {
            guard controller.completionEvent > 0 else { return }
            celebration = Date()
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 1.7))
            if !Task.isCancelled { celebration = nil }
        }
    }
    private var color: Color { controller.cycleState.phase == .rest ? Color(red: 0.93, green: 0.3, blue: 0.27) : Color(red: 0.3, green: 0.78, blue: 0.46) }
    private func circleButton(_ symbol: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium)).frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(selected ? Color.white.opacity(0.8) : Color.white.opacity(0.3), lineWidth: selected ? 1.2 : 0.7))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}
