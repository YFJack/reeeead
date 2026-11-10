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
    static let size = CGSize(width: 156, height: 62)
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
    var body: some View {
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
        }.padding(5).foregroundStyle(.primary)
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
