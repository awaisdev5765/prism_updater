import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// How the native store flow launched.
enum StoreLaunchResult {
  /// The native store UI (or store page) was opened.
  launched,

  /// The platform cannot open a store flow (web/desktop) or the package
  /// identifier is missing.
  unavailable,

  /// The native side reported a failure (e.g. Play Store missing).
  failed,
}

/// Opens native store flows for updates:
///
/// - **Android**: launches the Play Store page for the running app via the
///   platform `market://` intent — the real store flow, no browser hop.
/// - **iOS**: presents the native `SKStoreProductViewController` sheet for
///   the Apple ID from the metadata, so users never leave the app.
///
/// Web and desktop builds return [StoreLaunchResult.unavailable]; use the
/// direct download flow there instead.
class StoreFlowLauncher {
  /// Creates a launcher. [methodChannel] is injectable for tests.
  StoreFlowLauncher({
    MethodChannel? methodChannel,
    this.iosAppleId,
  }) : _channel = methodChannel ??
            const MethodChannel('prism_updater/store_flow');

  /// The Apple ID (numeric, from `apps.apple.com/app/id…`) used to present
  /// the native App Store product sheet on iOS.
  final String? iosAppleId;

  final MethodChannel _channel;

  /// Launches the native store flow for the current platform.
  Future<StoreLaunchResult> launch() async {
    if (kIsWeb) return StoreLaunchResult.unavailable;
    try {
      final result = await _channel.invokeMethod<String>('launchStore', {
        'appleId': iosAppleId,
      });
      return switch (result) {
        'launched' => StoreLaunchResult.launched,
        'unavailable' => StoreLaunchResult.unavailable,
        _ => StoreLaunchResult.failed,
      };
    } on MissingPluginException {
      // Running in an environment without the native side (e.g. tests,
      // unsupported embedding). Fall back gracefully.
      return StoreLaunchResult.unavailable;
    } on PlatformException {
      return StoreLaunchResult.failed;
    }
  }
}
