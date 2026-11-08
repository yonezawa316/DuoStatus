import Foundation

@main
struct WiFiSnapshotTests {
    static func main() {
        let cases: [(String, Bool, Bool, WiFiInterfaceMode, Bool?, WiFiState)] = [
            ("关联且链路有效", true, true, .station, true, .connected),
            ("关联模式本身可确认连接", true, true, .station, nil, .connected),
            ("关联与断链冲突不猜测", true, true, .station, false, .unavailable),
            ("通电且明确断链", true, true, .none, false, .disconnected),
            ("none 与活动链路冲突", true, true, .none, true, .unavailable),
            ("none 且链路缺失不冒充未连接", true, true, .none, nil, .unavailable),
            ("断电且明确无链路", true, false, .none, false, .off),
            ("断电与活动链路冲突", true, false, .none, true, .unavailable),
            ("缺失链路不将读取失败冒充关闭", true, false, .none, nil, .unavailable),
            ("断电与关联模式冲突", true, false, .station, false, .unavailable),
            ("断电且关联活动链路冲突", true, false, .station, true, .unavailable),
            ("AP 或其他模式不是客户端连接", true, true, .other, true, .unavailable),
            ("未知模式断链不猜测", true, true, .other, false, .unavailable),
            ("未知模式断电不猜测", true, false, .other, false, .unavailable),
            ("缺少接口", false, false, .none, nil, .unavailable),
            ("接口失效时不使用旧连接数据", false, true, .station, true, .unavailable)
        ]
        var failures = 0
        for (name, available, powered, mode, active, expected) in cases {
            let result = WiFiSnapshot.resolve(
                interfaceAvailable: available, powerOn: powered, mode: mode, linkActive: active
            )
            if result.state != expected {
                print("FAIL: \(name)")
                failures += 1
            }
        }
        guard failures == 0 else { exit(1) }
        print("通过 \(cases.count) 个 Wi-Fi 状态与异常边界用例。")
    }
}
