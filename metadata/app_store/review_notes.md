# App Review Notes

Screen recording:
Attach the screen recording in App Store Connect before submitting. It should be captured on a physical Mac mini (M4, Mac16,10) running macOS 26.5 (25F71), the latest macOS release available at the time of testing. The recording should start with launching SKtimer and show the main flow: notification permission prompt if macOS shows it, creating a timer, pausing/resuming, using recent duration shortcuts, menu bar countdown, opening Settings, timer completion, the meaningful-time prompt, and the 24H / Past 7 Days / Past 30 Days stats.

Tested devices and operating systems:
- Mac mini (M4, Mac16,10), macOS 26.5 (25F71)

Purpose and target audience:
SKtimer is a lightweight native macOS timer for people who want a quiet, local, and reliable countdown tool for focused work, breaks, and long-running personal timers. It solves the need for a simple timer that stays visible in the macOS menu bar, supports multiple simultaneous timers, restores running timers after relaunch, and keeps local meaningful-time totals after timers finish.

Setup and access instructions:
- No account, login, demo credentials, subscription, in-app purchase, sample files, or network setup are required.
- Launch SKtimer.
- If macOS asks for notification permission, allow notifications to test timer completion alerts. The app can still run timers without notification permission; it falls back to an in-app/system sound when needed.
- Enter hours and/or minutes, then start a timer.
- Use the timer row controls to pause, resume, restart, or delete a timer.
- Start more than one timer to test simultaneous timers.
- Use recent duration shortcuts after at least one timer has been started.
- Check the menu bar item to see the next finishing running timer and to start recent timers from the menu.
- Open Settings from the toolbar or menu bar item to toggle menu bar display, request/open notification settings, preview the system sound, or choose a local audio file as a custom notification sound.
- When a timer completes, answer the prompt asking whether the time was meaningful. A positive answer updates the 24H, Past 7 Days, and Past 30 Days local stats and charts.

External services, tools, or platforms:
- SKtimer does not use external services for its core functionality.
- There are no data providers, authentication services, payment processors, AI services, analytics SDKs, advertising SDKs, crash reporting SDKs, or tracking SDKs.
- The app uses Apple platform frameworks only, including SwiftUI, AppKit, Charts, UserNotifications, NSSound, UserDefaults, and local file access for an optional user-selected notification sound.
- The Settings screen includes a Privacy Policy link to the public GitHub repository, but the app does not require network access to function.

Regional differences:
SKtimer functions consistently across all regions. The app is localized in English and Simplified Chinese based on the user's macOS language settings, but all features and content are the same worldwide.

Regulated industry or protected third-party material:
SKtimer is not in a regulated industry and does not provide medical, financial, legal, gambling, government, or similar regulated services. It does not include protected third-party content. The app icon, UI, text, and functionality are original to this app.

Privacy and permissions:
- Privacy category: Data Not Collected.
- The app is fully offline and stores timer records, recent durations, meaningful-time answers/statistics, menu bar preferences, notification status, and optional custom notification sound files locally on the user's Mac.
- Local notification permission is requested so SKtimer can alert the user when a timer completes.
- Optional user-selected file access is used only when the user chooses a local audio file for a custom notification sound; the selected file is copied into local app storage and is not transmitted.
- Network access: none for core functionality.
- In-app purchases: none.
- Ads or analytics: none.
