import 'package:flutter_test/flutter_test.dart';
import 'package:prism_updater/prism_updater.dart';
import 'package:prism_updater/src/skip_store.dart';

void main() {
  group('UpdatePolicy rollout', () {
    PrismVersion v(String s) => PrismVersion.parse(s);

    test('rolloutPercent 100 includes everyone', () {
      const policy = UpdatePolicy(rolloutPercent: 100);
      final result = policy.evaluate(
        v('1.0.0'),
        {UpdateChannel.stable: v('2.0.0')},
      );
      expect(result.decision, UpdateDecision.softUpdate);
    });

    test('rolloutPercent 0 excludes everyone from soft updates', () {
      const policy = UpdatePolicy(rolloutPercent: 0, rolloutDeviceId: 'a');
      final result = policy.evaluate(
        v('1.0.0'),
        {UpdateChannel.stable: v('2.0.0')},
      );
      expect(result.decision, UpdateDecision.upToDate);
      // Latest is still reported for informational purposes.
      expect(result.latest, v('2.0.0'));
    });

    test('rollout assignment is deterministic per device', () {
      // The same device id must always land in the same bucket.
      final buckets = <int>{};
      for (var i = 0; i < 50; i++) {
        final policy = UpdatePolicy(
          rolloutPercent: 50,
          rolloutDeviceId: 'device-$i',
        );
        final result = policy.evaluate(
          v('1.0.0'),
          {UpdateChannel.stable: v('2.0.0')},
        );
        buckets.add(result.decision.index);
        // Re-evaluating with the same id gives the same decision.
        final again = UpdatePolicy(
          rolloutPercent: 50,
          rolloutDeviceId: 'device-$i',
        ).evaluate(v('1.0.0'), {UpdateChannel.stable: v('2.0.0')});
        expect(again.decision, result.decision);
      }
      // With 50 distinct devices at 50%, we should see both decisions.
      expect(buckets.length, 2);
    });

    test('roughly respects the rollout percentage', () {
      var included = 0;
      const total = 1000;
      for (var i = 0; i < total; i++) {
        final policy = UpdatePolicy(
          rolloutPercent: 30,
          rolloutDeviceId: 'device-$i',
        );
        final result = policy.evaluate(
          v('1.0.0'),
          {UpdateChannel.stable: v('2.0.0')},
        );
        if (result.decision == UpdateDecision.softUpdate) included++;
      }
      // FNV-1a buckets should land within a few percent of 30%.
      expect(included / total, greaterThan(0.25));
      expect(included / total, lessThan(0.35));
    });

    test('forced updates ignore rollout gating', () {
      final policy = UpdatePolicy(
        minimumVersion: PrismVersion.parse('1.5.0'),
        rolloutPercent: 0,
        rolloutDeviceId: 'a',
      );
      final result = policy.evaluate(
        v('1.0.0'),
        {UpdateChannel.stable: v('2.0.0')},
      );
      expect(result.decision, UpdateDecision.forcedUpdate);
    });

    test('null device id is always included', () {
      const policy = UpdatePolicy(rolloutPercent: 1);
      final result = policy.evaluate(
        v('1.0.0'),
        {UpdateChannel.stable: v('2.0.0')},
      );
      expect(result.decision, UpdateDecision.softUpdate);
    });
  });

  group('PrismSkipStore', () {
    late PrismSkipStore store;

    setUp(() {
      store = PrismSkipStore(backend: MemoryBackend());
    });

    test('skip and isSkipped roundtrip', () async {
      final version = PrismVersion.parse('2.0.0');
      expect(await store.isSkipped(version), isFalse);
      await store.skip(version);
      expect(await store.isSkipped(version), isTrue);
    });

    test('clearSkip removes the record', () async {
      final version = PrismVersion.parse('2.0.0');
      await store.skip(version);
      await store.clearSkip(version);
      expect(await store.isSkipped(version), isFalse);
    });

    test('different versions are tracked independently', () async {
      await store.skip(PrismVersion.parse('2.0.0'));
      expect(
        await store.isSkipped(PrismVersion.parse('2.1.0')),
        isFalse,
      );
    });

    test('markSeen / seenAt roundtrip', () async {
      final version = PrismVersion.parse('2.0.0');
      expect(await store.seenAt(version), isNull);
      final at = DateTime(2026, 1, 15, 12);
      await store.markSeen(version, at: at);
      expect(await store.seenAt(version), at);
    });

    test('reset clears everything', () async {
      final version = PrismVersion.parse('2.0.0');
      await store.skip(version);
      await store.markSeen(version);
      await store.reset();
      expect(await store.isSkipped(version), isFalse);
      expect(await store.seenAt(version), isNull);
    });
  });

  group('PrismUpdateController with skip store', () {
    test('soft update previously skipped reports Skipped state', () async {
      final skipStore = PrismSkipStore(backend: MemoryBackend());
      final latest = PrismVersion.parse('2.0.0');
      await skipStore.skip(latest);

      final controller = PrismUpdateController(
        source: StaticUpdateSource({UpdateChannel.stable: latest}),
        currentVersion: PrismVersion.parse('1.0.0'),
        autoCheck: false,
        skipStore: skipStore,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateSkipped>());
      controller.dispose();
    });

    test('forced updates are never suppressed by skips', () async {
      final skipStore = PrismSkipStore(backend: MemoryBackend());
      final latest = PrismVersion.parse('2.0.0');
      await skipStore.skip(latest);

      final controller = PrismUpdateController(
        source: StaticUpdateSource({UpdateChannel.stable: latest}),
        policy: UpdatePolicy(minimumVersion: PrismVersion.parse('1.5.0')),
        currentVersion: PrismVersion.parse('1.0.0'),
        autoCheck: false,
        skipStore: skipStore,
      );
      await controller.checkNow();
      final state = controller.state;
      expect(state, isA<PrismUpdateAvailable>());
      expect((state as PrismUpdateAvailable).isForced, isTrue);
      controller.dispose();
    });

    test('ignoreSkips re-checks and shows the update', () async {
      final skipStore = PrismSkipStore(backend: MemoryBackend());
      final latest = PrismVersion.parse('2.0.0');
      await skipStore.skip(latest);

      final controller = PrismUpdateController(
        source: StaticUpdateSource({UpdateChannel.stable: latest}),
        currentVersion: PrismVersion.parse('1.0.0'),
        autoCheck: false,
        skipStore: skipStore,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateSkipped>());

      await controller.checkNow(ignoreSkips: true);
      expect(controller.state, isA<PrismUpdateAvailable>());
      controller.dispose();
    });

    test('skipCurrentUpdate records and emits Skipped', () async {
      final skipStore = PrismSkipStore(backend: MemoryBackend());
      final latest = PrismVersion.parse('2.0.0');

      final controller = PrismUpdateController(
        source: StaticUpdateSource({UpdateChannel.stable: latest}),
        currentVersion: PrismVersion.parse('1.0.0'),
        autoCheck: false,
        skipStore: skipStore,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateAvailable>());

      await controller.skipCurrentUpdate();
      expect(controller.state, isA<PrismUpdateSkipped>());
      expect(await skipStore.isSkipped(latest), isTrue);
      controller.dispose();
    });

    test('clearSkipAndRecheck clears and re-reports availability', () async {
      final skipStore = PrismSkipStore(backend: MemoryBackend());
      final latest = PrismVersion.parse('2.0.0');
      await skipStore.skip(latest);

      final controller = PrismUpdateController(
        source: StaticUpdateSource({UpdateChannel.stable: latest}),
        currentVersion: PrismVersion.parse('1.0.0'),
        autoCheck: false,
        skipStore: skipStore,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateSkipped>());

      await controller.clearSkipAndRecheck(latest);
      expect(controller.state, isA<PrismUpdateAvailable>());
      controller.dispose();
    });

    test('no skip store behaves as before', () async {
      final controller = PrismUpdateController(
        source: StaticUpdateSource({
          UpdateChannel.stable: PrismVersion.parse('2.0.0'),
        }),
        currentVersion: PrismVersion.parse('1.0.0'),
        autoCheck: false,
      );
      await controller.checkNow();
      expect(controller.state, isA<PrismUpdateAvailable>());
      controller.dispose();
    });
  });
}
