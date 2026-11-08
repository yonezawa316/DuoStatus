enum WiFiState: Equatable, Sendable {
    case connected, disconnected, off, unavailable
}

enum WiFiInterfaceMode: Sendable {
    case none, station, other
}

struct WiFiSnapshot: Equatable, Sendable {
    let state: WiFiState

    static let unavailable = WiFiSnapshot(state: .unavailable)

    // Link.Active is the selected Wi-Fi interface's link state, not reachability.
    // CoreWLAN's false/none results also represent errors, so absence and
    // contradictions must not be silently converted to a disconnected radio.
    static func resolve(
        interfaceAvailable: Bool,
        powerOn: Bool,
        mode: WiFiInterfaceMode,
        linkActive: Bool?
    ) -> WiFiSnapshot {
        guard interfaceAvailable else { return .unavailable }
        if !powerOn {
            return mode == .none && linkActive == false
                ? .init(state: .off) : .unavailable
        }
        switch mode {
        case .station:
            return linkActive == false ? .unavailable : .init(state: .connected)
        case .none:
            return linkActive == false ? .init(state: .disconnected) : .unavailable
        case .other:
            // Hosting an access point is not association with another access point.
            return .unavailable
        }
    }

    var statusText: String {
        switch state {
        case .connected: "Wi-Fi：已连接"
        case .disconnected: "Wi-Fi：未连接或正在连接"
        case .off: "Wi-Fi：已关闭"
        case .unavailable: "Wi-Fi：状态暂不可用"
        }
    }
}
