import Foundation
import IOKit.ps

@main
struct BatterySnapshotTests {
    static func main() {
        let normal: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 80,
            kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSIsChargingKey: false
        ]
        func changed(_ key: String, _ value: Any?) -> [String: Any] {
            var result = normal
            result[key] = value
            return result
        }
        let cases: [(String, [[String: Any]], BatterySnapshot)] = [
            ("80% 接电但未充电", [normal], .init(percentage: 80, state: .pluggedInNotCharging)),
            ("正在充电", [changed(kIOPSIsChargingKey, true)], .init(percentage: 80, state: .charging)),
            ("使用电池", [changed(kIOPSPowerSourceStateKey, kIOPSBatteryPowerValue)], .init(percentage: 80, state: .batteryPower)),
            ("容量单位不是百分比", [changed(kIOPSMaxCapacityKey, 200)], .init(percentage: 40, state: .pluggedInNotCharging)),
            ("真实零电量", [changed(kIOPSCurrentCapacityKey, 0)], .init(percentage: 0, state: .pluggedInNotCharging)),
            ("缺失充电字段不猜测", [changed(kIOPSIsChargingKey, nil)], .init(percentage: 80, state: .unknown)),
            ("未知电源状态不猜测", [changed(kIOPSPowerSourceStateKey, "unexpected")], .init(percentage: 80, state: .unknown)),
            ("缺失容量不是零电量", [changed(kIOPSCurrentCapacityKey, nil)], .unavailable),
            ("零最大容量不除零", [changed(kIOPSMaxCapacityKey, 0)], .unavailable),
            ("负容量无效", [changed(kIOPSCurrentCapacityKey, -1)], .unavailable),
            ("超出最大容量无效", [changed(kIOPSCurrentCapacityKey, 101)], .unavailable),
            ("布尔值不是容量", [changed(kIOPSCurrentCapacityKey, true)], .unavailable),
            ("NaN 容量无效", [changed(kIOPSCurrentCapacityKey, Double.nan)], .unavailable),
            ("无内置电池", [], .init(percentage: nil, state: .noBattery)),
            ("电池不存在", [changed(kIOPSIsPresentKey, false)], .init(percentage: nil, state: .noBattery)),
            ("缺失存在标志", [changed(kIOPSIsPresentKey, nil)], .unavailable),
            ("缺失类型不能证明无电池", [changed(kIOPSTypeKey, nil)], .unavailable),
            ("错误类型不能证明无电池", [changed(kIOPSTypeKey, 123)], .unavailable),
            ("未知类型不能证明无电池", [changed(kIOPSTypeKey, "unexpected")], .unavailable),
            ("已有有效内置电池时忽略未知外设", [changed(kIOPSTypeKey, nil), normal], .init(percentage: 80, state: .pluggedInNotCharging)),
            ("UPS 不是内置电池", [changed(kIOPSTypeKey, kIOPSUPSType)], .init(percentage: nil, state: .noBattery)),
            ("UPS 在前仍选内置电池", [changed(kIOPSTypeKey, kIOPSUPSType), normal], .init(percentage: 80, state: .pluggedInNotCharging))
        ]
        var failures = 0
        for (name, input, expected) in cases {
            if BatterySnapshot.parse(input) != expected {
                print("FAIL: \(name)")
                failures += 1
            }
        }
        guard failures == 0 else { exit(1) }
        print("通过 \(cases.count) 个电池数据与异常状态用例。")
    }
}
