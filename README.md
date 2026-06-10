# Codex Quota Bar

Native macOS menu bar app for watching Codex quota usage from the local Codex session.

[中文说明](#中文说明)

## English

### Features

- Shows 5-hour and 7-day remaining quota directly in the macOS menu bar.
- Uses an AppKit status item shell with a SwiftUI panel: left-click shows quota, right-click opens the management menu.
- Shows account, plan, reset times, refresh state, and quota planning details.
- Includes a current-cycle 7-day usage chart with a `Used %` y-axis.
- Supports an "Open at login" toggle in the right-click menu through the native macOS login item API.
- Ships with an original transparent app icon in the release bundle.
- UI copy automatically switches between Chinese and English based on the system language.

### Data And Privacy

The app reads the current Codex access token and account id from `~/.codex/auth.json`, then calls:

```text
https://chatgpt.com/backend-api/wham/usage
```

Local quota history is stored at:

```text
~/Library/Application Support/CodexQuotaBar/usage-history.json
```

History records contain quota percentages, reset timestamps, and a hashed account key. They do not store Codex tokens.

### Build

Building the SwiftUI/AppKit app requires full Xcode, not Command Line Tools only.

```sh
./Scripts/build.sh
```

The script builds a universal Intel + Apple Silicon app at:

```text
outputs/CodexQuotaBar.app
```

### Run

```sh
open outputs/CodexQuotaBar.app
```

For a terminal-only quota check:

```sh
outputs/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --once
```

### Open At Login

Right-click the status item and enable "Open at login" from the menu. macOS may ask you to approve it in System Settings > Login Items.

If the toggle reports that the login item cannot be found, move `CodexQuotaBar.app` from the release package into `/Applications` and open it again.

## 中文说明

一个原生 macOS 菜单栏小工具，用来查看本机 Codex 账号的 5 小时和 7 天额度。

### 功能

- 在菜单栏直接显示 5 小时额度和 7 天额度的剩余百分比。
- 使用 AppKit 状态栏外壳和 SwiftUI 面板，左键查看额度，右键打开管理菜单。
- 面板里显示账号、套餐、重置时间、刷新状态和用量规划。
- 提供本周期 7 天额度消耗图表，图表带有 `已用 %` 纵轴刻度。
- 支持右键菜单里的“开机自启动”开关，使用 macOS 原生登录项能力。
- 提供原创透明 app icon，并打包进 release app bundle。
- 所有界面文案会根据系统语言在中文和英文之间自动切换。

### 数据与隐私

应用会读取当前 Codex 登录态中的 access token 和 account id，然后请求：

```text
https://chatgpt.com/backend-api/wham/usage
```

本地历史记录保存到：

```text
~/Library/Application Support/CodexQuotaBar/usage-history.json
```

历史记录只保存额度百分比、重置时间和哈希后的账号 key，不保存 Codex token。

### 构建

SwiftUI/AppKit 版本需要完整 Xcode，不能只装 Command Line Tools。

```sh
./Scripts/build.sh
```

构建产物是 Intel + Apple Silicon 通用 app：

```text
outputs/CodexQuotaBar.app
```

### 运行

```sh
open outputs/CodexQuotaBar.app
```

命令行只检查一次额度：

```sh
outputs/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --once
```

### 开机自启动

右键点击状态栏图标，在菜单里打开“开机自启动”即可。macOS 可能会要求你在“系统设置 > 登录项”中批准。

如果开关提示找不到登录项，先把 release 里的 `CodexQuotaBar.app` 放进 `/Applications` 后再打开。
