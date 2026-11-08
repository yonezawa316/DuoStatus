import Foundation
import Darwin

@MainActor
final class MemoryMonitor {
    var onUpdate: ((MemorySnapshot?) -> Void)?
    private(set) var snapshot: MemorySnapshot?

    private let reader: () -> MemorySnapshot?
    private var timer: Timer?
    private var timerGeneration: UInt64 = 0
    private var isRunning = false
    private var isPaused = false
    private var isMenuOpen = false

    init(reader: (() -> MemorySnapshot?)? = nil) {
        if let reader {
            self.reader = reader
        } else {
            let totalBytes = ProcessInfo.processInfo.physicalMemory
            self.reader = { Self.readSnapshot(totalBytes: totalBytes) }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        guard !isPaused else { return }
        readAndPublish()
        replaceTimer()
    }

    func setMenuOpen(_ open: Bool) {
        guard open != isMenuOpen else { return }
        isMenuOpen = open
        guard isRunning, !isPaused else { return }
        cancelTimer()
        if open { readAndPublish() }
        replaceTimer()
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        cancelTimer()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        guard isRunning else { return }
        readAndPublish()
        replaceTimer()
    }

    func stop() {
        isRunning = false
        isPaused = false
        isMenuOpen = false
        cancelTimer()
    }

    private func readAndPublish() {
        guard isRunning, !isPaused else { return }
        // These small kernel reads are synchronous: no queued work or old results.
        // Publish unchanged values too, so an open menu can update its timestamp.
        snapshot = reader()
        onUpdate?(snapshot)
    }

    private func replaceTimer() {
        cancelTimer()
        // An onUpdate callback is allowed to stop or pause the monitor.
        guard isRunning, !isPaused else { return }
        let interval: TimeInterval = isMenuOpen ? 1 : 5
        let generation = timerGeneration
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] fired in
            guard let self else {
                fired.invalidate()
                return
            }
            // This timer is installed only on the main run loop.
            // Only the Sendable generation crosses the actor boundary, not Timer.
            MainActor.assumeIsolated {
                guard self.timerGeneration == generation, self.isRunning, !self.isPaused else { return }
                self.readAndPublish()
            }
        }
        next.tolerance = interval * 0.1
        timer = next
        // Default-mode timers would stop while NSMenu tracks the pointer.
        RunLoop.main.add(next, forMode: .common)
    }

    private func cancelTimer() {
        timerGeneration &+= 1
        timer?.invalidate()
        timer = nil
    }

    private static func readSnapshot(totalBytes: UInt64) -> MemorySnapshot? {
        let host = mach_host_self()
        guard host != MACH_PORT_NULL else { return nil }
        defer { _ = mach_port_deallocate(mach_task_self_, host) }

        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }

        var statistics = vm_statistics64_data_t()
        let capacity = MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        var count = mach_msg_type_number_t(capacity)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                host_statistics64(host, host_flavor_t(HOST_VM_INFO64), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryStatisticsDecoder.decode(statistics, returnedCount: count,
                                               totalBytes: totalBytes, pageSize: UInt64(pageSize))
    }
}

/// HOST_VM_INFO64 has grown across macOS releases. Accept its stable prefix and
/// only use an extension when both the build SDK and returned byte count allow it.
/// Never infer a field's presence from the OS version or read missing zeroed data.
enum MemoryStatisticsDecoder {
    static func decode(_ statistics: vm_statistics64_data_t,
                       returnedCount: mach_msg_type_number_t,
                       totalBytes: UInt64, pageSize: UInt64) -> MemorySnapshot? {
        let returnedBytes = Int(returnedCount) * MemoryLayout<integer_t>.stride
        guard returnedBytes <= MemoryLayout<vm_statistics64_data_t>.stride,
              let lastBaseOffset = MemoryLayout<vm_statistics64_data_t>.offset(of: \.internal_page_count),
              returnedBytes >= lastBaseOffset + MemoryLayout<natural_t>.size else { return nil }

        // Older kernels and SDKs expose the legacy purgeable count. That remains
        // an estimate: it cannot distinguish pageable purgeable memory from wired
        // purgeable memory. Do not invent a correction for data we cannot read.
        var purgeablePages = UInt64(statistics.purgeable_count)
        #if DUOSTATUS_HAS_PAGEABLE_PURGEABLE
        // The build script detects this member in the selected SDK, rather than
        // tying SDK availability to the Swift compiler's version. New kernels
        // expose the pageable subset so wired memory is not subtracted twice.
        if let offset = MemoryLayout<vm_statistics64_data_t>.offset(of: \.purgeable_pageable_count),
           returnedBytes >= offset + MemoryLayout<UInt64>.size {
            purgeablePages = statistics.purgeable_pageable_count
        }
        #endif

        return MemorySnapshot(
            totalBytes: totalBytes,
            pageSize: pageSize,
            internalPages: UInt64(statistics.internal_page_count),
            purgeablePages: purgeablePages,
            wiredPages: UInt64(statistics.wire_count),
            compressedPages: UInt64(statistics.compressor_page_count)
        )
    }
}
