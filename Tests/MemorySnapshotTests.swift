import Foundation

@main
struct MemorySnapshotTests {
    static func main() {
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ name: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: \(name)") }
        }
        let snapshot = MemorySnapshot(totalBytes: 16_384_000, pageSize: 16_384,
                                      internalPages: 400, purgeablePages: 100,
                                      wiredPages: 150, compressedPages: 50)!
        expect(snapshot.appBytes == 4_915_200, "应用内存扣除可清除页")
        expect(snapshot.wiredBytes == 2_457_600, "按实际 16 KiB 页计算联动内存")
        expect(snapshot.compressedBytes == 819_200, "压缩内存使用物理页而非解压后大小")
        expect(snapshot.usedBytes == 8_192_000, "已用为三项之和，不包含文件缓存")
        expect(snapshot.percentage == 50, "比例按物理总内存计算")

        func make(total: UInt64 = 1000, page: UInt64 = 1, internalCount: UInt64 = 0,
                  purgeable: UInt64 = 0, wired: UInt64 = 0, compressed: UInt64 = 0) -> MemorySnapshot? {
            MemorySnapshot(totalBytes: total, pageSize: page, internalPages: internalCount,
                           purgeablePages: purgeable, wiredPages: wired, compressedPages: compressed)
        }
        expect(make()?.percentage == 0, "合法零占用与不可用不同")
        expect(make(internalCount: 1000)?.percentage == 100, "全占用边界")
        expect(make(internalCount: 494)?.percentage == 49, "整数比例向下舍入")
        expect(make(internalCount: 495)?.percentage == 50, "整数比例半数进位")
        expect(make(total: 0) == nil, "总内存零值不可用")
        expect(make(page: 0) == nil, "页大小零值不可用")
        expect(make(internalCount: 10, purgeable: 11) == nil, "扣除异常不发生无符号下溢")
        expect(make(internalCount: 1001) == nil, "超过物理总量不伪装成100%")
        expect(make(total: .max, page: 2, internalCount: .max) == nil, "应用页乘法溢出")
        expect(make(total: .max, page: 2, wired: .max) == nil, "联动页乘法溢出")
        expect(make(total: .max, page: 2, compressed: .max) == nil, "压缩页乘法溢出")
        expect(make(total: .max, internalCount: .max, wired: 1) == nil, "第一项加法溢出")
        expect(make(total: .max, internalCount: .max - 1, wired: 1, compressed: 1) == nil, "第二项加法溢出")
        expect(make(total: .max, internalCount: .max)?.percentage == 100, "大整数比例不进行整数乘100")
        expect(make(total: 409_600, page: 4096, internalCount: 50)?.percentage == 50, "不硬编码Apple Silicon页大小")
        guard failures == 0 else { exit(1) }
        print("通过 \(checks) 项内存统计与异常边界检查。")
    }
}
