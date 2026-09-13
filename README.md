# NetTracker — Native macOS Network Usage Tracker

Lightweight menu-bar utility. Swift/SwiftUI owns the macOS experience;
Go owns measurement, aggregation, persistence, and optional sync.

```
macos/       SwiftUI app (MenuBarExtra, NWPathMonitor, SMAppService)
agent/       Go measurement engine (collector, tracker, IPC, persistence)
protocol/    socket protocol v1 docs
scripts/     build, bundle, sign, notarize
```

## Quick start

```sh
make test        # Run Go unit tests
make lint        # Run golangci-lint
make agent       # Build agent -> build/agent/NetTrackerAgent
make bundle      # Build NetTracker.app (needs full Xcode; else swiftc fallback)
make run         # Bundle, sign, and launch the app in macOS menu bar
```

On this machine only Command Line Tools are installed, so `make bundle`
uses the `swiftc` fallback (`#Preview` blocks are stripped for that path;
they still work in Xcode). For release distribution use full Xcode.

## How it works

- Agent samples aggregate counters every 1s, attributes deltas by real
  elapsed time, re-baselines on gaps > 5s, counter resets, sleep/wake,
  and network path changes.
- State checkpoints to `~/Library/Application Support/NetTracker/history.json`
  about once a minute (dirty-flag) plus on shutdown, via atomic tmp+rename.
- Swift talks to the agent over `agent.sock` (newline JSON, `protocol/schema/v1`).
- UI polls snapshot ~1s; history refreshes periodically. All bytes are
  integer bytes; KB/MB/GB formatting is UI-only.

## Release

```sh
CODE_SIGN_IDENTITY="Developer ID Application: ..." make sign
APPLE_ID=... APPLE_TEAM_ID=... APPLE_APP_PASSWORD=... make notarize
```

## Notes

- Counters are system-wide (`gopsutil` aggregate), not Internet-only.
  The collector is an interface, replaceable with interface-aware accounting.
- Local-first: everything works offline; cloud sync (`agent/internal/sync`)
  is opt-in and disabled by default.
