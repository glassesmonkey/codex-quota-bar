# Codex Quota Bar Roadmap

## 当前阶段

- 稳定性修复：兼容 usage 接口动态增减额度窗口。

## 已完成

- 修复 usage 响应缺少 `primary_window`、`secondary_window` 或 `used_percent` 时误显示 100% 的问题。
- 将 app 版本更新为 v0.1.7，并构建本地 release zip。
- 发布 GitHub Release v0.1.7，并上传通用 macOS zip 产物。
- 按 `limit_window_seconds` 识别短周期与周额度，兼容只返回单个周窗口且字段位置变化的响应。
- 缺失 5 小时窗口时，菜单栏、概览、预测和 `--once` 不再显示空卡片、未知压力或伪造的 0%。
- 将 app 版本更新为 v0.1.8。
- 将菜单栏额度文字前的系统终端图标替换为可跟随浅色/深色菜单栏的单色云形终端图标。
- 将 app 版本更新为 v0.1.9，并生成本地通用架构安装包。

## 进行中

- 无。

## 待办

- 无。

## 阻塞

- 无。

## 最近验证

- 2026-07-13：并行启动 v0.1.9 验证实例并截图确认，单色云形图标在深色菜单栏中显示、尺寸及文字间距正常；验证后仅关闭新实例。
- 2026-07-13：生成 `outputs/CodexQuotaBar-macos-universal-v0.1.9.zip`，压缩完整性、应用签名及 `x86_64 arm64` 架构验证通过。
- 2026-07-13：生成 `outputs/CodexQuotaBar-macos-universal-v0.1.8.zip`，压缩完整性、应用签名及 `x86_64 arm64` 架构验证通过。
- 2026-07-13：`./Scripts/build.sh` 通过，生成 v0.1.8 通用架构 `outputs/CodexQuotaBar.app`。
- 2026-07-13：live `--once` 通过；仅返回的 7 天窗口被识别为周额度，历史采样和预测恢复工作。
- 2026-07-13：首次 live 验证确认周窗口已迁移至 `primary_window`，不能继续依赖字段位置判断窗口语义。
- 2026-07-09：`./Scripts/build.sh` 通过，生成 `outputs/CodexQuotaBar.app`。
- 2026-07-09：`outputs/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --once` 通过，当前 live 响应可正常解析。
- 2026-07-09：生成 `outputs/CodexQuotaBar-macos-universal-v0.1.7.zip`。
- 2026-07-09：GitHub Release v0.1.7 发布成功，资产 `CodexQuotaBar-macos-universal-v0.1.7.zip` 状态为 `uploaded`。
