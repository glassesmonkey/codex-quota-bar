# Codex Quota Bar Roadmap

## 当前阶段

- 稳定性修复：避免异常 usage 响应污染菜单栏额度、历史图表和预测。

## 已完成

- 修复 usage 响应缺少 `primary_window`、`secondary_window` 或 `used_percent` 时误显示 100% 的问题。
- 将 app 版本更新为 v0.1.7，并构建本地 release zip。

## 进行中

- 无。

## 待办

- 等待确认后上传 GitHub Release 产物。

## 阻塞

- 无。

## 最近验证

- 2026-07-09：`./Scripts/build.sh` 通过，生成 `outputs/CodexQuotaBar.app`。
- 2026-07-09：`outputs/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --once` 通过，当前 live 响应可正常解析。
- 2026-07-09：生成 `outputs/CodexQuotaBar-macos-universal-v0.1.7.zip`。
