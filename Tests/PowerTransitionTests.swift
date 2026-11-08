import AppKit

@main
@MainActor
struct PowerTransitionTests {
    private static var checks = 0
    private static var failures = 0

    static func main() {
        checkPowerChanges()
        checkBatteryTint()
        checkAnimationAndRestore()
        checkRapidReversal()
        checkNetworkAndPowerPriority()
        checkStopAndRelease()

        guard failures == 0 else {
            print("电源暂态测试失败：\(failures)/\(checks) 项。")
            exit(1)
        }
        print("通过 \(checks) 项电源暂态检查（使用真实主 runloop timer）。")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    // Running the main loop, rather than sleeping, lets the real timers fire.
    private static func pump(for seconds: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    private static func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    private static func checkPowerChanges() {
        let battery = BatterySnapshot(percentage: 80, state: .batteryPower)
        let charging = BatterySnapshot(percentage: 80, state: .charging)
        let plugged = BatterySnapshot(percentage: 80, state: .pluggedInNotCharging)

        expect(PowerChange.between(battery, charging) == .connected, "电池切换为充电触发接电")
        expect(PowerChange.between(battery, plugged) == .connected, "接电但未充电也触发接电")
        expect(PowerChange.between(charging, battery) == .disconnected, "充电切换为电池触发断电")
        expect(PowerChange.between(plugged, battery) == .disconnected, "未充电的 AC 切换为电池触发断电")
        expect(PowerChange.between(charging, plugged) == nil, "同为 AC 的充电状态变化不触发")
        expect(PowerChange.between(plugged, charging) == nil, "同为 AC 恢复充电不触发")
        expect(
            PowerChange.between(battery, .init(percentage: 79, state: .batteryPower)) == nil,
            "仅电量变化不触发"
        )

        for state: BatterySnapshot.State in [.unknown, .noBattery, .unavailable] {
            let unknown = BatterySnapshot(percentage: nil, state: state)
            expect(PowerChange.between(unknown, charging) == nil, "启动或未知到 AC 不猜测插电")
            expect(PowerChange.between(unknown, battery) == nil, "启动或未知到电池不猜测断电")
            expect(PowerChange.between(charging, unknown) == nil, "AC 到未知不猜测断电")
        }
    }

    private static func checkAnimationAndRestore() {
        let controller = PowerTransitionController()
        var frames = 0
        controller.onFrame = { frames += 1 }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        controller.show(.connected)
        expect(controller.change == .connected && frames == 1, "接电立即显示首帧")
        pump(for: 0.35)
        expect(controller.change == .connected, "动画前段仍保持接电图标")
        if reduceMotion {
            expect(controller.progress == 1, "减少动态效果时直接显示完整图标")
        } else {
            expect(controller.progress > 0 && controller.progress < 1, "真实 timer 推进约一秒动画")
            expect(frames > 1, "动画期间实际发出更新回调")
        }

        pump(for: 0.95)
        expect(controller.progress == 1 && controller.change == .connected, "动画结束后进入静止保持")
        let heldFrames = frames
        pump(for: 0.75)
        expect(controller.change == .connected, "约两秒时图标尚未提前恢复")
        expect(frames == heldFrames, "静止保持期间没有重复绘制回调")

        waitUntil({ controller.change == nil }, timeout: 1.6)
        expect(controller.change == nil && controller.progress == 1, "保持结束后恢复普通图标")
        let restoredFrames = frames
        pump(for: 0.35)
        expect(frames == restoredFrames, "恢复后不继续产生动画回调")
        controller.stop()
    }

    private static func checkBatteryTint() {
        let cases: [(Int?, Bool, BatteryTint, String)] = [
            (nil, false, .normal, "未知电量不显示低电量红色"),
            (nil, true, .normal, "未知电量不画出虚假的黄色电量填充"),
            (0, false, .critical, "真实零电量属于临界状态"),
            (10, false, .critical, "10% 边界显示红色"),
            (10, true, .critical, "临界红色优先于低电量模式黄色"),
            (11, false, .normal, "11% 且关闭低电量模式恢复普通颜色"),
            (11, true, .lowPower, "11% 且开启低电量模式显示黄色"),
            (100, true, .lowPower, "高电量也按已开启的低电量模式显示黄色"),
            (100, false, .normal, "高电量且普通模式使用正常颜色")
        ]
        for (percentage, lowPowerMode, expected, message) in cases {
            expect(BatteryTint.select(percentage: percentage, lowPowerMode: lowPowerMode) == expected, message)
        }
        let chargingCases: [(Int?, Bool, BatteryTint, String)] = [
            (80, false, .charging, "实际充电且普通模式显示绿色"),
            (11, false, .charging, "充电电量高于临界边界显示绿色"),
            (80, true, .lowPower, "充电时低电量模式黄色优先于绿色"),
            (10, false, .critical, "充电时 10% 边界红色优先于绿色"),
            (10, true, .critical, "充电且低电量模式时临界红色仍优先"),
            (nil, false, .normal, "充电但电量未知时不显示虚假绿色"),
            (nil, true, .normal, "充电且低电量模式但电量未知时不伪造填充")
        ]
        for (percentage, lowPowerMode, expected, message) in chargingCases {
            expect(
                BatteryTint.select(percentage: percentage, lowPowerMode: lowPowerMode, isCharging: true) == expected,
                message
            )
        }
    }

    private static func checkRapidReversal() {
        let controller = PowerTransitionController()
        controller.show(.connected)
        pump(for: 1.25)
        controller.show(.disconnected)
        expect(controller.change == .disconnected, "反向切换立即替换图标")

        // The first transition would restore after ~3 seconds. At this point
        // that old deadline has passed, but the new transition is still holding.
        pump(for: 2.1)
        expect(controller.change == .disconnected, "旧恢复 timer 不抢先覆盖新断电暂态")
        expect(controller.progress == 1, "反向切换后的动画能完成")
        waitUntil({ controller.change == nil }, timeout: 1.6)
        expect(controller.change == nil, "反向切换按新时序恢复")
        controller.stop()
    }

    private static func checkStopAndRelease() {
        weak var released: PowerTransitionController?
        var frames = 0
        autoreleasepool {
            let controller = PowerTransitionController()
            released = controller
            controller.onFrame = { frames += 1 }
            controller.show(.connected)
            pump(for: 0.2)
            controller.show(.disconnected)
            expect(controller.change == .disconnected, "动画尚未结束时也能反向切换")
            controller.stop()
            expect(controller.change == nil && controller.progress == 1, "stop 清除暂态")
        }
        expect(released == nil, "stop 后 timer 不再保留控制器")
        let stoppedFrames = frames
        pump(for: 0.35)
        expect(frames == stoppedFrames, "stop 后没有遗留回调")
    }

    private static func checkNetworkAndPowerPriority() {
        let controller = PowerTransitionController()
        controller.showNetworkConnection(true)
        expect(controller.networkConnected == true && controller.change == nil, "联网动画使用同一个暂态控制器")
        controller.showNetworkConnection(false)
        expect(controller.networkConnected == false, "快速断网替换联网动画")
        controller.show(.connected)
        expect(controller.networkConnected == nil && controller.change == .connected, "电源变化优先并取消网络动画")
        controller.showNetworkConnection(true)
        expect(controller.networkConnected == nil && controller.change == .connected, "网络事件不抢占电源提示")
        controller.stop()
        expect(controller.networkConnected == nil && controller.change == nil, "停止后同时清除两种暂态")
    }
}
