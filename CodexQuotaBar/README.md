# Codex Quota Bar

A small native macOS menu bar app for watching Codex quota usage from `~/.codex/auth.json`.

It reads the current Codex access token and account id, calls `https://chatgpt.com/backend-api/wham/usage`, and shows the 5-hour and 7-day remaining quota in the menu bar. The popover shows reset times, plan, account metadata, refresh status, and quick actions.

The app stores local quota history at:

```text
~/Library/Application Support/CodexQuotaBar/usage-history.json
```

History records contain quota percentages, reset timestamps, and a hashed account key. They do not store Codex tokens.

The planning forecast uses the 7-day usage trend for depletion timing and the 5-hour window as a burst-pressure signal. It ignores reset drops, filters implausible spikes, weights recent samples more heavily, and falls back to a low-confidence current-cycle estimate until enough history exists.

## Build

```sh
./CodexQuotaBar/Scripts/build.sh
```

The script builds a universal Intel + Apple Silicon app at:

```text
outputs/CodexQuotaBar.app
```

## Run

```sh
open outputs/CodexQuotaBar.app
```

For a terminal-only quota check:

```sh
outputs/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --once
```
