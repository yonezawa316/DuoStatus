import Foundation
import IOKit.ps

struct BatterySnapshot: Equatable {
    enum State {
        case batteryPower, charging, pluggedInNotCharging, unknown, noBattery, unavailable
    }

    let percentage: Int?
    let state: State
    static let unavailable = BatterySnapshot(percentage: nil, state: .unavailable)
    var percentageText: String { percentage.map { "\($0)%" } ?? "—" }
    var isConnectedToPower: Bool? {
        switch state {
        case .charging, .pluggedInNotCharging: true
        case .batteryPower: false
        default: nil
        }
    }

    var statusText: String {
        switch state {
        case .batteryPower: "使用电池"
        case .charging: "正在充电"
        case .pluggedInNotCharging: "已接通电源，未充电"
        case .unknown: "供电状态不可用"
        case .noBattery: "未检测到内置电池"
        case .unavailable: "电池信息暂不可用"
        }
    }

    static func parse(_ descriptions: [[String: Any]]) -> BatterySnapshot {
        let batteries = descriptions.filter { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        guard let battery = batteries.first(where: { ($0[kIOPSIsPresentKey] as? Bool) == true }) else {
            let unidentifiedSource = descriptions.contains {
                guard let type = $0[kIOPSTypeKey] as? String else { return true }
                return type != kIOPSInternalBatteryType && type != kIOPSUPSType
            }
            if unidentifiedSource || batteries.contains(where: { $0[kIOPSIsPresentKey] as? Bool == nil }) {
                return .unavailable
            }
            return BatterySnapshot(percentage: nil, state: .noBattery)
        }
        guard let current = capacity(battery[kIOPSCurrentCapacityKey]),
              let maximum = capacity(battery[kIOPSMaxCapacityKey]),
              maximum > 0, current >= 0, current <= maximum else { return .unavailable }
        let percentage = Int((current / maximum * 100).rounded())
        let state: State
        switch battery[kIOPSPowerSourceStateKey] as? String {
        case kIOPSBatteryPowerValue:
            state = .batteryPower
        case kIOPSACPowerValue:
            if let charging = battery[kIOPSIsChargingKey] as? Bool {
                state = charging ? .charging : .pluggedInNotCharging
            } else { state = .unknown }
        default:
            state = .unknown
        }
        return BatterySnapshot(percentage: percentage, state: state)
    }

    private static func capacity(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }
}
