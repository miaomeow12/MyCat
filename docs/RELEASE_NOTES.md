## MyCat v0.5.2 — 公开猫咪分享版

- 默认猫形象根据作者本人猫照片经 AI 生成；授权说明随安装包提供，代码使用 MIT、图片单独授权。
- 内置主人授权公开分享的 Q 版猫动作图，打开即可使用；原始照片和 API Key 不包含在仓库或安装包中。
- 保留完整打字节奏、鼠标点击/长按反馈、30 秒演示和输入诊断。
- 用户自己的自定义形象仍优先于内置形象。
- 修复 GitHub Actions 执行环境，使用 macOS 26。

下载 MyCat-macOS-universal.zip，解压后将 MyCat.app 放入“应用程序”。支持 macOS 14+ 的 Apple Silicon 和 Intel Mac。

仓库与 Release 已公开，可直接下载。默认猫形象根据作者本人猫照片经 AI 生成，代码和图片分别授权。下载包是 ad-hoc 签名，未经过 Apple 公证；键盘互动需输入监控授权。

### 首次打开提示“Apple could not verify MyCat”

此版本只有 ad-hoc（本地）签名，尚未使用 Apple Developer ID 签名和 Apple 公证，macOS 可能在首次下载后阻止打开。这类提示本身不代表已检出病毒，但该版本也未经过 Apple 验证。

确认下载来自本仓库并决定继续打开时：

1. 提示框点 **Done（完成）**。
2. 打开 **系统设置 → 隐私与安全性**。
3. 找到 MyCat 被阻止的提示，点击 **仍要打开（Open Anyway）**。
4. 按系统提示验证身份并确认打开。

未看到按钮时，再次尝试打开 MyCat 后回到设置查看；公司管理设备可能需要管理员处理。参见 [Apple 官方步骤](https://support.apple.com/en-us/102445)。
