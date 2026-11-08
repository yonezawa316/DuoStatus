import AppKit

enum PowerChange {
    case connected, disconnected

    static func between(_ previous: BatterySnapshot, _ next: BatterySnapshot) -> PowerChange? {
        guard let before = previous.isConnectedToPower,
              let after = next.isConnectedToPower, before != after else { return nil }
        return after ? .connected : .disconnected
    }
}

@MainActor
final class PowerTransitionController: NSObject {
    var onFrame: (() -> Void)?
    private(set) var change: PowerChange?
    private(set) var networkConnected: Bool?
    private(set) var progress: CGFloat = 1
    private(set) var menuClickProgress: CGFloat?
    private var timer: Timer?
    private var startedAt: TimeInterval = 0
    private var timerGeneration: UInt64 = 0
    private let menuClickDuration: TimeInterval = 0.8
    private var menuClickOrigin: CGFloat = 0
    private var menuClickTarget: CGFloat = 1
    private let reduceMotion: @MainActor () -> Bool

    init(reduceMotion: @escaping @MainActor () -> Bool = {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }) {
        self.reduceMotion = reduceMotion
        super.init()
    }

    func show(_ change: PowerChange) {
        stop()
        self.change = change
        begin()
    }

    func showNetworkConnection(_ connected: Bool) {
        // External power feedback takes priority when both events arrive together.
        guard change == nil else { return }
        stop()
        networkConnected = connected
        begin()
    }

    func showMenuClick() {
        showMenuFeedback(toward: 1)
    }

    func showMenuClose() {
        showMenuFeedback(toward: 0)
    }

    private func showMenuFeedback(toward target: CGFloat) {
        // State-change feedback has priority over decorative menu feedback.
        guard change == nil, networkConnected == nil else { return }
        guard !reduceMotion() else {
            cancelMenuClick()
            return
        }
        // Repeating the same direction must not extend or restart its timer.
        if menuClickProgress != nil, menuClickTarget == target { return }
        let origin = menuClickProgress ?? (target == 1 ? 0 : 1)
        stop()
        guard origin != target else {
            onFrame?()
            return
        }
        startedAt = ProcessInfo.processInfo.systemUptime
        menuClickOrigin = origin
        menuClickTarget = target
        menuClickProgress = origin
        let generation = timerGeneration
        onFrame?()
        guard timerGeneration == generation else { return }
        let next = Timer(timeInterval: 1.0 / 60, target: self,
                         selector: #selector(advanceMenuClick), userInfo: nil, repeats: true)
        timer = next
        RunLoop.main.add(next, forMode: .common)
    }

    func cancelMenuClick() {
        guard menuClickProgress != nil else { return }
        stop()
        onFrame?()
    }

    private func begin() {
        startedAt = ProcessInfo.processInfo.systemUptime
        progress = reduceMotion() ? 1 : 0
        let generation = timerGeneration
        onFrame?()
        guard timerGeneration == generation else { return }
        if progress == 1 {
            scheduleRestore(after: 3)
        } else {
            let next = Timer(timeInterval: 0.1, target: self, selector: #selector(advance), userInfo: nil, repeats: true)
            timer = next
            RunLoop.main.add(next, forMode: .common)
        }
    }

    func stop() {
        timerGeneration &+= 1
        timer?.invalidate()
        timer = nil
        change = nil
        networkConnected = nil
        menuClickProgress = nil
        menuClickOrigin = 0
        menuClickTarget = 1
        progress = 1
    }

    @objc private func advance() {
        let generation = timerGeneration
        progress = min(1, CGFloat(ProcessInfo.processInfo.systemUptime - startedAt))
        onFrame?()
        guard timerGeneration == generation else { return }
        if progress >= 1 {
            timer?.invalidate()
            timer = nil
            scheduleRestore(after: 2)
        }
    }

    @objc private func advanceMenuClick() {
        guard menuClickProgress != nil else { return }
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        let travelled = CGFloat(elapsed / menuClickDuration)
        let remaining = abs(menuClickTarget - menuClickOrigin)
        if travelled >= remaining {
            // The restoring frame has no transform; do not enter the power hold.
            restore()
        } else {
            let direction: CGFloat = menuClickTarget > menuClickOrigin ? 1 : -1
            menuClickProgress = menuClickOrigin + direction * travelled
            onFrame?()
        }
    }

    private func scheduleRestore(after seconds: TimeInterval) {
        let next = Timer(timeInterval: seconds, target: self, selector: #selector(restore), userInfo: nil, repeats: false)
        timer = next
        RunLoop.main.add(next, forMode: .common)
    }

    @objc private func restore() {
        stop()
        onFrame?()
    }
}
