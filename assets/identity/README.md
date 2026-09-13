# NetTracker Identity — v3 WiFi (locked)

Concept: classic WiFi dot + arcs, outer arc launches into one upward arrow.
Live throughput + connection. Apple blue (`#0A84FF` → cyan) on white squircle.

## Source of truth

- `original/nettracker-wifi-v3-raw-2048.png` — AI master render (2048×2048).
- `appicon/AppIcon-1024.png` — cleaned white-square master.
  `scripts/generate_assets.py` prefers this file, falling back to `original/`.

## Derived sources (checked in for review)

- `appicon/AppIcon-{512,256,128,64,32}.png` — scaled previews of the 1024 master.
- `menubar/MenuBar-template-{512,64,44,36}.png` — black silhouette on
  transparent (template). Rebuilt from blue-channel mask.
  Not bundled yet — `MenuBarStatusView` still uses SF Symbols (`wifi` /
  `wifi.slash`). Verify 36px legibility in situ before wiring into Xcode.

## Generated outputs (do not edit by hand)

Regenerate with:

```sh
make assets
# or: python3 scripts/generate_assets.py
```

- `assets/logo.png` + `macos/NetTracker/Resources/logo.png` (identical copy) —
  transparent full-color WiFi mark for README, docs & Settings → About.
- `assets/app-icon.png` — 1024×1024 macOS squircle App Icon
  (transparent canvas + shadow), also shown in README header.
- `macos/NetTracker/Resources/AppIcon.icns` — multi-res bundle icon
  (built via `iconutil`).
- `assets/dmg-background.png` + `assets/dmg-background@2x.png` — installer
  background with Apple-blue accents.

## History

- v3 (current): Apple-blue WiFi + upward arrow. Old teal `nettracker-logo.jpeg`
  source was removed; all outputs are regenerated from this folder.
