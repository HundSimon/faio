import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/tag_preferences.dart';

class TagPreferencesStorage {
  TagPreferencesStorage({Future<SharedPreferences>? prefsFuture})
    : _prefsFuture = prefsFuture ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _prefsKey = 'tag_preferences_v1';

  Future<TagPreferences> load() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return const TagPreferences();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>?;
      return TagPreferences.fromJson(decoded);
    } catch (_) {
      return const TagPreferences();
    }
  }

  Future<void> save(TagPreferences preferences) async {
    final prefs = await _prefsFuture;
    final encoded = jsonEncode(preferences.toJson());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> clear() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_prefsKey);
  }
}
