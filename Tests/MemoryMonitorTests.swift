import Foundation

@main
@MainActor
struct MemoryMonitorTests {
    private static var checks = 0
    private static var failures = 0
    private static let trackingMode = RunLoop.Mode("DuoStatus.MemoryMonitorTests.tracking")

    static func main() {
        // Exercise a real non-default common mode without opening or controlling UI.
        // A timer accidentally installed only in .default will fail this test.
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(rawValue: trackingMode.rawValue as CFString))
        checkImmediateUpdatesAndFailure()
        checkTrackingAndClosedFrequency()
        checkRepeatedChangesAndPause()
        checkStopDuringCallbackAndRelease()

        guard failures == 0 else {
            print("内存采样器测试失败：\(failures)/\(checks) 项。")
            exit(1)
        }
        print("通过 \(checks) 项内存采样器检查（真实主 runloop、5 秒/1 秒间隔）。")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    private static func sample() -> MemorySnapshot {
        MemorySnapshot(
            totalBytes: 16 * 1_073_741_824, pageSize: 16_384,
            internalPages: 300_000, purgeablePages: 20_000,
            wiredPages: 100_000, compressedPages: 40_000
        )!
    }

    private static func pump(for seconds: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while ProcessInfo.processInfo.systemUptime < deadline {
            if !RunLoop.main.run(mode: trackingMode, before: Date(timeIntervalSinceNow: 0.01)) {
                // After cancellation this mode can have no sources; avoid a busy loop.
                Thread.sleep(forTimeInterval: 0.002)
            }
        }
    }

    private static func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline {
            pump(for: 0.01)
        }
    }

    private static func checkImmediateUpdatesAndFailure() {
        var next: MemorySnapshot? = sample()
        var reads = 0
        var updates = 0
        var publishedUnavailable = false
        let monitor = MemoryMonitor(reader: {
            reads += 1
            return next
        })
        monitor.onUpdate = { snapshot in
            updates += 1
            publishedUnavailable = snapshot == nil
        }

        expect(monitor.snapshot == nil, "首次读取前明确无数据")
        monitor.start()
        expect(reads == 1 && updates == 1 && monitor.snapshot != nil, "启动立即读取并发布")
        monitor.start()
        expect(reads == 1 && updates == 1, "重复启动不重复读取或注册")

        monitor.setMenuOpen(true)
        expect(reads == 2 && updates == 2, "打开菜单即使数值相同也立即发布")
        monitor.setMenuOpen(true)
        expect(reads == 2, "重复展开通知不额外读取")
        monitor.setMenuOpen(false)
        expect(reads == 2, "关闭菜单不额外读取")

        next = nil
        monitor.setMenuOpen(true)
        expect(monitor.snapshot == nil && publishedUnavailable, "读取失败清空旧值并发布不可用")
        next = sample()
        monitor.setMenuOpen(false)
        monitor.setMenuOpen(true)
        expect(monitor.snapshot != nil && !publishedUnavailable, "后续成功读取恢复真实数据")
        monitor.stop()
        let stoppedReads = reads
        let stoppedUpdates = updates
        pump(for: 1.25)
        expect(reads == stoppedReads && updates == stoppedUpdates, "停止后旧计时器不再读取或回调")
    }

    private static func checkTrackingAndClosedFrequency() {
        let value = sample()
        var reads = 0
        var updates = 0
        let monitor = MemoryMonitor(reader: {
            reads += 1
            return value
        })
        monitor.onUpdate = { _ in updates += 1 }
        monitor.start()
        monitor.setMenuOpen(true)
        let openedReads = reads
        waitUntil({ reads > openedReads }, timeout: 1.7)
        expect(reads == openedReads + 1, "非默认 common 模式中一秒计时器仍触发")
        expect(updates == reads, "重复相同数据仍发布以刷新菜单时间")

        monitor.setMenuOpen(false)
        let closedReads = reads
        pump(for: 1.3)
        expect(reads == closedReads, "关闭后不会继续按一秒读取")
        waitUntil({ reads > closedReads }, timeout: 4.7)
        expect(reads == closedReads + 1, "关闭后约五秒恢复一次读取且没有重复计时器")
        monitor.stop()
    }

    private static func checkRepeatedChangesAndPause() {
        let value = sample()
        var reads = 0
        let monitor = MemoryMonitor(reader: {
            reads += 1
            return value
        })
        monitor.start()
        for _ in 0..<20 {
            monitor.setMenuOpen(true)
            monitor.setMenuOpen(false)
        }
        monitor.setMenuOpen(true)
        let beforeTick = reads
        pump(for: 1.3)
        expect(reads == beforeTick + 1, "二十次开合后只有一个展开计时器")

        monitor.pause()
        monitor.pause()
        let pausedReads = reads
        monitor.setMenuOpen(false)
        monitor.setMenuOpen(true)
        monitor.start()
        pump(for: 1.3)
        expect(reads == pausedReads, "暂停期间开合菜单与重复启动都不会读取")
        monitor.resume()
        expect(reads == pausedReads + 1, "恢复立即读取")
        monitor.resume()
        expect(reads == pausedReads + 1, "重复恢复不增加读取或计时器")
        pump(for: 1.3)
        expect(reads == pausedReads + 2, "恢复后沿用展开状态且只有一个计时器")

        monitor.pause()
        monitor.stop()
        let stoppedReads = reads
        monitor.resume()
        monitor.setMenuOpen(true)
        pump(for: 1.3)
        expect(reads == stoppedReads, "停止后恢复或菜单事件不会复活采样")
    }

    private static func checkStopDuringCallbackAndRelease() {
        let value = sample()
        var reads = 0
        var monitor: MemoryMonitor? = MemoryMonitor(reader: {
            reads += 1
            return value
        })
        weak let weakMonitor = monitor
        monitor?.onUpdate = { [weak monitor] _ in monitor?.stop() }
        monitor?.setMenuOpen(true)
        monitor?.start()
        pump(for: 1.3)
        expect(reads == 1, "回调内停止不会被随后创建的计时器复活")

        monitor?.onUpdate = nil
        monitor?.setMenuOpen(true)
        monitor?.start()
        monitor?.stop()
        monitor = nil
        expect(weakMonitor == nil, "停止后计时器和闭包不保留采样器")
        let stoppedReads = reads
        pump(for: 1.3)
        expect(reads == stoppedReads, "释放后不再执行读取闭包")
    }
}
