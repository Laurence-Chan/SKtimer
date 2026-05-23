# Contributing

Thanks for helping improve SKtimer.

## Development

```bash
./script/build_and_run.sh
```

Run tests with:

```bash
xcodebuild -project SKtimer.xcodeproj -scheme SKtimer -destination "platform=macOS" test
```

## Guidelines

- Keep SKtimer fully offline.
- Do not add analytics, tracking, advertising, accounts, or network dependencies.
- Keep UI strings localized in English and Simplified Chinese.
- Keep timer logic covered by tests when changing behavior.
- Prefer native SwiftUI and AppKit system services over third-party dependencies.

## Release Work

Release signing, notarization, and App Store upload require Apple Developer credentials. Do not commit private keys, API keys, provisioning profiles, or notarization credentials.
