# DuoStatus

<img src="docs/assets/app-icon-light.png" width="128" alt="DuoStatus light app icon">

A lightweight native Mac menu bar app that brings battery, Wi-Fi status, and estimated system memory usage into one compact icon.

**macOS 13+ · Apple Silicon and Intel · Universal app**

[Download the pre-release](https://github.com/yonezawa316/DuoStatus/releases) · [中文介绍](#中文介绍)

## What it shows

- **Battery:** the upper arc shows charge level. It turns red at 10% or below; otherwise yellow in Low Power Mode, or green while actively charging.
- **Wi-Fi:** the center icon shows connection state, with a gray slash when disconnected or switched off.
- **Memory:** the lower arc shows estimated system memory use. Open the menu for App, Wired, and Compressed memory, plus the last update time.
- **Motion:** short arc animations play forward when opening the menu and reverse when closing it. Power and Wi-Fi changes have brief feedback, with support for Reduce Motion.

The menu displays status and provides a quit action. It does not change battery or network settings. Missing or unsupported data is clearly marked. Wi-Fi connection does not guarantee internet access; estimated memory use is not memory pressure and may differ from Activity Monitor.

## Install

1. Download the app ZIP marked `universal` from [Releases](https://github.com/yonezawa316/DuoStatus/releases). The automatically generated `Source code` archives contain source files, not the app.
2. Unzip it, move **DuoStatus Release.app** to **Applications**, and open it.
3. Click its menu bar icon to view status. Choose **退出 DuoStatus Release** to quit; double-click the app to open it again. The current app menu is in Chinese.

The app has no main window or Dock icon and does not add a login item. The current pre-release uses **ad-hoc signing and is not notarized by Apple**. If macOS blocks it, verify the download source and follow [Apple’s instructions for opening an app](https://support.apple.com/en-us/102445).

## Lightweight and private

Built with Swift and AppKit, using Apple frameworks and system runtimes without third-party runtime dependencies. Battery and Wi-Fi use system events. Memory retains only the latest snapshot, updating every five seconds with the menu closed and every second while open, and pausing during sleep. Animation timers stop when their brief feedback ends.

No telemetry, ads, update service, network scanning, or stored history. DuoStatus does not read SSIDs, BSSIDs, or Wi-Fi passwords, and does not request location, accessibility, or administrator access. See [privacy and removal](docs/privacy.md).

This is **0.5.0, a release candidate**. Both architectures build, and focused logic and package checks have passed. Older-system and Intel hardware testing and long-term resource measurements are still pending; no fixed memory footprint is promised across devices. See the [compatibility record](docs/compatibility.md).

## Build and package

Use an existing Apple development toolchain with **Swift 6.0+** and a macOS SDK. Scripts do not install tools or download dependencies. From the project root:

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/package.sh
```

The app and ZIP default to `dist/`, which CI also uses. Build products and caches stay in `build/`. To export the ZIP and SHA-256 file next to the project folder:

```sh
./scripts/package.sh --output-dir ..
```

The app remains in `dist/`. Its light icon is embedded in the app and travels with the package. Packaging also attempts to give the ZIP a matching Finder icon; that outer icon is file metadata and may not survive upload or transfer. Icon tools do not run inside the app. See [build instructions](docs/build.md).

## Documentation and license

Additional documentation is currently in Chinese:

[Compatibility](docs/compatibility.md) · [File rules](docs/file-rules.md) · [Privacy](docs/privacy.md) · [Icon design](docs/icon-design.md) · [Publishing and signing](docs/publishing.md) · [Changelog](CHANGELOG.md)

**All rights reserved.** This repository is not open-source licensed. Public visibility does not grant additional rights to copy, modify, or redistribute the source or original artwork. See [LICENSE.md](LICENSE.md) for the current license status.

---

## 中文介绍

DuoStatus 是一个轻量原生 Mac 菜单栏应用，将电量、Wi-Fi 状态和全机内存估算放进一枚紧凑图标。

**面向 macOS 13 及以上，提供 Apple 芯片与 Intel 通用安装包。**

### 功能

- **电量上弧：**显示剩余电量；不超过 10% 时红色，否则低电量模式下黄色，否则实际充电时绿色。
- **中央 Wi-Fi：**显示连接状态，关闭或断开时采用灰色斜线标识。
- **内存下弧：**显示全机内存占比估算，点击可查看 App、Wired、Compressed 分类及更新时间。
- **简短动画：**打开菜单时弧线收短再展开，关闭时反播；电源与 Wi-Fi 变化有短暂反馈，支持“减少动态效果”。

菜单只显示状态并提供退出，不修改电源或网络设置。数据不可用时明确提示。Wi-Fi 已连接不代表互联网一定可用；内存占比不等于内存压力，也可能与活动监视器总数不同。

### 安装与使用

1. 从 [Releases](https://github.com/yonezawa316/DuoStatus/releases) 下载标有 `universal` 的应用 ZIP，自动生成的 `Source code` 是源码包。
2. 解压，把 **DuoStatus Release.app** 拖入“应用程序”，双击打开。
3. 点击菜单栏图标查看信息，选择“退出 DuoStatus Release”结束；再次使用时双击应用。

应用没有主窗口或 Dock 图标，也不会添加开机启动项。当前预发布包采用 **ad-hoc 签名，尚未经过 Apple 公证**。如果 macOS 拦截，请核实来源后参照[苹果的打开说明](https://support.apple.com/en-us/102445)。

### 低占用与隐私

使用 Swift、AppKit 和系统框架，没有第三方运行依赖。电量和 Wi-Fi 按系统事件更新；内存只保留最新快照，菜单收起时每 5 秒读取、展开时每秒更新，睡眠时暂停。动画结束后停止动画计时器。

无遥测、广告、更新服务、网络扫描或历史记录。不读取 SSID、BSSID 和 Wi-Fi 密码，不请求定位、辅助功能或管理员权限，详见[隐私与卸载](docs/privacy.md)。

当前为 **0.5.0 发布候选版**：已完成双架构构建、逻辑回归和打包检查，尚待旧系统、Intel 实机及长期资源验证，不承诺所有设备具有相同内存占用。具体范围见[兼容性记录](docs/compatibility.md)。

### 构建与文件位置

需要已有的 Apple 开发工具、Swift 6.0+ 编译器及 macOS SDK。构建命令见上方英文部分；脚本不会安装工具或下载依赖。默认应用和 ZIP 位于 `dist/`，CI 也使用此位置，缓存位于 `build/`。

在工程根目录执行 `./scripts/package.sh --output-dir ..`，可将 ZIP 和校验文件导出到工程上一级目录，与工程文件夹同级；应用仍保留在 `dist/`。应用内置浅色图标始终随包提供，ZIP 的 Finder 外观图标可能在传输后丢失，不影响解压后的应用图标。详见[构建说明](docs/build.md)。

[文件规则](docs/file-rules.md) · [图标设计](docs/icon-design.md) · [发布与签名](docs/publishing.md) · [更新记录](CHANGELOG.md)

项目目前**未采用开源许可证，保留全部权利**。公开可见不等于获得额外的复制、修改或再分发许可；当前状态见 [LICENSE.md](LICENSE.md)。
