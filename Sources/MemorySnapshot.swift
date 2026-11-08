import Foundation

/// A VM-based estimate in bytes. Purgeable pages and file cache are excluded;
/// the reader selects the pageable purgeable subset when the SDK/kernel expose
/// it, otherwise the legacy count. Compressed memory counts physical storage.
struct MemorySnapshot: Equatable {
    let totalBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let usedBytes: UInt64

    var percentage: Int {
        Int((Double(usedBytes) / Double(totalBytes) * 100).rounded())
    }

    init?(totalBytes: UInt64, pageSize: UInt64, internalPages: UInt64,
          purgeablePages: UInt64, wiredPages: UInt64, compressedPages: UInt64) {
        guard totalBytes > 0, pageSize > 0, purgeablePages <= internalPages else { return nil }
        let app = (internalPages - purgeablePages).multipliedReportingOverflow(by: pageSize)
        let wired = wiredPages.multipliedReportingOverflow(by: pageSize)
        let compressed = compressedPages.multipliedReportingOverflow(by: pageSize)
        guard !app.overflow, !wired.overflow, !compressed.overflow else { return nil }
        let firstSum = app.partialValue.addingReportingOverflow(wired.partialValue)
        let sum = firstSum.partialValue.addingReportingOverflow(compressed.partialValue)
        guard !firstSum.overflow, !sum.overflow, sum.partialValue <= totalBytes else { return nil }
        self.totalBytes = totalBytes
        appBytes = app.partialValue
        wiredBytes = wired.partialValue
        compressedBytes = compressed.partialValue
        usedBytes = sum.partialValue
    }
}
