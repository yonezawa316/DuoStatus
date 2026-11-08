import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let applicationName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? "DuoStatus Release"
    private var statusItem: NSStatusItem?
    private let monitor = BatteryMonitor()
    private let wifiMonitor = WiFiMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let transition = PowerTransitionController()
    private var displayedSnapshot = BatterySnapshot.unavailable
    private var displayedWiFi = WiFiSnapshot.unavailable
    private var displayedMemory: MemorySnapshot?
    private var isMenuOpen = false
    private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var powerModeObserver: NSObjectProtocol?
    private var appearanceObserver: NSKeyValueObservation?
    private var renderedAppearance: NSAppearance.Name?
    private let levelItem = NSMenuItem(title: "电量：不可用", action: nil, keyEquivalent: "")
    private let powerItem = NSMenuItem(title: "电池信息暂不可用", action: nil, keyEquivalent: "")
    private let observerItem = NSMenuItem(title: "自动更新不可用，打开菜单时刷新", action: nil, keyEquivalent: "")
    private let lowPowerItem = NSMenuItem(title: "低电量模式：关闭", action: nil, keyEquivalent: "")
    private let wifiItem = NSMenuItem(title: "Wi-Fi：状态暂不可用", action: nil, keyEquivalent: "")
    private let wifiObserverItem = NSMenuItem(title: "Wi-Fi 自动更新不可用，打开菜单时刷新", action: nil, keyEquivalent: "")
    private let memoryItem = NSMenuItem(title: "内存：暂不可用", action: nil, keyEquivalent: "")
    private let appMemoryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let wiredMemoryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let compressedMemoryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let memoryUpdatedItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(levelItem)
        menu.addItem(powerItem)
        menu.addItem(lowPowerItem)
        menu.addItem(observerItem)
        menu.addItem(wifiItem)
        wifiObserverItem.isHidden = true
        menu.addItem(wifiObserverItem)
        menu.addItem(.separator())
        for memoryRow in [memoryItem, appMemoryItem, wiredMemoryItem, compressedMemoryItem, memoryUpdatedItem] {
            menu.addItem(memoryRow)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "退出 \(applicationName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApplication.shared
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        transition.onFrame = { [weak self] in self?.renderIcon() }
        monitor.onChange = { [weak self] snapshot in self?.update(snapshot) }
        monitor.start()
        if item.button?.image == nil { update(monitor.snapshot) }
        wifiMonitor.onChange = { [weak self] snapshot in self?.updateWiFi(snapshot) }
        wifiMonitor.start()
        memoryMonitor.onUpdate = { [weak self] snapshot in self?.updateMemory(snapshot) }
        memoryMonitor.start()
        powerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshPowerMode() }
        }
        appearanceObserver = item.button?.observe(\.effectiveAppearance, options: [.old, .new]) { [weak self] _, change in
            // AppKit may notify even when the effective appearance is unchanged.
            // Replacing the image in response to every notification causes a redraw loop.
            guard change.oldValue?.name != change.newValue?.name else { return }
            Task { @MainActor [weak self] in self?.refreshAppearance() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        wifiMonitor.stop()
        memoryMonitor.stop()
        transition.stop()
        if let powerModeObserver { NotificationCenter.default.removeObserver(powerModeObserver) }
        powerModeObserver = nil
        appearanceObserver = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        memoryMonitor.setMenuOpen(true)
        refreshPowerMode()
        monitor.start() // Retry if notification registration previously failed.
        monitor.refresh()
        wifiMonitor.start()
        observerItem.isHidden = monitor.isObserving
        transition.showMenuClick()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        memoryMonitor.setMenuOpen(false)
        transition.showMenuClose()
    }

    @objc private func willSleep() {
        memoryMonitor.pause()
        transition.stop()
    }

    @objc private func didWake() {
        transition.stop()
        memoryMonitor.resume()
        refreshPowerMode()
        monitor.start()
        monitor.refresh()
        wifiMonitor.start()
        renderIcon()
    }

    private func update(_ snapshot: BatterySnapshot) {
        let change = PowerChange.between(displayedSnapshot, snapshot)
        displayedSnapshot = snapshot
        if snapshot.isConnectedToPower == nil, transition.change != nil { transition.stop() }
        if let change { transition.show(change) } else { renderIcon() }
        updateDescription()
        levelItem.title = snapshot.percentage.map { "电量：\($0)%" } ?? "电量：不可用"
        powerItem.title = snapshot.statusText
        lowPowerItem.title = lowPowerMode ? "低电量模式：开启" : "低电量模式：关闭"
        observerItem.isHidden = monitor.isObserving
    }

    private func updateWiFi(_ snapshot: WiFiSnapshot) {
        let previous = displayedWiFi
        displayedWiFi = snapshot
        if previous.state != .unavailable, snapshot.state != .unavailable, previous != snapshot {
            transition.showNetworkConnection(snapshot.state == .connected)
        } else {
            if snapshot.state == .unavailable, transition.networkConnected != nil { transition.stop() }
            renderIcon()
        }
        wifiItem.title = snapshot.statusText
        wifiObserverItem.isHidden = wifiMonitor.isObserving
        updateDescription()
    }

    private func updateDescription() {
        let memoryText = displayedMemory.map { "内存估算 \($0.percentage)%" } ?? "内存暂不可用"
        let description = "\(applicationName)，电量 \(displayedSnapshot.percentageText)，\(displayedSnapshot.statusText)；\(displayedWiFi.statusText)；\(memoryText)"
        statusItem?.button?.toolTip = description
        statusItem?.button?.setAccessibilityLabel(description)
    }

    private func renderIcon() {
        guard let button = statusItem?.button else { return }
        renderedAppearance = button.effectiveAppearance.name
        // Menu tracking and timers can draw many frames within an event cycle.
        // Drain temporary AppKit drawing objects after each frame; the button
        // retains the displayed image beyond this pool.
        autoreleasepool {
            button.effectiveAppearance.performAsCurrentDrawingAppearance {
                button.image = DuoStatusIcon.make(
                    displayedSnapshot, powerChange: transition.change,
                    progress: transition.progress, lowPowerMode: lowPowerMode,
                    wifi: displayedWiFi, networkProgress: transition.networkConnected == nil ? nil : transition.progress,
                    memoryPercentage: displayedMemory?.percentage,
                    menuClickProgress: transition.menuClickProgress
                )
            }
        }
    }

    private func refreshAppearance() {
        guard statusItem?.button?.effectiveAppearance.name != renderedAppearance else { return }
        renderIcon()
    }

    private func refreshPowerMode() {
        let enabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard enabled != lowPowerMode else { return }
        lowPowerMode = enabled
        lowPowerItem.title = enabled ? "低电量模式：开启" : "低电量模式：关闭"
        renderIcon()
    }

    private func updateMemory(_ snapshot: MemorySnapshot?) {
        let previousPercentage = displayedMemory?.percentage
        displayedMemory = snapshot
        if previousPercentage != snapshot?.percentage {
            renderIcon()
            updateDescription()
        }
        // No capacity/time formatting or menu updates while the menu is closed.
        guard isMenuOpen else { return }
        for row in [appMemoryItem, wiredMemoryItem, compressedMemoryItem, memoryUpdatedItem] {
            let unavailable = snapshot == nil
            if row.isHidden != unavailable { row.isHidden = unavailable }
        }
        guard let snapshot else {
            setTitle(memoryItem, "内存：暂不可用")
            return
        }
        setTitle(memoryItem, "内存（估算）：\(snapshot.percentage)% · \(gib(snapshot.usedBytes)) / \(gib(snapshot.totalBytes)) GiB")
        setTitle(appMemoryItem, "应用内存：\(gib(snapshot.appBytes)) GiB")
        setTitle(wiredMemoryItem, "联动内存：\(gib(snapshot.wiredBytes)) GiB")
        setTitle(compressedMemoryItem, "压缩内存：\(gib(snapshot.compressedBytes)) GiB")
        var now = time(nil)
        var local = tm()
        if localtime_r(&now, &local) != nil {
            setTitle(memoryUpdatedItem, "更新于 \(twoDigits(Int(local.tm_hour))):\(twoDigits(Int(local.tm_min))):\(twoDigits(Int(local.tm_sec))) · 每秒刷新")
        } else {
            setTitle(memoryUpdatedItem, "刚刚更新 · 每秒刷新")
        }
    }

    private func setTitle(_ item: NSMenuItem, _ title: String) {
        if item.title != title { item.title = title }
    }

    private func gib(_ bytes: UInt64) -> String {
        let hundredths = UInt64((Double(bytes) / 1_073_741_824 * 100).rounded())
        return "\(hundredths / 100).\(twoDigits(Int(hundredths % 100)))"
    }

    private func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : String(value)
    }

}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
