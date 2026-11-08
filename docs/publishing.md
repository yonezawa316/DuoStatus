# GitHub 发布说明

本仓库保存发布工程，应用安装包通过 Releases 提供。当前包按预发布版本发布，兼容性边界与签名状态必须随包说明。GitHub 上传与商业销售是不同步骤；上传项目不需要绑定收款方式。

## 仓库与 Release

1. 发布沿用 [LICENSE.md](../LICENSE.md) 中的许可状态。当前保留权利，上传到 GitHub 不要求改用 MIT 或其他开源许可证。
2. 将本工程连接到维护者指定的 GitHub 仓库并推送 `main`。只上传已经审查的源码、资源和文档，排除 `docs/local/`、构建缓存及其他应用。首次推送前检查提交作者采用公开身份及 GitHub 隐藏邮箱，以及暂存和历史内容不含凭据。
3. GitHub Actions 配置会构建两种架构，在 Apple Silicon 与 Intel runner 分别运行逻辑测试，再保留安装包 artifact。工作流仅有读取权限，不会创建公开 Release；尚未在远端运行时不要标记 CI 已通过。
4. 创建一个 **draft / pre-release**，选择实际提交并使用 `v0.5.0-rc.1` 等候选标签。附上本次导出目录中的 Universal ZIP 和对应 `.sha256`，填写下面的说明模板，检查后再发布。默认导出目录为 `dist/`；本地也可在项目根目录执行 `./scripts/package.sh --output-dir ..`，把附件放到工程的上一级目录。CI 继续从默认 `dist/` 收集附件。

GitHub 自动提供的 `Source code.zip` 不是应用安装包；Releases 中必须另外上传构建得到的 ZIP。不要把 `.app`、构建缓存或公证凭据提交到源码仓库。

应用内置浅色图标会随 ZIP 内的 `.app` 提供。为本地 ZIP 设置的 Finder 外观图标可能在上传或下载时丢失，因为它依赖文件元数据；这不影响解压后的应用图标。

## 可复制的候选版说明

> DuoStatus 0.5.0 发布候选版。支持目标为 macOS 13.0 及以上、Apple Silicon 与 Intel，下载带 `universal` 的应用 ZIP。
>
> 解压后把 DuoStatus Release.app 拖到“应用程序”并打开；菜单栏中点击查看电量、Wi-Fi 和内存估算。无自动启动项，不需要定位或管理员权限。
>
> 当前包使用 ad-hoc 本地签名，未经 Apple 公证，首次打开可能被 Gatekeeper 拦截。仅在确认来源及完整性后，按苹果指引逐应用允许打开，不要关闭整体安全检查。
>
> 双架构构建与逻辑检查不等于所有旧系统实机测试。内存为公开 VM 统计估算，不保证与活动监视器完全一致，也未承诺所有机器相同的资源占用。具体记录见仓库兼容性文档。

安装包的使用和再分发范围以具体 Release 的说明为准；公开提供下载不等于授予开源许可。收费与支付交付另行安排，不应在上传源码时索取收款账号或银行卡信息。

## 正式签名与公证

面向普通用户的正式分发推荐 Developer ID 签名及 Apple 公证。需要自己的 Apple Developer 账号、已有的 Developer ID Application 证书，以及在系统钥匙串中配置好的公证凭据；本工程不自动注册账号、申请证书或保存密码。

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' ./scripts/build.sh
NOTARY_PROFILE='YOUR_EXISTING_KEYCHAIN_PROFILE' ./scripts/notarize.sh
```

上述值是占位符，必须替换为自己已有的身份与钥匙串条目。第二条命令会把签名包提交给 Apple，只在维护者安排公证时执行。成功后脚本装订公证票据、核验 Gatekeeper，再生成标有 `notarized` 的新 ZIP 与校验值。不要在公证后修改应用资源或重新签名，也不要继续发送公证前的旧 ZIP。

没有账号和证书时，仍可以在 GitHub 提供注明状态的预发布包，但不能宣称“已公证”或保证所有用户双击即开。商业收费页面与支付交付另外准备，GitHub Releases 自身不是付费下载门槛。

## 参考

- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [GitHub 许可证说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
- [Apple Developer ID 与公证](https://developer.apple.com/developer-id/)
- [Apple 关于打开应用的说明](https://support.apple.com/en-us/102445)
