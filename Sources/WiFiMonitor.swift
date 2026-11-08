import Foundation
import CoreWLAN
import SystemConfiguration

@MainActor
final class WiFiMonitor {
    var onChange: ((WiFiSnapshot) -> Void)?
    private(set) var snapshot = WiFiSnapshot.unavailable
    private(set) var isObserving = false
    private var isRunning = false
    private var generation: UInt64 = 0
    private lazy var worker = WiFiWorker { [weak self] generation, snapshot, observing in
        Task { @MainActor [weak self] in
            guard let self, self.isRunning, self.generation == generation else { return }
            let changed = self.snapshot != snapshot || self.isObserving != observing
            self.isObserving = observing
            self.snapshot = snapshot
            if changed { self.onChange?(snapshot) }
        }
    }

    // Call at launch, and again on menu opening/wake to retry failed observation.
    func start() {
        if !isRunning {
            isRunning = true
            generation &+= 1
        }
        worker.start(generation: generation)
    }

    func refresh() {
        guard isRunning else { return }
        worker.refresh(generation: generation)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        isObserving = false
        generation &+= 1
        worker.stop()
    }
}

// All mutable state and framework objects are confined to queue. Framework
// delegate callbacks only enqueue work; only Sendable snapshots leave it.
private final class WiFiWorker: NSObject, CWEventDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "DuoStatus.WiFi", qos: .utility, autoreleaseFrequency: .workItem)
    private let onSnapshot: @Sendable (UInt64, WiFiSnapshot, Bool) -> Void
    private var client: CWWiFiClient?
    private var store: SCDynamicStore?
    private var linkKey: CFString?
    private var watchedInterface: String?
    private var storeIsObserving = false
    private var storeIsScheduled = false
    private var registeredEvents: Set<Int> = []
    private var generation: UInt64 = 0
    private var active = false
    private var lastPublished: (UInt64, WiFiSnapshot, Bool)?

    init(onSnapshot: @escaping @Sendable (UInt64, WiFiSnapshot, Bool) -> Void) {
        self.onSnapshot = onSnapshot
    }

    func start(generation: UInt64) {
        queue.async { [self] in
            self.generation = generation
            active = true
            if client == nil { client = CWWiFiClient() }
            client?.delegate = self
            for event in [CWEventType.powerDidChange, .linkDidChange, .modeDidChange] {
                guard !registeredEvents.contains(event.rawValue) else { continue }
                do {
                    try client?.startMonitoringEvent(with: event)
                    registeredEvents.insert(event.rawValue)
                } catch { /* Opening the menu or waking retries registration. */ }
            }
            prepareStore()
            readAndPublish()
        }
    }

    func refresh(generation: UInt64) {
        queue.async { [self] in
            guard active, self.generation == generation else { return }
            readAndPublish()
        }
    }

    func stop() {
        queue.async { [self] in
            active = false
            lastPublished = nil
            client?.delegate = nil
            try? client?.stopMonitoringAllEvents()
            registeredEvents.removeAll()
            if let store { SCDynamicStoreSetDispatchQueue(store, nil) }
            store = nil
            linkKey = nil
            watchedInterface = nil
            storeIsObserving = false
            storeIsScheduled = false
        }
    }

    private func prepareStore() {
        guard store == nil else { return }
        var context = SCDynamicStoreContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        store = SCDynamicStoreCreate(nil, "DuoStatus.WiFi" as CFString, { _, _, context in
            guard let context else { return }
            Unmanaged<WiFiWorker>.fromOpaque(context).takeUnretainedValue().eventReceived()
        }, &context)
    }

    private func watchInterface(_ name: String?) {
        guard let store else { return }
        guard name != watchedInterface || linkKey == nil || !storeIsObserving else { return }
        watchedInterface = name
        linkKey = name.map {
            SCDynamicStoreKeyCreateNetworkInterfaceEntity(
                nil, kSCDynamicStoreDomainState, $0 as CFString, kSCEntNetLink
            )
        }
        var keys = [SCDynamicStoreKeyCreateNetworkInterface(nil, kSCDynamicStoreDomainState)]
        if let linkKey { keys.append(linkKey) }
        let keysRegistered = SCDynamicStoreSetNotificationKeys(store, keys as CFArray, nil)
        if !storeIsScheduled {
            storeIsScheduled = SCDynamicStoreSetDispatchQueue(store, queue)
        }
        storeIsObserving = keysRegistered && storeIsScheduled
    }

    private func readAndPublish() {
        guard active else { return }
        guard let interface = client?.interface() else {
            watchInterface(nil)
            publish(.unavailable)
            return
        }
        watchInterface(interface.interfaceName)
        var linkActive: Bool?
        if let store, let linkKey,
           let link = SCDynamicStoreCopyValue(store, linkKey) as? [String: Any] {
            linkActive = link[kSCPropNetLinkActive as String] as? Bool
        }
        let powerOn = interface.powerOn()
        let mode: WiFiInterfaceMode
        switch interface.interfaceMode() {
        case .none: mode = .none
        case .station: mode = .station
        default: mode = .other
        }
        publish(.resolve(interfaceAvailable: true, powerOn: powerOn, mode: mode, linkActive: linkActive))
    }

    private func publish(_ snapshot: WiFiSnapshot) {
        let observing = registeredEvents.count == 3 && storeIsObserving
        if let previous = lastPublished, previous.0 == generation,
           previous.1 == snapshot, previous.2 == observing { return }
        lastPublished = (generation, snapshot, observing)
        onSnapshot(generation, snapshot, observing)
    }

    private func eventReceived() {
        queue.async { [self] in readAndPublish() }
    }

    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) { eventReceived() }
    func linkDidChangeForWiFiInterface(withName interfaceName: String) { eventReceived() }
    func modeDidChangeForWiFiInterface(withName interfaceName: String) { eventReceived() }

    func clientConnectionInterrupted() {
        queue.async { [self] in
            guard active else { return }
            // CoreWLAN automatically re-registers events after interruption.
            publish(.unavailable)
        }
    }

    func clientConnectionInvalidated() {
        queue.async { [self] in
            guard active else { return }
            client?.delegate = nil
            client = nil
            registeredEvents.removeAll()
            publish(.unavailable)
        }
    }
}
