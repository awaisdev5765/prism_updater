# prism_updater

[![pub package](https://img.shields.io/pub/v/prism_updater.svg)](https://pub.dev/packages/prism_updater)
[![popularity](https://img.shields.io/pub/popularity/prism_updater.svg)](https://pub.dev/packages/prism_updater/score)
[![likes](https://img.shields.io/pub/likes/prism_updater.svg)](https://pub.dev/packages/prism_updater/score)

Cross-platform **in-app update experience for Flutter** — version checks
against any source, force-update and soft-update screens, minimum-version
gating, and a headless controller you can wire into any state management.

**Platforms: Android · iOS · Web · Windows** (macOS and Linux work through
the same direct-download flow as Windows).

| Platform | Update flow |
|---|---|
| Android | Direct APK download URL from your metadata (store flow hook included) |
| iOS | App Store URL |
| Web | Direct link |
| Windows | Direct `.exe` / `.msi` download URL |

Part of the **Prism package family**:
[prism_markdown](https://pub.dev/packages/prism_markdown) ·
[prism_code_view](https://pub.dev/packages/prism_code_view) ·
[prism_adaptive_scaffold](https://pub.dev/packages/prism_adaptive_scaffold) ·
[prism_adaptive_dialog](https://pub.dev/packages/prism_adaptive_dialog) ·
[prism_state_views](https://pub.dev/packages/prism_state_views) ·
[prism_master_detail](https://pub.dev/packages/prism_master_detail) ·
[prism_banner](https://pub.dev/packages/prism_banner) ·
[prism_search](https://pub.dev/packages/prism_search) ·
[prism_toast](https://pub.dev/packages/prism_toast) ·
[prism_pagination](https://pub.dev/packages/prism_pagination) ·
[prism_form](https://pub.dev/packages/prism_form)

---

## Table of contents

- [Why](#why)
- [Quick start](#quick-start)
- [The metadata file](#the-metadata-file)
- [How it works](#how-it-works)
- [Update decisions](#update-decisions)
- [Gate behaviors](#gate-behaviors)
- [Custom UI](#custom-ui)
- [Headless usage](#headless-usage)
- [Channels (beta / alpha)](#channels-beta--alpha)
- [Testing](#testing)
- [Platform notes](#platform-notes)
- [FAQ](#faq)
- [Roadmap](#roadmap)

---

## Why

Every Flutter app needs "check for updates", and every team hand-rolls it:
a hardcoded version string, an alert dialog, a full-screen block, three
different flows for three platforms. Store APIs (`in_app_update`,
`SKStoreProductViewController`) cover only some platforms and are imperative.

`prism_updater` gives you the whole story in one package:

- **One policy object** decides between *up to date*, *optional update*, and
  *forced update*.
- **One controller** exposes that decision as a sealed state — no platform
  channels required for the core flow.
- **Declarative UI** renders the decision and gets out of the way otherwise.
- **Fail-open by design**: if the update check fails (no internet, 500s, bad
  JSON), your app renders normally. An update check must never break the app.

## Quick start

### 1. Host a metadata file

Serve this JSON anywhere — GitHub Pages, S3, Firebase Hosting, your own API:

```json
{
  "latest": { "stable": "2.1.0", "beta": "2.3.0" },
  "minimum": { "stable": "1.5.0" },
  "notes": { "2.1.0": "Bug fixes and a new gate widget." },
  "urls": {
    "android": "https://example.com/releases/app-2.1.0.apk",
    "ios": "https://apps.apple.com/app/id123456789",
    "windows": "https://example.com/releases/App-2.1.0-Setup.exe",
    "web": "https://example.com/download"
  }
}
```

### 2. Wrap your app

```dart
import 'package:prism_updater/prism_updater.dart';

PrismUpdateGate(
  controller: PrismUpdateController(
    source: RemoteUpdateSource(
      url: Uri.parse('https://example.com/updates.json'),
    ),
    currentVersion: PrismVersion.parse('1.4.2'), // your app's version
  ),
  child: const MyApp(),
)
```

That's it:

- Installed `1.2.0` → **forced** update screen (below the `1.5.0` minimum)
- Installed `1.4.2` → **soft** update screen (latest is `2.1.0`)
- Installed `2.1.0` → nothing changes

### 3. Where do I get the current version?

Pass it from `package_info_plus` (or your own config):

```dart
final info = await PackageInfo.fromPlatform();
final current = PrismVersion.parse(info.version); // e.g. "1.4.2"
```

## The metadata file

| Field | Type | Required | Description |
|---|---|---|---|
| `latest` | `Map<String, String>` | ✅ | Latest version per channel: `stable`, `beta`, `alpha` |
| `minimum` | `Map<String, String>` | — | Force-update floor per channel. Users below it are blocked |
| `notes` | `Map<String, String>` | — | Release notes keyed by version, shown on update screens |
| `urls` | `Map<String, String>` | — | Download/store URL per platform key: `android`, `ios`, `windows`, `web`, `macos`, `linux` |

Keys not relevant to your setup can be omitted. Unknown platform keys are
ignored, so you can extend the schema freely.

## How it works

```
PrismUpdateSource          UpdatePolicy            PrismUpdateController        UI
┌────────────────┐ fetch  ┌──────────┐  evaluate  ┌─────────────────────┐      ┌──────────────────┐
│ Remote (HTTP)  │ ─────▶ │ latest?  │ ─────────▶ │ sealed state        │ ───▶ │ Gate / screens / │
│ Static (tests) │        │ minimum? │            │ Idle/Checking/      │      │ your builders    │
└────────────────┘        └──────────┘            │ UpToDate/Available/ │      └──────────────────┘
                                                  │ Failure             │
                                                  └─────────────────────┘
```

1. **`PrismUpdateSource`** fetches the latest version per channel.
2. **`UpdatePolicy`** compares the running version against the latest and the
   configured minimum.
3. **`PrismUpdateController`** (a `ChangeNotifier`) emits one of five states.
4. **`PrismUpdateGate`** renders the right experience — or your custom
   builders.

## Update decisions

`UpdatePolicy.evaluate` returns an `UpdatePolicyResult` with one of three
decisions, in priority order:

| Decision | When | Default UI |
|---|---|---|
| `forcedUpdate` | Current version < `minimumVersion` | Non-dismissable full screen |
| `softUpdate` | Current version < latest | Block page *or* dismissible banner card |
| `upToDate` | Current version >= latest | Nothing — your app renders |

Force-update always wins over soft-update, even when the latest version
equals the current one.

## Gate behaviors

```dart
PrismUpdateGate(
  controller: controller,
  behavior: GateBehavior.block, // default: soft updates take over the screen
  // behavior: GateBehavior.banner, // soft updates as a dismissible card over your app
  child: app,
)
```

- **`GateBehavior.block`** — soft updates show a full-screen page with a
  "Maybe later" skip action. Good for important releases.
- **`GateBehavior.banner`** — soft updates show a floating dismissible card
  at the bottom of the screen while the app stays fully usable. Good for
  routine releases.

Forced updates always block regardless of behavior.

## Custom UI

Every default screen can be replaced:

```dart
PrismUpdateGate(
  controller: controller,
  forcedBuilder: (context) => MyBrandedForceUpdateScreen(
    state: controller.state as PrismUpdateAvailable,
  ),
  softUpdateBuilder: (context) => MyUpdateNudge(),
  checkingBuilder: (context) => MySplashLikeLoader(),
  failureBuilder: (context) => child, // default: keep the app running
  child: app,
)
```

The default widgets are also usable standalone:

- `PrismForceUpdateScreen` — full-screen update page (`canDismiss: true` adds
  a skip action)
- `PrismSoftUpdateCard` — compact dismissible card
- `PrismUpdateProgress` — checking indicator
- `PrismUpdateStatusView` — one-line human-readable state summary, handy for
  debug pages

## Headless usage

The controller is a plain `ChangeNotifier`, so it works with anything:

```dart
final controller = PrismUpdateController(
  source: RemoteUpdateSource(url: metadataUrl),
  currentVersion: current,
  autoCheck: false, // check manually, e.g. on app resume
);

await controller.checkNow();

switch (controller.state) {
  case PrismUpdateIdle():
    break; // not checked yet
  case PrismUpdateChecking():
    break; // in flight
  case PrismUpdateUpToDate():
    break; // nothing to do
  case PrismUpdateAvailable(:final result, :final notes):
    if (result.isForced) { /* block */ } else { /* nudge */ }
  case PrismUpdateFailure(:final error):
    break; // log and continue — the app still works
}
```

You can also skip the controller entirely and drive your own state from
`source` + `policy`:

```dart
final latest = await RemoteUpdateSource(url: metadataUrl).fetchLatest();
final decision = policy.evaluate(current, latest).decision;
```

## Channels (beta / alpha)

The source returns a version per channel. The policy only considers the
channels you enable:

```dart
const policy = UpdatePolicy(
  channels: {UpdateChannel.stable, UpdateChannel.beta},
);
```

Builds can pick their channel at runtime (flavor, compile-time constant, or
remote config). The latest version across *enabled* channels wins; disabled
channels are ignored, so beta users aren't dragged onto alpha releases.

## Testing

`StaticUpdateSource` makes the entire pipeline deterministic:

```dart
test('forced update below minimum', () async {
  final controller = PrismUpdateController(
    source: StaticUpdateSource({
      UpdateChannel.stable: PrismVersion.parse('2.0.0'),
    }),
    policy: UpdatePolicy(minimumVersion: PrismVersion.parse('1.5.0')),
    currentVersion: PrismVersion.parse('1.0.0'),
    autoCheck: false,
  );
  await controller.checkNow();

  final state = controller.state as PrismUpdateAvailable;
  expect(state.isForced, isTrue);
});
```

`RemoteUpdateSource` accepts a custom `http.Client` — pair it with
`MockClient` from `package:http/testing.dart` for HTTP-level tests.

## Platform notes

**Android** — the `urls.android` entry can be a Play Store link or a direct
APK URL. The default action button opens it with an external browser intent.

**iOS** — point `urls.ios` at your App Store page. SKStoreProductViewController
integration (native sheet without leaving the app) is on the roadmap.

**Web** — `urls.web` is opened in a new tab. There is no "install" concept on
the web, so the flow is a simple call-to-action.

**Windows** — point `urls.windows` at your installer. The button opens the
default browser. Auto-download + progress reporting is on the roadmap.

**Platform key resolution** — `PrismUpdatePlatformInfo.detect()` maps the
running platform to one of `web`, `android`, `ios`, `windows`, `macos`,
`linux`, which is used to pick the URL from the metadata. You can override it
for tests or unusual setups by passing `platformInfo`.

## FAQ

**Does the check run on every app launch?**
Yes, by default (`autoCheck: true`). Set `autoCheck: false` and call
`checkNow()` whenever you want — on resume, from a drawer action, etc.

**What happens offline?**
The check fails and the gate renders your app normally. Optionally provide a
`failureBuilder` to show a subtle indicator.

**Can I force-update everyone instantly (kill switch)?**
Yes — set `minimum` in the metadata to your latest version. Every older
build blocks on next launch. No app update required.

**Does this upload anything / track users?**
No. The package makes one HTTP GET to the endpoint you configure and nothing
else.

**Where are my dismissed soft updates remembered?**
Version-skipping persistence is on the roadmap (see below). Until then,
banner dismissal lasts for the current session.

## Roadmap

- [ ] Native store flows (`in_app_update` on Android, App Store sheet on iOS)
- [ ] Download progress reporting for direct downloads
- [ ] Per-version skip persistence
- [ ] Staged rollout percentage support in the policy

## Contributing

PRs welcome! Please make sure `flutter analyze` and `flutter test` pass.

## License

MIT — see [LICENSE](LICENSE).
