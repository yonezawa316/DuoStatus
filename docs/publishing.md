# GitHub 发布与销售说明

当前 **DuoStatus 0.5.0 为正式版，售价 US$1.99，一次性买断、无订阅**。购买入口准备中，尚未开放销售；安装包应保持 GitHub 发布草稿，等待收款与付费交付准备完成。源码仓库保持公开，源码公开不等于应用免费分发或授予开源许可。

GitHub 用于项目介绍、技术文档与版本记录；销售平台负责收款和购买后的文件交付。上传 GitHub 本身不需要绑定收款方式。产品介绍使用英语在前、中文随后，安装与兼容性细节通过技术文档提供。

## 仓库与安装包

1. 发布沿用 [LICENSE.md](../LICENSE.md) 中的许可状态。当前保留权利，不自行改用 MIT 或其他开源许可证。实际开售前需准备购买入口与对应使用条款；本次定价不承诺永久免费升级。
2. 公开 `main` 仅包含已经审查的源码、资源和文档，排除 `docs/local/`、构建缓存及其他应用。提交作者采用公开身份及 GitHub 隐藏邮箱，检查历史内容不含凭据。
3. GitHub Actions 在 Apple Silicon 与 Intel runner 分别构建、运行原生逻辑测试并打包。工作流仅有读取权限，不会自动创建公开 Release。提交 `6641a00` 的[两组检查已通过](https://github.com/yonezawa316/DuoStatus/actions/runs/42484134549)。
4. 收款准备完成前，将当前 Release 保持为 **draft**，保留已核对的 Universal ZIP 与 `.sha256` 附件供发布准备。未经维护者新的指令，不重新公开免费安装包。正式版面向用户的名称为 **DuoStatus 0.5.0**，是否准备好销售与 GitHub 草稿状态分开记录。
5. 销售平台准备好后，将同一份已核对的 ZIP 作为付费交付文件，并在产品页放入真实购买链接。不要用公开 GitHub 附件链接作为付费下载限制。

默认导出目录为 `dist/`；本地也可执行 `./scripts/package.sh --output-dir ..`，把 ZIP 和校验文件放到工程上一级目录。CI 在 runner 内完成打包验证，不上传可公开下载的应用 artifact；付费安装包通过选定销售平台交付。

GitHub 自动生成的 `Source code.zip` 是工程文件，不是应用安装包。不要把 `.app`、构建缓存或公证凭据提交到源码仓库。

应用内置浅色图标随 ZIP 内的 `.app` 提供。为本地 ZIP 设置的 Finder 图标可能在上传或下载时丢失，因为它依赖文件元数据；这不影响解压后的应用图标。

## Product description

> **DuoStatus 0.5.0 — US$1.99, one-time purchase. No subscription.**
>
> Battery, Wi-Fi status, and estimated memory usage in one compact Mac menu bar icon. Native Swift/AppKit design, live menu information, and short, smooth animations.
>
> For macOS 13 and later, with one Universal app for Apple Silicon and Intel. Sales are not open yet; the purchase link is coming soon.
>
> [Installation guide](build.md#installation-and-opening) · [Technical details](compatibility.md)

## 中文产品介绍

> **DuoStatus 0.5.0 — 1.99 美元一次性买断，无订阅。**
>
> 将电量、Wi-Fi 状态和内存占比估算整合在一枚紧凑的 Mac 菜单栏图标中。采用原生 Swift/AppKit，提供实时菜单信息与简短流畅的动画。
>
> 面向 macOS 13 及以上，提供 Apple 芯片与 Intel 通用应用。目前尚未开放销售，购买入口即将提供。
>
> [安装说明](build.md#安装与打开) · [技术信息](compatibility.md)

安装包的使用和分发范围由作者随销售条款另行说明；当前定价不代替完整的商业使用条款。支付账号、银行卡与身份资料只在选定销售平台的正式页面中填写，不放入 GitHub 或聊天记录。

## 正式签名与公证

面向普通用户的正式分发推荐 Developer ID 签名及 Apple 公证。需要自己的 Apple Developer 账号、已有的 Developer ID Application 证书，以及在系统钥匙串中配置好的公证凭据；本工程不自动注册账号、申请证书或保存密码。

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' ./scripts/build.sh
NOTARY_PROFILE='YOUR_EXISTING_KEYCHAIN_PROFILE' ./scripts/notarize.sh
```

上述值是占位符，必须替换为自己已有的身份与钥匙串条目。第二条命令会把签名包提交给 Apple，只在维护者安排公证时执行。成功后脚本装订公证票据、核验 Gatekeeper，再生成标有 `notarized` 的新 ZIP 与校验值。不要在公证后修改应用资源或重新签名，也不要继续发送公证前的旧 ZIP。

版本号和售价不改变签名状态，不能宣称“已公证”或保证所有用户双击即开。安装说明与兼容记录应与实际交付包一致。GitHub Releases 自身不是付费下载门槛，当前商业交付安排见上文。

## 参考

- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [GitHub 许可证说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
- [Apple Developer ID 与公证](https://developer.apple.com/developer-id/)
- [Apple 关于打开应用的说明](https://support.apple.com/en-us/102445)
