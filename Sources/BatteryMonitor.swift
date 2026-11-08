import AppKit
import IOKit.ps

@MainActor
final class BatteryMonitor: NSObject {
    var onChange: ((BatterySnapshot) -> Void)?
    private(set) var snapshot: BatterySnapshot = .unavailable
    private var notificationSource: CFRunLoopSource?
    var isObserving: Bool { notificationSource != nil }

    func start() {
        guard notificationSource == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        notificationSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // This source is scheduled only on the main run loop.
            MainActor.assumeIsolated {
                Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }, context)?.takeRetainedValue()
        if let notificationSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), notificationSource, .commonModes)
        }
        refresh()
    }

    func refresh() {
        let next = Self.readSnapshot()
        guard next != snapshot else { return }
        snapshot = next
        onChange?(next)
    }

    func stop() {
        if let notificationSource {
            CFRunLoopSourceInvalidate(notificationSource)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), notificationSource, .commonModes)
        }
        notificationSource = nil
    }

    private static func readSnapshot() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let handles = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() else { return .unavailable }
        var descriptions: [[String: Any]] = []
        for handle in handles as NSArray {
            guard let description = IOPSGetPowerSourceDescription(info, handle as CFTypeRef)?.takeUnretainedValue(),
                  let dictionary = description as NSDictionary as? [String: Any] else { return .unavailable }
            descriptions.append(dictionary)
        }
        // GetPowerSourceDescription dictionaries are owned by this info blob.
        return withExtendedLifetime(info) { BatterySnapshot.parse(descriptions) }
    }
}
