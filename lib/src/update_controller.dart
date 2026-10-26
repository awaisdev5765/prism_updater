import 'dart:async';

import 'package:flutter/foundation.dart';

import 'skip_store.dart';
import 'update_platform.dart';
import 'update_policy.dart';
import 'update_source.dart';
import 'version.dart';

/// Sealed states emitted by [PrismUpdateController].
sealed class PrismUpdateState {
  const PrismUpdateState();
}

/// No check has run yet.
class PrismUpdateIdle extends PrismUpdateState {
  /// Creates an idle state.
  const PrismUpdateIdle();
}

/// A check is in flight.
class PrismUpdateChecking extends PrismUpdateState {
  /// Creates a checking state.
  const PrismUpdateChecking();
}

/// The installed version satisfies the policy.
class PrismUpdateUpToDate extends PrismUpdateState {
  /// Creates an up-to-date state.
  const PrismUpdateUpToDate({this.latest});

  /// Latest known version, when known.
  final PrismVersion? latest;
}

/// An update is available (soft or forced per the policy).
class PrismUpdateAvailable extends PrismUpdateState {
  /// Creates an update-available state.
  const PrismUpdateAvailable({
    required this.current,
    required this.result,
    this.downloadUrl,
    this.notes,
  });

  /// The version currently installed.
  final PrismVersion current;

  /// Full policy evaluation result.
  final UpdatePolicyResult result;

  /// Direct download URL on platforms without a store flow.
  final Uri? downloadUrl;

  /// Release notes for the latest version, when available.
  final String? notes;

  /// Whether the update is mandatory.
  bool get isForced => result.isForced;

  /// The latest version being offered.
  PrismVersion? get latest => result.latest;
}

/// The check ran, but the available soft update was previously skipped.
class PrismUpdateSkipped extends PrismUpdateState {
  /// Creates a skipped state.
  const PrismUpdateSkipped({required this.available});

  /// The available update that was skipped.
  final PrismUpdateAvailable available;

  /// Convenience accessors.
  PrismVersion? get latest => available.latest;
}

/// The check failed.
class PrismUpdateFailure extends PrismUpdateState {
  /// Creates a failure state.
  const PrismUpdateFailure(this.error, [this.stackTrace]);

  /// The error that caused the failure.
  final Object error;

  /// Optional stack trace.
  final StackTrace? stackTrace;
}

/// Headless controller that checks versions and exposes an update state.
///
/// Platform-agnostic: works on Android, iOS, web, and Windows. The UI layer
/// ([PrismUpdateGate], [PrismForceUpdateScreen], [PrismSoftUpdateCard])
/// renders whatever this controller reports.
///
/// When a [skipStore] is provided, previously skipped soft updates are
/// reported as [PrismUpdateSkipped] instead of [PrismUpdateAvailable] —
/// forced updates are never suppressed.
class PrismUpdateController extends ChangeNotifier {
  /// Creates a controller.
  PrismUpdateController({
    required PrismUpdateSource source,
    this.policy = const UpdatePolicy(),
    required this.currentVersion,
    PrismUpdatePlatformInfo? platformInfo,
    this.autoCheck = true,
    PrismSkipStore? skipStore,
  })  : _source = source,
        _skipStore = skipStore,
        platformInfo = platformInfo ?? PrismUpdatePlatformInfo.detect() {
    if (autoCheck) {
      scheduleMicrotask(checkNow);
    }
  }

  /// Source used to fetch the latest versions.
  final PrismUpdateSource _source;

  /// Policy used to evaluate decisions.
  final UpdatePolicy policy;

  /// Version of the currently running app.
  final PrismVersion currentVersion;

  /// Platform information used for URL and flow selection.
  final PrismUpdatePlatformInfo platformInfo;

  /// Whether a check runs automatically on construction.
  final bool autoCheck;

  final PrismSkipStore? _skipStore;

  PrismUpdateState _state = const PrismUpdateIdle();
  int _generation = 0;

  /// The current state.
  PrismUpdateState get state => _state;

  /// Runs a version check and updates [state].
  Future<void> checkNow({bool ignoreSkips = false}) async {
    final generation = ++_generation;
    _set(const PrismUpdateChecking());
    try {
      final latest = await _source.fetchLatest();
      if (generation != _generation) return;
      final result = policy.evaluate(currentVersion, latest);
      final remote = switch (_source) {
        RemoteUpdateSource remote => remote,
        _ => null,
      };
      final downloadUrl =
          remote?.downloadUrlFor(platformInfo.key);
      final notes = remote?.notesFor(result.latest ?? currentVersion);

      final PrismUpdateState next;
      if (result.isUpdateAvailable) {
        final available = PrismUpdateAvailable(
          current: currentVersion,
          result: result,
          downloadUrl: downloadUrl,
          notes: notes,
        );
        final latestVersion = result.latest;
        final skipped = !ignoreSkips &&
            !result.isForced &&
            latestVersion != null &&
            await (_skipStore?.isSkipped(latestVersion) ??
                Future.value(false));
        next = skipped ? PrismUpdateSkipped(available: available) : available;
      } else {
        next = PrismUpdateUpToDate(latest: result.latest);
      }
      _set(next);
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      _set(PrismUpdateFailure(error, stackTrace));
    }
  }

  /// Marks the currently offered soft update as skipped.
  ///
  /// Future checks (until the version changes or the skip is cleared) will
  /// report [PrismUpdateSkipped] instead of [PrismUpdateAvailable].
  Future<void> skipCurrentUpdate() async {
    final state = _state;
    if (state is! PrismUpdateAvailable || state.isForced) return;
    final latest = state.latest;
    if (latest == null) return;
    await _skipStore?.skip(latest);
    _set(PrismUpdateSkipped(available: state));
  }

  /// Clears the skip for [version] and re-checks.
  Future<void> clearSkipAndRecheck(PrismVersion version) async {
    await _skipStore?.clearSkip(version);
    await checkNow(ignoreSkips: false);
  }

  void _set(PrismUpdateState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
