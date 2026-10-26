import 'version.dart';

/// Deterministic hash of a device/installation identifier for staged
/// rollouts. Same input always yields the same bucket.
int _stableBucket(String deviceId) {
  var hash = 0xcbf29ce4;
  for (final code in deviceId.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash % 100;
}

/// Update channel a release belongs to.
enum UpdateChannel {
  /// Stable public releases.
  stable,

  /// Beta channel — receives releases earlier.
  beta,

  /// Alpha/nightly channel.
  alpha,
}

/// What the policy decided the app should do.
enum UpdateDecision {
  /// Current version satisfies the policy; nothing to show.
  upToDate,

  /// A newer version exists but updating is optional.
  softUpdate,

  /// The current version is below the minimum; updating is required.
  forcedUpdate,
}

/// The result of evaluating an update policy.
class UpdatePolicyResult {
  /// Creates a policy result.
  const UpdatePolicyResult(this.decision, {this.latest, this.minimum});

  /// The decision reached.
  final UpdateDecision decision;

  /// The latest available version, when known.
  final PrismVersion? latest;

  /// The minimum supported version, when known.
  final PrismVersion? minimum;

  /// Whether a forced update is required.
  bool get isForced => decision == UpdateDecision.forcedUpdate;

  /// Whether an update is available (soft or forced).
  bool get isUpdateAvailable => decision != UpdateDecision.upToDate;
}

/// Decides whether the running app should update.
///
/// Extend or compose this to plug in custom rules (staged rollouts, kill
/// switches, per-country gating, etc.).
class UpdatePolicy {
  /// Creates a policy.
  const UpdatePolicy({
    this.minimumVersion,
    this.channels = const {UpdateChannel.stable},
    this.rolloutPercent = 100,
    this.rolloutDeviceId,
  });

  /// Builds a policy from a remote configuration map, e.g.:
  ///
  /// ```json
  /// {
  ///   "latest": {"stable": "2.1.0", "beta": "2.2.0-beta.1"},
  ///   "minimum": {"stable": "1.9.0"}
  /// }
  /// ```
  factory UpdatePolicy.fromJson(Map<String, dynamic> json) {
    final latestMap = (json['latest'] as Map<String, dynamic>?) ?? const {};
    final minimumMap = (json['minimum'] as Map<String, dynamic>?) ?? const {};
    final minimumForStable = minimumMap['stable'] as String?;
    return UpdatePolicy(
      minimumVersion:
          minimumForStable == null ? null : PrismVersion.parse(minimumForStable),
      channels: {
        for (final channel in UpdateChannel.values)
          if (latestMap.containsKey(channel.name)) channel,
      },
    );
  }

  /// Below this version an update is forced. `null` disables forced updates.
  final PrismVersion? minimumVersion;

  /// Channels considered when resolving the latest version.
  final Set<UpdateChannel> channels;

  /// Percentage of devices (0–100) that see a soft update during a staged
  /// rollout. Forced updates ignore the rollout and always apply.
  ///
  /// Assignment is deterministic: the same [rolloutDeviceId] always gets the
  /// same bucket, so devices don't flip between check runs.
  final int rolloutPercent;

  /// Device/installation identifier used for rollout bucketing. When null,
  /// rollout gating treats the device as included (useful for tests).
  final String? rolloutDeviceId;

  /// Evaluates [current] against the policy using the latest known
  /// version per channel in [latestByChannel].
  UpdatePolicyResult evaluate(
    PrismVersion current,
    Map<UpdateChannel, PrismVersion> latestByChannel,
  ) {
    final candidates = [
      for (final channel in channels) ...[
        ?latestByChannel[channel],
      ],
    ];
    if (candidates.isEmpty) {
      return const UpdatePolicyResult(UpdateDecision.upToDate);
    }
    final latest = candidates.reduce(
      (a, b) => a >= b ? a : b,
    );

    final minimum = minimumVersion;
    if (minimum != null && current < minimum) {
      return UpdatePolicyResult(
        UpdateDecision.forcedUpdate,
        latest: latest,
        minimum: minimum,
      );
    }
    if (current < latest) {
      // Staged rollout: only the selected percentage of devices sees the
      // soft update. Forced updates below the minimum have already returned.
      final included = rolloutPercent >= 100 || _isIncludedInRollout();
      if (!included) {
        return UpdatePolicyResult(
          UpdateDecision.upToDate,
          latest: latest,
          minimum: minimum,
        );
      }
      return UpdatePolicyResult(
        UpdateDecision.softUpdate,
        latest: latest,
        minimum: minimum,
      );
    }
    return UpdatePolicyResult(
      UpdateDecision.upToDate,
      latest: latest,
      minimum: minimum,
    );
  }

  bool _isIncludedInRollout() {
    final deviceId = rolloutDeviceId;
    if (deviceId == null || deviceId.isEmpty) return true;
    return _stableBucket(deviceId) < rolloutPercent;
  }
}
