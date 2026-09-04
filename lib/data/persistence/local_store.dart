import 'dart:async';
import 'dart:convert';

import 'package:safe_path/data/persistence/persisted_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app writes what it must not lose when it is closed.
///
/// Behind an interface like every other external service here: the pilot
/// writes to the device, the product will write to a server, and no screen or
/// rule should be able to tell the difference. Tests get an in-memory one.
abstract class LocalStore {
  /// Returns null when there is nothing readable — first launch, cleared
  /// data, or a file this build does not understand.
  Future<PersistedSnapshot?> load();

  Future<void> save(PersistedSnapshot snapshot);

  Future<void> clear();
}

/// A store that keeps nothing. The honest default for a demo build, and what
/// widget tests get unless they ask for otherwise.
class InMemoryLocalStore implements LocalStore {
  PersistedSnapshot? _snapshot;

  /// How many times [save] has been called. Tests assert on it; nothing in
  /// the app reads it.
  int saveCount = 0;

  @override
  Future<PersistedSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(PersistedSnapshot snapshot) async {
    _snapshot = snapshot;
    saveCount++;
  }

  @override
  Future<void> clear() async => _snapshot = null;
}

/// The device-local store, on `shared_preferences`.
///
/// One JSON document under one key. A school day is a few hundred records, so
/// the simplest thing that cannot half-write is the right thing: a partially
/// applied set of keys would leave the attendance log and the alerts derived
/// from it disagreeing, which is worse than losing both.
class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferencesLocalStore({this.retention = const Duration(days: 30)});

  static const _key = 'safe_path.snapshot.v1';

  /// How far back the device keeps records.
  ///
  /// This is a cache, not the system of record — the append-only log lives on
  /// the server, and nothing here is the only copy of anything. Keeping a
  /// child's movements on a driver's tablet indefinitely is a PDPL liability
  /// with no operational benefit, so the local copy is bounded.
  final Duration retention;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<PersistedSnapshot?> load() async {
    try {
      final raw = (await _prefs).getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PersistedSnapshot.fromJson(decoded);
    } on Object {
      // A store that throws on a corrupt file turns a bad byte into an app
      // that will not open. Start clean instead; the server has the record.
      return null;
    }
  }

  @override
  Future<void> save(PersistedSnapshot snapshot) async {
    try {
      final pruned = _prune(snapshot);
      await (await _prefs).setString(_key, jsonEncode(pruned.toJson()));
    } on Object {
      // A full disk must not take the app down mid-trip. The in-memory state
      // is still correct; only the restart guarantee is lost.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await _prefs).remove(_key);
    } on Object {
      // Nothing to do — the caller cannot act on this either.
    }
  }

  PersistedSnapshot _prune(PersistedSnapshot s) {
    final cutoff = DateTime.now().subtract(retention);
    return PersistedSnapshot(
      savedAt: s.savedAt,
      attendanceEvents: s.attendanceEvents
          .where((e) => e.occurredAt.isAfter(cutoff))
          .toList(),
      absences: s.absences.where((a) => a.declaredAt.isAfter(cutoff)).toList(),
      alerts: s.alerts.where((a) => a.raisedAt.isAfter(cutoff)).toList(),
      notifications:
          s.notifications.where((n) => n.sentAt.isAfter(cutoff)).toList(),
      auditLog: s.auditLog.where((a) => a.occurredAt.isAfter(cutoff)).toList(),
      studentOverrides: s.studentOverrides,
      tripProgress: s.tripProgress,
      localeCode: s.localeCode,
      themeModeName: s.themeModeName,
      currentUserId: s.currentUserId,
    );
  }
}
