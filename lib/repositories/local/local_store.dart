import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_keys.dart';

/// JSON collections over SharedPreferences, with change notification.
///
/// `watchCollection` emits the current contents immediately and then re-emits
/// after every write - the same contract as a Firestore snapshot stream. That
/// single behaviour is what lets the local and Firestore repositories share an
/// interface, in about 40 lines and with no rxdart.
///
/// Collections here hold tens of documents, so rewriting a whole collection per
/// mutation is cheaper than maintaining an index.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  /// Documents are stored as a map of id -> fields, matching how both backends
  /// address documents.
  Map<String, Map<String, dynamic>> readCollection(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, Map<String, dynamic>>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (id, value) => MapEntry(id, Map<String, dynamic>.from(value as Map)),
      );
    } catch (error) {
      debugPrint('LocalStore: unreadable collection $key ($error); resetting.');
      return <String, Map<String, dynamic>>{};
    }
  }

  Map<String, dynamic>? readDoc(String key, String id) =>
      readCollection(key)[id];

  Future<void> writeCollection(
    String key,
    Map<String, Map<String, dynamic>> docs,
  ) async {
    await _prefs.setString(key, jsonEncode(docs));
    _emit(key);
  }

  Future<void> setDoc(
    String key,
    String id,
    Map<String, dynamic> data,
  ) async {
    final docs = readCollection(key)..[id] = data;
    await writeCollection(key, docs);
  }

  Future<void> setDocs(
    String key,
    Map<String, Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    final docs = readCollection(key)..addAll(entries);
    await writeCollection(key, docs);
  }

  Future<void> updateDoc(
    String key,
    String id,
    Map<String, dynamic> Function(Map<String, dynamic> current) transform,
  ) async {
    final docs = readCollection(key);
    final current = docs[id];
    if (current == null) return;
    docs[id] = transform(Map<String, dynamic>.from(current));
    await writeCollection(key, docs);
  }

  Future<void> deleteDoc(String key, String id) async {
    final docs = readCollection(key);
    if (docs.remove(id) == null) return;
    await writeCollection(key, docs);
  }

  Stream<Map<String, Map<String, dynamic>>> watchCollection(String key) async* {
    yield readCollection(key);
    yield* _changes.stream.where((changed) => changed == key).map(
          (_) => readCollection(key),
        );
  }

  // Scalar helpers for session flags and the cooldown ledger.
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
    _emit(key);
  }

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    _emit(key);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
    _emit(key);
  }

  bool containsKey(String key) => _prefs.containsKey(key);

  /// Wipe and reseed on a schema bump rather than crashing on a shape change.
  Future<bool> needsMigration() async {
    final stored = _prefs.getInt(LocalKeys.schemaVersion);
    return stored != LocalKeys.currentSchemaVersion;
  }

  Future<void> migrate() async {
    final stored = _prefs.getInt(LocalKeys.schemaVersion);
    if (stored == LocalKeys.currentSchemaVersion) return;
    if (stored != null) {
      debugPrint(
        'LocalStore: schema $stored -> ${LocalKeys.currentSchemaVersion}; '
        'clearing demo data.',
      );
      for (final key in _prefs.getKeys().toList()) {
        if (key.startsWith(LocalKeys.prefix)) await _prefs.remove(key);
      }
    }
    await _prefs.setInt(
      LocalKeys.schemaVersion,
      LocalKeys.currentSchemaVersion,
    );
  }

  void _emit(String key) {
    if (!_changes.isClosed) _changes.add(key);
  }

  void dispose() => _changes.close();
}
