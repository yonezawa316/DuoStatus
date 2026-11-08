import Foundation
import Darwin

@main
@MainActor
struct MemoryCompatibilityTests {
    private static var checks = 0
    private static var failures = 0

    static func main() {
        let integerSize = MemoryLayout<integer_t>.stride
        let capacity = MemoryLayout<vm_statistics64_data_t>.stride / integerSize
        guard let baseOffset = MemoryLayout<vm_statistics64_data_t>.offset(of: \.internal_page_count) else {
            fatalError("当前 SDK 的 VM 结构缺少必需字段")
        }
        let minimumCount = (baseOffset + MemoryLayout<natural_t>.size) / integerSize
        var statistics = vm_statistics64_data_t()
        statistics.internal_page_count = 800
        statistics.purgeable_count = 100
        statistics.wire_count = 200
        statistics.compressor_page_count = 50

        func decode(_ value: vm_statistics64_data_t, count: Int, pageSize: UInt64 = 4_096) -> MemorySnapshot? {
            MemoryStatisticsDecoder.decode(value, returnedCount: mach_msg_type_number_t(count),
                                            totalBytes: 16 * 1_073_741_824, pageSize: pageSize)
        }

        expect(decode(statistics, count: 0) == nil, "空返回不伪造全机零内存")
        expect(decode(statistics, count: minimumCount - 1) == nil, "不足稳定字段长度时拒绝读取")
        expect(decode(statistics, count: capacity + 1) == nil, "返回长度超过本地缓冲区时拒绝读取")
        let legacy = decode(statistics, count: minimumCount)
        expect(legacy?.usedBytes == 950 * 4_096, "旧内核短结构使用旧 purgeable 计数")
        expect(legacy?.appBytes == 700 * 4_096, "旧结构应用内存扣除可回收页")
        expect(legacy?.wiredBytes == 200 * 4_096, "旧结构有线内存不丢失")
        expect(legacy?.compressedBytes == 50 * 4_096, "压缩内存使用实际物理页数")
        expect(decode(statistics, count: minimumCount, pageSize: 16_384)?.usedBytes == 950 * 16_384,
               "页尺寸来自调用者，支持 Intel 与 Apple Silicon")
        expect(decode(statistics, count: minimumCount, pageSize: 0) == nil, "无效页尺寸不产生比例")

        var inconsistent = statistics
        inconsistent.purgeable_count = 801
        expect(decode(inconsistent, count: minimumCount) == nil, "不一致旧计数不会无符号下溢或伪造校正")

        #if DUOSTATUS_HAS_PAGEABLE_PURGEABLE
        guard let offset = MemoryLayout<vm_statistics64_data_t>.offset(of: \.purgeable_pageable_count) else {
            fatalError("SDK 特性探测与 Swift 导入不一致")
        }
        let extendedCount = (offset + MemoryLayout<UInt64>.size) / integerSize
        statistics.purgeable_pageable_count = 40
        expect(decode(statistics, count: extendedCount)?.usedBytes == 1_010 * 4_096,
               "有完整新字段时仅扣除 pageable purgeable 页")
        expect(decode(statistics, count: extendedCount - 1)?.usedBytes == 950 * 4_096,
               "新字段不完整时忽略尾部数据并采用旧计数")
        statistics.purgeable_pageable_count = 0
        expect(decode(statistics, count: extendedCount)?.usedBytes == 1_050 * 4_096,
               "完整新字段的真实零值不会误当作不可用")
        statistics.purgeable_count = 1_000
        statistics.purgeable_pageable_count = 40
        expect(decode(statistics, count: extendedCount)?.usedBytes == 1_010 * 4_096,
               "新字段可用时不因包含 wired 的旧计数拒绝有效样本")
        statistics.purgeable_pageable_count = 801
        expect(decode(statistics, count: extendedCount) == nil, "异常新计数仍按边界规则拒绝")
        #endif

        guard failures == 0 else {
            print("内存兼容检查失败：\(failures)/\(checks) 项。")
            exit(1)
        }
        print("通过 \(checks) 项内存兼容检查（结构长度、旧内核回退、页尺寸）。")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }
}
