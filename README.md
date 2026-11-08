# DuoStatus

<img src="docs/assets/app-icon-light.png" width="128" alt="DuoStatus 浅色应用图标">

轻量的 Mac 菜单栏状态应用：电量、Wi-Fi 和全机内存估算，一枚组合图标即可查看。

A lightweight native macOS menu bar app for battery, Wi-Fi status, and estimated system memory usage. Built with Swift and AppKit, without third-party runtime dependencies.

## 发布候选版

当前为 **0.5.0 发布候选版**。应用名为 **DuoStatus Release**，使用浅色应用图标、独立的可执行文件和 bundle 标识。

- 部署目标：**macOS 13.0 或更新系统，Apple Silicon 与 Intel**，同一个 Universal 安装包。
- 无第三方运行依赖，不需要安装开发工具才能使用。
- 构建检查与实机兼容性是两回事；已完成和未完成的验证见[兼容性记录](docs/compatibility.md)。未在所有旧版系统和机型上实测，不保证未来系统版本。
- 默认下载包为 ad-hoc 本地签名、**未经 Apple 公证的预发布包**。GitHub 发布与 Apple 公证互相独立；正式签名流程见[发布说明](docs/publishing.md)。

## 功能

- 上弧显示电量：实际充电时绿色、低电量模式黄色、剩余电量不超过 10% 时红色。
- 中间显示 Wi-Fi 状态，关闭或断开时采用灰色斜线标识；不读取网络名称、密码或周围网络列表。
- 下弧显示整台 Mac 的内存占比估算，点击可查看 App、Wired、Compressed 分类和更新时间。
- 打开菜单时弧线收短再展开，关闭时反播；插拔电源、Wi-Fi 连接变化有短暂反馈，支持系统“减少动态效果”。

菜单只显示状态并提供退出，不修改电源或网络设置。已连接 Wi-Fi 不代表互联网一定可用；内存占比不等于内存压力，也不保证与活动监视器总数完全一致。无电池或无法取得数据时明确提示，不伪造正常值。

## 安装与使用

1. 从本项目 Releases 下载标注 `universal` 的应用 ZIP；GitHub 自动生成的 `Source code` 是源码，不是应用。
2. 解压，将 `DuoStatus Release.app` 拖入“应用程序”，双击打开。
3. 应用只出现在菜单栏。点击查看信息，选择“退出 DuoStatus Release”即可结束。重新使用时双击应用。

本版本不会添加开机启动项。若系统拦截未经公证的预发布包，请先核实来源，再参照[苹果的逐应用打开说明](https://support.apple.com/en-us/102445)，不需要关闭系统整体安全检查。

## 低占用原则

电量和 Wi-Fi 使用系统事件；内存仅保存最新快照，菜单收起时每 5 秒读取、展开时每秒更新，睡眠时暂停。动画结束后取消动画计时器，不保存历史帧。应用图标是静态资源，图标生成器不进入应用。

使用 `-Osize` 优化，但本发布候选版尚未完成长期资源采样，**不承诺所有 Mac 有相同的内存占用**。Universal 包含两种机器码，启动时只使用匹配的一种；文件大小不等于运行内存。

## 从源码构建

需要已有的 Apple 开发工具、**Swift 6.0 或更新编译器**及 macOS SDK。运行系统下限与构建工具版本是不同要求。本项目脚本不会自动安装任何工具。

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/package.sh
```

默认应用和分享包位于 `dist/`，CI 也使用该默认位置；构建缓存位于 `build/`。如果希望本地分享包与工程目录同级，在项目根目录执行：

```sh
./scripts/package.sh --output-dir ..
```

这会把 ZIP 与校验文件导出到工程的上一级目录，应用仍保留在 `dist/`。应用内置浅色图标会随包提供；脚本也尝试为 ZIP 设置同款 Finder 外观图标。ZIP 外观图标属于本地文件元数据，是否随传输保留取决于发送方式。生成应用图标并非日常构建的必要步骤，已有资源可直接打包。详见[构建说明](docs/build.md)。

## 文档

- [兼容范围与验证边界](docs/compatibility.md)
- [构建与文件规则](docs/file-rules.md)
- [隐私与卸载](docs/privacy.md)
- [图标设计](docs/icon-design.md)
- [GitHub 发布及签名](docs/publishing.md)
- [更新记录](CHANGELOG.md)

本项目目前**未采用开源许可证**，源码和原创图标保留权利，详见 [LICENSE.md](LICENSE.md)。公开可见不等于获得自由复制、修改或再分发许可；后续商业发布与许可方案由作者另行决定。
