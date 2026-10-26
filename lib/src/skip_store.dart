import 'package:shared_preferences/shared_preferences.dart';

import 'version.dart';

/// Backing store abstraction so tests can inject an in-memory implementation.
abstract class SkipStoreBackend {
  /// Reads a bool value.
  Future<bool?> getBool(String key);

  /// Writes a bool value.
  Future<void> setBool(String key, bool value);

  /// Reads a string value.
  Future<String?> getString(String key);

  /// Writes a string value.
  Future<void> setString(String key, String value);

  /// Removes a key.
  Future<void> remove(String key);

  /// All stored keys.
  Future<Set<String>> keys();
}

/// [SkipStoreBackend] over [SharedPreferencesAsync].
class AsyncPrefsBackend implements SkipStoreBackend {
  /// Creates a backend.
  AsyncPrefsBackend(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool?> getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<Set<String>> keys() => _prefs.getKeys();
}

/// In-memory [SkipStoreBackend] for tests.
class MemoryBackend implements SkipStoreBackend {
  /// Creates an empty backend.
  MemoryBackend();

  final _values = <String, Object>{};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<Set<String>> keys() async => Set.of(_values.keys);
}

/// Remembers which versions the user has skipped or dismissed, and whether
/// an update screen was seen, using [SharedPreferences].
///
/// Keys are namespaced under `prism_updater:` so the family never collides
/// with host-app preferences.
class PrismSkipStore {
  /// Creates a skip store over [SharedPreferencesAsync] by default, or an
  /// injected [backend] (in-memory in tests).
  PrismSkipStore({SkipStoreBackend? backend})
      : _backend = backend ?? AsyncPrefsBackend(SharedPreferencesAsync());

  final SkipStoreBackend _backend;

  static const _prefix = 'prism_updater.skipped.';
  static const _seenPrefix = 'prism_updater.seen.';

  /// Records [version] as skipped (user pressed "Maybe later").
  Future<void> skip(PrismVersion version) =>
      _backend.setBool('$_prefix$version', true);

  /// Clears a previously skipped [version] (e.g. it became forced, or the
  /// user explicitly re-checks).
  Future<void> clearSkip(PrismVersion version) =>
      _backend.remove('$_prefix$version');

  /// Whether [version] was skipped.
  Future<bool> isSkipped(PrismVersion version) async =>
      await _backend.getBool('$_prefix$version') ?? false;

  /// Records that an update to [version] was shown to the user at [at].
  Future<void> markSeen(PrismVersion version, {DateTime? at}) =>
      _backend.setString('$_seenPrefix$version', (at ?? DateTime.now()).toIso8601String());

  /// When [version]'s update was last shown, or `null` if never shown.
  Future<DateTime?> seenAt(PrismVersion version) async {
    final raw = await _backend.getString('$_seenPrefix$version');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Clears all prism_updater skip/seen records.
  Future<void> reset() async {
    final keys = await _backend.keys();
    for (final key in keys) {
      if (key.startsWith(_prefix) || key.startsWith(_seenPrefix)) {
        await _backend.remove(key);
      }
    }
  }
}
