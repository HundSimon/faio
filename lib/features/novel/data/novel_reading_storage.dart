import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/novel_reader.dart';

class NovelReadingStorage {
  NovelReadingStorage({Future<SharedPreferences>? prefsFuture})
      : _prefsFuture = prefsFuture ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _settingsKey = 'novel_reader_settings_v1';
  static const _progressPrefix = 'novel_reader_progress_v1_';

  Future<NovelReaderSettings> loadSettings() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const NovelReaderSettings();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>?;
      return NovelReaderSettings.fromJson(json);
    } catch (_) {
      return const NovelReaderSettings();
    }
  }

  Future<void> saveSettings(NovelReaderSettings settings) async {
    final prefs = await _prefsFuture;
    await prefs.setString(
      _settingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<NovelReadingProgress?> loadProgress(int novelId) async {
    final prefs = await _prefsFuture;
    final key = _progressKey(novelId);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>?;
      final progress = NovelReadingProgress.fromJson(novelId, json);
      if (progress.relativeOffset <= 0) {
        return null;
      }
      return progress;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress(NovelReadingProgress progress) async {
    final prefs = await _prefsFuture;
    final key = _progressKey(progress.novelId);
    if (progress.relativeOffset <= 0.01) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(progress.toJson()));
  }

  Future<void> clearProgress(int novelId) async {
    final prefs = await _prefsFuture;
    await prefs.remove(_progressKey(novelId));
  }

  String _progressKey(int novelId) => '$_progressPrefix$novelId';
}
