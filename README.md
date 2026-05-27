# SKtimer

SKtimer is a small native macOS timer for focused work, breaks, and long-running personal countdowns. It is fully offline, stores data locally, and keeps the next finishing timer visible in the menu bar.

SKtimer 是一个轻量的原生 macOS 倒计时工具，适合专注、休息和长时间个人计时。它完全离线运行，数据只保存在本机，并可在菜单栏显示下一个即将结束的倒计时。

## Features

- Fully offline: no account, network calls, analytics, ads, or tracking.
- Multiple simultaneous timers.
- Hour/minute input with minute precision.
- Recent duration shortcuts with a six-item MRU list.
- Pause, resume, restart, and delete for each timer.
- Menu bar countdown for the next finishing running timer.
- Local macOS notifications with system or custom sound.
- Meaningful completion prompt with rolling 24H / Past 7 Days / Past 30 Days totals and charts.
- Restores running timers after relaunch by comparing real elapsed time.
- English and Simplified Chinese localization.

## Requirements

- macOS 14.0 or newer
- Xcode 16 or newer for local development
- Apple Developer Program membership for App Store upload, Developer ID signing, and notarization

## Build and Run

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

## Release

The release script creates an App Store export and GitHub release artifacts:

```bash
./script/release.sh
```

Expected outputs:

- `dist/archives/SKtimer.xcarchive`
- `dist/app-store/`
- `dist/SKtimer.app.zip`
- `dist/SKtimer.pkg`
- `dist/SHA256SUMS.txt`

For notarized outside-the-App-Store distribution, configure:

```bash
export NOTARYTOOL_PROFILE="Your notarytool keychain profile"
export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
./script/release.sh
```

The Xcode project uses automatic signing. The App Store export requires an Apple Distribution signing setup. The Developer ID export requires a Developer ID Application certificate. The installer package should be signed with a Developer ID Installer certificate.

## App Store Metadata

Prepared metadata lives in `metadata/app_store/`.

- Category: Productivity
- Price: Free
- Age Rating: 4+
- Privacy: Data Not Collected
- English subtitle: Offline menu bar timer
- Simplified Chinese subtitle: 离线菜单栏倒计时

## Privacy

SKtimer does not collect data. Timers, recent durations, completion answers, meaningful time totals, and preferences are stored locally on the user's Mac. See `PRIVACY.md`.

## License

MIT. See `LICENSE`.
