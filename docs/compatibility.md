# 兼容性与验证记录

## 支持目标

| 项目 | 当前范围 |
| --- | --- |
| 运行系统下限 | macOS 13.0 Ventura |
| CPU | arm64（Apple Silicon）、x86_64（Intel），均为原生机器码 |
| 发布格式 | 一个 Universal `.app`，ZIP 分发 |
| 特殊硬件 | 无电池的 Mac 显示无内置电池；无线接口或读数不可用时明确提示 |
| 系统权限 | 不要求定位、管理员、辅助功能或设备控制权限 |
| 不在支持范围 | macOS 12 及更旧版本、32 位及 PowerPC；不保证未来未验证的系统变化 |

这是部署与实现目标，不是所有机型已经通过实测的声明。没有市场占有率数据，因此不声称覆盖某个百分比的 Mac。Intel 能安装的系统仍受 Apple 对具体机型的支持范围限制。

两片机器码的 `LC_BUILD_VERSION` 与 Info.plist 均检查为 13.0。当前不提供 macOS 12 或更早系统的构建；降低下限需要验证 API 和兼容运行库，不能仅修改应用配置。

## 内存统计兼容

基础估算为：`(internal − purgeable + wired + compressor) × 系统页尺寸`，再除以物理内存总量得到比例。压缩内存使用实际存储页数，文件缓存不直接算作 App 内存。

- 新 SDK 定义了 `purgeable_pageable_count` 且内核返回完整字段时，用可分页可回收页数；避免从 App 内存中重复扣除 wired 可回收页。
- 旧 SDK 或旧内核没有该字段时，使用稳定的旧 `purgeable_count`。旧计数无法区分可分页和 wired 可回收内存，因此仍有统计口径误差，不进行无依据补偿。
- 只读取返回长度覆盖的字段；异常长度、溢出、不合理减法和页尺寸会返回不可用。页尺寸使用 `host_page_size`，不硬编码 4 KiB 或 16 KiB。

这不是内存压力指标，不能将百分比高直接称为“内存不足”，也不承诺与活动监视器总数相等。仅保留最新快照，不增加历史记录或补偿轮询。

## 发布候选版验证边界

0.5.0 build 1 已完成以下构建、逻辑回归与包完整性检查：

| 检查 | 结果 |
| --- | --- |
| 双架构构建 | arm64、x86_64 均成功；最低系统均为 13.0 |
| arm64 原生逻辑回归 | 204 项通过，含 15 项新版/旧内核 VM 结构兼容检查 |
| 不包含新 VM 字段的 SDK | arm64、x86_64 全部应用源文件类型检查通过；旧字段路径另外 10 项检查通过 |
| 包结构、图标与依赖 | 浅色图标存在；独立名称/标识；仅系统动态库依赖 |
| 签名及 ZIP 往返 | 本地 ad-hoc 签名有效；解压后的签名和可执行文件一致；SHA-256 校验通过 |

GitHub CI 已配置两个原生架构 runner，是否通过以对应提交的实际运行结果为准。配置存在不等于 CI 已通过，逻辑检查也不等于界面实机验收。

尚未执行：Intel 实机启动、macOS 13 最低系统实机操作、其他 macOS 版本矩阵、真实睡眠唤醒和重新长时间资源采样。因此不将候选版标为全面验收或保证所有 Mac 同等内存占用。

## 资源设计与目标

采用事件驱动、菜单收起 5 秒/展开 1 秒内存更新、短暂动画结束即停以及逐帧 `autoreleasepool`。

参考预算为冷启空闲 20 MiB、交互后 25 MiB、进程峰值 30 MiB。这些是设计目标，不是本发布包在不同硬件上的实测保证。没有“已经证明全局最省内存”的结论。Universal 增加磁盘文件大小，运行时只加载匹配架构，不会启动两份进程。

## 参考

- [Apple Universal 构建说明](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
- [Apple 开源 XNU host_statistics 实现](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/host.c)
- [活动监视器的内存说明](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac)
