# 构建与打包

本工程使用 Apple 自带的 Swift、Clang、AppKit、IOKit、CoreWLAN 和 SystemConfiguration。需要现有 Swift 6.0+ 工具链和 macOS SDK；脚本不会安装工具、获取依赖或修改开发目录。

最低运行系统为 macOS 13.0，与开发工具所在系统及 SDK 版本并不相同。Swift 并发使用系统运行库，本项目不携带额外的动态回部署库。两种架构采用统一的 13.0 下限；若调整下限，需要重新验证 API 和工具链运行库兼容性，不能只修改 Info.plist。

## 日常命令

在本项目根目录执行：

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/package.sh
```

- `build.sh` 用 `-Osize`、整模块优化分别编译 arm64 和 x86_64，合并为 Universal 应用，复制浅色图标、配置并签名，再检查包结构。
- `test.sh` 执行数据计算、内存结构兼容、采样和动画状态测试，不启动应用或性能采样器，也不切换系统设置。
- `verify.sh` 检查双架构、两片机器码的最低系统版本、必要资源、系统动态库依赖及签名。可选参数为待检查的 `.app` 路径。
- `package.sh` 使用 `ditto` 打包，默认输出 `dist/DuoStatus-0.5.0-universal-adhoc.zip` 和 `.sha256`，CI 保持该默认位置。名称明确指出本地签名，不能把它宣传为已经 Apple 公证。

本地分享时，可在项目根目录指定上一级目录，让分享包与工程文件夹同级：

```sh
./scripts/package.sh --output-dir ..
```

`--output-dir PATH` 接受已有目录；相对路径按执行命令时的工作目录解析，支持带空格的路径（需加引号）。它只改变 ZIP 与校验文件的位置，应用仍在 `dist/`，不会自动删除其他目录中的旧分享包。不能导出到 `.app` 内部，也不会覆盖同名符号链接或非普通文件。

此参数可与 `--notarized` 同时使用，次序不限；只有已通过公证检查的应用才能生成带 `notarized` 名称的包。

运行发布版：

```sh
open 'dist/DuoStatus Release.app'
```

应用只有菜单栏入口，没有主窗口或 Dock 图标。构建脚本只检查本发布版是否运行，不退出或覆盖其他应用。

## SDK 兼容

`common.sh` 用 Clang 对当前 SDK 的 `vm_statistics64_data_t.purgeable_pageable_count` 做编译探测；字段存在时启用 `DUOSTATUS_HAS_PAGEABLE_PURGEABLE`。Swift 读取器还会核对内核实际返回的字段长度，不能因构建 SDK 较新就直接读取旧内核未提供的数据。

旧 SDK 及旧内核使用稳定计数的估算路径；页面尺寸来自 `host_page_size`，不假设 Intel 和 Apple Silicon 相同。口径限制见[兼容性记录](compatibility.md)。

如果已有其他 SDK，可仅对此次构建指定路径，不改变全局开发目录：

```sh
DUOSTATUS_SDK_PATH=/path/to/existing/MacOSX.sdk ./scripts/build.sh
```

## 输出与图标

所有持久编译缓存、单架构机器码、打包暂存文件和测试程序位于 `build/`；最终应用位于 `dist/`。ZIP 默认也放在 `dist/`，可通过 `--output-dir` 导出到已有目录；工程内的 `build/`、`dist/` 均被 Git 忽略，导出的分享包也不应提交到源码仓库。Swift driver 的短期临时文件使用系统用户临时目录，避免部分工具链对临时目录路径字符的限制。

`Resources/AppIcon.icns` 是实际发布资源。只有修改图标设计后才需要执行 `./scripts/build-icons.sh`。深色变体和生成器不会打进发布应用，因此不会常驻占用运行内存。

应用内置浅色图标始终包含在 `.app` 中。打包脚本编译并运行 `scripts/SetArchiveIcon.swift`，尝试为 ZIP 设置同款 Finder 外观图标；该构建工具保存在 `build/Tools/`，不进入应用。没有图形会话的 CI 可能无法设置外观图标，这时只输出警告，仍保留有效的分享包。

ZIP 外观图标保存在文件元数据中，不改变 ZIP 内容或 SHA-256；网盘、聊天或下载服务可能不保留它，这不影响解压后应用自带的图标。

构建脚本可用 `SIGNING_IDENTITY` 指定已有的 Developer ID 证书；Apple 公证是后续显式步骤，见[发布说明](publishing.md)。签名凭据不写入仓库。
