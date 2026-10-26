# Changelog

## 0.2.0

- **Native store flows**: Play Store intent on Android (registered plugin,
  https fallback), native `SKStoreProductViewController` App Store sheet on
  iOS, graceful `unavailable` on web/desktop. New `StoreFlowLauncher`.
- **Direct downloads with progress**: `PrismDownloadManager` streams files
  to disk with progress, throughput, and cancellation; new
  `PrismDownloadScreen` UI with progress bar and cancel button.
- **Skip persistence**: `PrismSkipStore` remembers skipped versions via
  `SharedPreferences`; skipped soft updates surface as
  `PrismUpdateSkipped`; forced updates are never suppressed;
  `checkNow(ignoreSkips: true)` re-shows everything.
- **Staged rollouts**: `UpdatePolicy(rolloutPercent, rolloutDeviceId)`
  deterministically buckets devices (FNV-1a); forced updates ignore the
  rollout.
- 58 tests passing.

## 0.1.0

- Initial release: version parsing, update policy (soft/forced), remote &
  static sources, headless controller, update gate, force/soft update screens.
- Platform support: Android, iOS, web, Windows (macOS/Linux via download URL).
