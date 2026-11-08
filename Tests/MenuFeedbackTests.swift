import AppKit

@MainActor
private final class TestMotionPreference {
    var enabled = true
}

@main
@MainActor
struct MenuFeedbackTests {
    private static var checks = 0
    private static var failures = 0
    private static let trackingMode = RunLoop.Mode("DuoStatus.MenuFeedbackTests.tracking")

    static func main() {
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(rawValue: trackingMode.rawValue as CFString))
        checkPlaybackAndRestore(closing: false)
        checkPlaybackAndRestore(closing: true)
        checkReduceMotion()
        checkPriorityAndReplacement()
        checkRapidClicks()
        checkContinuousReversal()
        checkEndpointReversal()
        checkCancelStopAndRelease()
        checkStopDuringCallback()
        guard failures == 0 else {
            print("菜单点击反馈测试失败：\(failures)/\(checks) 项。")
            exit(1)
        }
        print("通过 \(checks) 项菜单开合反馈检查（真实主 runloop、正反向完整行程约 0.8 秒）。")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    private static func pump(for seconds: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while ProcessInfo.processInfo.systemUptime < deadline {
            if !RunLoop.main.run(mode: trackingMode, before: Date(timeIntervalSinceNow: 0.005)) {
                Thread.sleep(forTimeInterval: 0.002)
            }
        }
    }

    private static func waitUntil(_ condition: () -> Bool, timeout: TimeInterval) {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline {
            pump(for: 0.005)
        }
    }

    private static func frameDiagnostic(_ controller: PowerTransitionController,
                                        frames: Int, since started: TimeInterval) -> String {
        let progress = controller.menuClickProgress.map { String(Double($0)) } ?? "restored"
        return "progress=\(progress), frames=\(frames), elapsed=\(ProcessInfo.processInfo.systemUptime - started)s"
    }

    private static func checkPlaybackAndRestore(closing: Bool) {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        var previousProgress: CGFloat = closing ? 1 : 0
        var validProgress = true
        let action = closing ? "关闭" : "打开"
        controller.onFrame = {
            frames += 1
            if let progress = controller.menuClickProgress {
                let followsDirection = closing ? progress <= previousProgress : progress >= previousProgress
                validProgress = validProgress && followsDirection && progress >= 0 && progress <= 1
                previousProgress = progress
            }
        }
        let started = ProcessInfo.processInfo.systemUptime
        if closing {
            controller.showMenuClose()
        } else {
            controller.showMenuClick()
        }
        expect(controller.menuClickProgress == (closing ? 1 : 0) && frames == 1,
               "\(action)立即发布对应端点进度")
        expect(controller.change == nil && controller.networkConnected == nil,
               "\(action)不伪造电源或网络变化")
        pump(for: 0.14)
        let advanced = controller.menuClickProgress.map { closing ? $0 < 1 : $0 > 0 } ?? false
        expect(advanced, "菜单跟踪 common 模式仍推进\(action)动画")
        waitUntil({ controller.menuClickProgress == nil }, timeout: 0.9)
        expect(controller.menuClickProgress == nil, "\(action)动画完成后立即清除变换")
        let duration = ProcessInfo.processInfo.systemUptime - started
        expect(duration >= 0.75 && duration < 1.3, "\(action)完整行程约 0.8 秒且没有保持阶段")
        expect(validProgress && frames > 2, "\(action)进度沿正确方向单调且在零到一之间")
        let finishedFrames = frames
        pump(for: 0.15)
        expect(frames == finishedFrames, "\(action)结束后没有残留回调")
        controller.stop()
        controller.onFrame = nil
    }

    private static func checkReduceMotion() {
        let preference = TestMotionPreference()
        let controller = PowerTransitionController(reduceMotion: { preference.enabled })
        var frames = 0
        controller.onFrame = { frames += 1 }
        controller.showMenuClick()
        controller.showMenuClose()
        expect(controller.menuClickProgress == nil && frames == 0,
               "减少动态效果时跳过打开和关闭，不发布首帧")
        pump(for: 0.15)
        expect(frames == 0, "减少动态效果时没有菜单计时回调")

        preference.enabled = false
        controller.showMenuClick()
        pump(for: 0.06)
        preference.enabled = true
        let beforeCancel = frames
        controller.showMenuClose()
        expect(controller.menuClickProgress == nil && frames == beforeCancel + 1,
               "播放期间开启减少动态效果，只发一次恢复帧")
        let afterCancel = frames
        controller.showMenuClick()
        controller.showMenuClose()
        pump(for: 0.15)
        expect(frames == afterCancel, "减少动态效果取消后不残留或重新创建计时器")
        controller.stop()
    }

    private static func checkPriorityAndReplacement() {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        controller.onFrame = { frames += 1 }
        controller.show(.connected)
        let powerFrames = frames
        controller.showMenuClick()
        controller.showMenuClose()
        expect(controller.change == .connected && controller.menuClickProgress == nil,
               "打开和关闭均不抢占已有电源提示")
        expect(frames == powerFrames, "被电源提示抑制的开合不额外绘制")
        controller.cancelMenuClick()
        expect(controller.change == .connected, "强制取消菜单反馈不取消电源提示")
        controller.stop()

        controller.showNetworkConnection(true)
        let networkFrames = frames
        controller.showMenuClick()
        controller.showMenuClose()
        expect(controller.networkConnected == true && controller.menuClickProgress == nil,
               "打开和关闭均不抢占已有网络提示")
        expect(frames == networkFrames, "被网络提示抑制的开合不额外绘制")
        controller.cancelMenuClick()
        expect(controller.networkConnected == true, "强制取消菜单反馈不取消网络提示")
        controller.stop()

        controller.showMenuClick()
        controller.showNetworkConnection(false)
        expect(controller.menuClickProgress == nil && controller.networkConnected == false,
               "网络变化可以替换点击反馈")
        pump(for: 0.9)
        expect(controller.networkConnected == false, "旧点击恢复不会提前清掉网络提示")
        controller.stop()

        controller.showMenuClose()
        controller.show(.disconnected)
        expect(controller.menuClickProgress == nil && controller.change == .disconnected,
               "电源变化可以替换关闭反馈")
        pump(for: 0.9)
        expect(controller.change == .disconnected, "旧点击恢复不会提前清掉电源提示")
        controller.stop()
    }

    private static func checkRapidClicks() {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        controller.onFrame = { frames += 1 }
        let started = ProcessInfo.processInfo.systemUptime
        controller.showMenuClick()
        waitUntil({ frames > 1 }, timeout: 1.0)
        expect(frames > 1 && (controller.menuClickProgress ?? 1) > 0,
               "首个点击已经开始推进 [\(frameDiagnostic(controller, frames: frames, since: started))]")
        let beforeRepeat = controller.menuClickProgress
        let beforeFrames = frames
        for _ in 0..<20 { controller.showMenuClick() }
        expect(controller.menuClickProgress == beforeRepeat && frames == beforeFrames,
               "同方向快速点击保持进度，不重置或额外绘制")
        let observationStarted = ProcessInfo.processInfo.systemUptime
        pump(for: 0.16)
        waitUntil({ frames > beforeFrames || controller.menuClickProgress == nil }, timeout: 0.8)
        let observationElapsed = ProcessInfo.processInfo.systemUptime - observationStarted
        let frameLimit = Int(ceil(observationElapsed * 60)) + 2
        expect(frames - beforeFrames > 0 && frames - beforeFrames <= frameLimit,
               "重复点击后仍按单个 60 Hz 计时器推进 [limit=\(frameLimit), \(frameDiagnostic(controller, frames: frames - beforeFrames, since: observationStarted))]")
        waitUntil({ controller.menuClickProgress == nil }, timeout: 1.0)
        expect(controller.menuClickProgress == nil, "重复点击后正常结束")
        expect(ProcessInfo.processInfo.systemUptime - started < 1.15,
               "同方向点击不延长完整行程")
        let finishedFrames = frames
        pump(for: 0.15)
        expect(frames == finishedFrames, "快速点击结束后没有重复计时器回调")
        controller.stop()
    }

    private static func checkContinuousReversal() {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        var phaseOrigin: CGFloat = 0
        var target: CGFloat = 1
        var previousProgress: CGFloat = 0
        var phaseAdvanced = false
        var phaseValid = true
        // Observe every callback, including the restoring endpoint. A busy
        // runner may deliver several frames before waitUntil regains control.
        controller.onFrame = { [weak controller] in
            guard let controller else { return }
            frames += 1
            let value = controller.menuClickProgress ?? target
            let increasing = target > phaseOrigin
            phaseValid = phaseValid && value >= 0 && value <= 1
                && (increasing ? value >= previousProgress : value <= previousProgress)
            phaseAdvanced = phaseAdvanced || (increasing ? value > phaseOrigin : value < phaseOrigin)
            previousProgress = value
        }
        let started = ProcessInfo.processInfo.systemUptime
        controller.showMenuClick()
        waitUntil({ previousProgress >= 0.35 }, timeout: 1.0)
        let openingProgress = controller.menuClickProgress ?? 1
        phaseOrigin = openingProgress
        target = 0
        previousProgress = phaseOrigin
        phaseAdvanced = false
        phaseValid = true
        controller.showMenuClose()
        expect(openingProgress > 0 && controller.menuClickProgress == openingProgress,
               "关闭从当前已绘制进度连续反转 [\(frameDiagnostic(controller, frames: frames, since: started))]")
        waitUntil({ phaseAdvanced || controller.menuClickProgress == nil }, timeout: 1.0)
        let closingProgress = controller.menuClickProgress ?? 0
        expect(phaseAdvanced && phaseValid && closingProgress < openingProgress,
               "关闭后回调进度单调下降 [origin=\(openingProgress), \(frameDiagnostic(controller, frames: frames, since: started))]")
        phaseOrigin = closingProgress
        target = 1
        previousProgress = phaseOrigin
        phaseAdvanced = false
        phaseValid = true
        controller.showMenuClick()
        expect(controller.menuClickProgress == closingProgress,
               "关闭后重新打开保持进度连续 [\(frameDiagnostic(controller, frames: frames, since: started))]")
        waitUntil({ phaseAdvanced || controller.menuClickProgress == nil }, timeout: 1.0)
        let reopenedProgress = controller.menuClickProgress
        expect(phaseAdvanced && phaseValid && (reopenedProgress ?? 1) > closingProgress,
               "再次打开后回调进度单调上升 [origin=\(closingProgress), \(frameDiagnostic(controller, frames: frames, since: started))]")

        // The following block measures callback rate, not direction: its
        // synchronous calls intentionally alternate targets without advancing.
        controller.onFrame = { frames += 1 }

        // Repeated reversals keep replacing the one timer, then finish only the
        // remaining distance at the same progress-per-second speed.
        for _ in 0..<10 {
            controller.showMenuClose()
            controller.showMenuClick()
        }
        expect(controller.menuClickProgress == reopenedProgress,
               "快速来回反转不跳到零或一")
        let beforeSteadyFrames = frames
        let observationStarted = ProcessInfo.processInfo.systemUptime
        pump(for: 0.12)
        waitUntil({ frames > beforeSteadyFrames || controller.menuClickProgress == nil }, timeout: 0.8)
        let observationElapsed = ProcessInfo.processInfo.systemUptime - observationStarted
        let frameLimit = Int(ceil(observationElapsed * 60)) + 2
        expect(frames - beforeSteadyFrames > 0 && frames - beforeSteadyFrames <= frameLimit,
               "连续反转不累积并行帧计时器 [limit=\(frameLimit), \(frameDiagnostic(controller, frames: frames - beforeSteadyFrames, since: observationStarted))]")
        let closingOrigin = controller.menuClickProgress ?? 1
        let closeStarted = ProcessInfo.processInfo.systemUptime
        controller.showMenuClose()
        expect(controller.menuClickProgress == closingOrigin, "最终关闭仍保持当前进度")
        let beforeRepeatedClose = frames
        for _ in 0..<10 { controller.showMenuClose() }
        expect(frames == beforeRepeatedClose && controller.menuClickProgress == closingOrigin,
               "重复关闭不重置反向计时器")
        let expectedRemaining = TimeInterval(closingOrigin) * 0.8
        waitUntil({ controller.menuClickProgress == nil }, timeout: expectedRemaining + 0.2)
        let elapsed = ProcessInfo.processInfo.systemUptime - closeStarted
        expect(controller.menuClickProgress == nil, "反向只播放剩余距离后恢复")
        expect(elapsed >= max(0, expectedRemaining - 0.04) && elapsed < expectedRemaining + 0.15,
               "反向剩余时长按进度距离乘 0.8 秒计算")
        let finishedFrames = frames
        pump(for: 0.15)
        expect(frames == finishedFrames, "多次反转结束后没有残留回调")
        controller.stop()
    }

    private static func checkEndpointReversal() {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        controller.onFrame = { frames += 1 }
        controller.showMenuClick()
        controller.showMenuClose()
        expect(controller.menuClickProgress == nil, "打开首帧立刻关闭，在零端点直接恢复")
        controller.showMenuClose()
        controller.showMenuClick()
        expect(controller.menuClickProgress == nil, "关闭首帧立刻打开，在一端点直接恢复")
        let finishedFrames = frames
        pump(for: 0.15)
        expect(frames == finishedFrames, "端点反转不留下无意义计时器")
        controller.stop()
    }

    private static func checkCancelStopAndRelease() {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        controller.onFrame = { frames += 1 }
        controller.showMenuClick()
        pump(for: 0.1)
        controller.cancelMenuClick()
        expect(controller.menuClickProgress == nil, "强制取消时清除菜单变换")
        let cancelledFrames = frames
        controller.cancelMenuClick()
        pump(for: 0.9)
        expect(frames == cancelledFrames, "重复取消和旧计时器不再回调")

        weak var released: PowerTransitionController?
        autoreleasepool {
            let temporary = PowerTransitionController(reduceMotion: { false })
            released = temporary
            temporary.onFrame = { frames += 1 }
            temporary.showMenuClose()
            temporary.stop()
            expect(temporary.menuClickProgress == nil && temporary.change == nil
                   && temporary.networkConnected == nil && temporary.progress == 1,
                   "stop 清除点击、电源与网络全部状态")
        }
        expect(released == nil, "stop 后点击计时器不保留控制器")
        let stoppedFrames = frames
        pump(for: 0.9)
        expect(frames == stoppedFrames, "控制器释放后没有残留回调")
        controller.stop()
    }

    private static func checkStopDuringCallback() {
        let controller = PowerTransitionController(reduceMotion: { false })
        var frames = 0
        controller.onFrame = { [weak controller] in
            frames += 1
            controller?.stop()
        }
        controller.showMenuClick()
        let stoppedFrames = frames
        pump(for: 0.9)
        expect(controller.menuClickProgress == nil && frames == stoppedFrames,
               "首帧回调内停止不会再次创建点击计时器")
        controller.showMenuClose()
        let stoppedCloseFrames = frames
        pump(for: 0.15)
        expect(controller.menuClickProgress == nil && frames == stoppedCloseFrames,
               "关闭首帧回调内停止不会创建反向计时器")
        controller.onFrame = nil
        controller.stop()
    }
}
