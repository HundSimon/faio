import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:faio/features/common/utils/content_warning.dart';

import '../providers/shared_preferences_provider.dart';

const _adultVisibilityKey = 'contentSafety.adultVisibility';
const _extremeVisibilityKey = 'contentSafety.extremeVisibility';

enum ContentVisibility { blur, hide, show }

@immutable
class ContentSafetySettings {
  const ContentSafetySettings({
    this.adultVisibility = ContentVisibility.blur,
    this.extremeVisibility = ContentVisibility.blur,
    this.isLoaded = false,
  });

  final ContentVisibility adultVisibility;
  final ContentVisibility extremeVisibility;
  final bool isLoaded;

  ContentSafetySettings copyWith({
    ContentVisibility? adultVisibility,
    ContentVisibility? extremeVisibility,
    bool? isLoaded,
  }) {
    return ContentSafetySettings(
      adultVisibility: adultVisibility ?? this.adultVisibility,
      extremeVisibility: extremeVisibility ?? this.extremeVisibility,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  ContentVisibility _visibilityFor(ContentWarningLevel level) {
    return switch (level) {
      ContentWarningLevel.extreme => extremeVisibility,
      ContentWarningLevel.adult => adultVisibility,
      ContentWarningLevel.none => ContentVisibility.show,
    };
  }

  bool isBlocked(ContentWarningLevel? level) {
    if (level == null) return false;
    return _visibilityFor(level) == ContentVisibility.hide;
  }

  bool isAutoApproved(ContentWarningLevel? level) {
    if (level == null) return true;
    return _visibilityFor(level) == ContentVisibility.show;
  }

  bool requiresPrompt(ContentWarningLevel? level) {
    if (level == null) return false;
    return _visibilityFor(level) == ContentVisibility.blur;
  }
}

final contentSafetySettingsProvider =
    StateNotifierProvider<ContentSafetySettingsNotifier, ContentSafetySettings>(
      (ref) =>
          ContentSafetySettingsNotifier(ref.read(sharedPreferencesProvider)),
    );

class ContentSafetySettingsNotifier
    extends StateNotifier<ContentSafetySettings> {
  ContentSafetySettingsNotifier(this._prefsFuture)
    : super(_cachedInitial ?? const ContentSafetySettings()) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  static ContentSafetySettings? _cachedInitial;
  static SharedPreferences? _cachedPrefs;

  static Future<void> preload() async {
    final prefs = _cachedPrefs ??= await SharedPreferences.getInstance();
    _cachedInitial = _fromPrefs(prefs);
  }

  static ContentSafetySettings _fromPrefs(SharedPreferences prefs) {
    return ContentSafetySettings(
      adultVisibility: _decodeVisibility(prefs.getString(_adultVisibilityKey)),
      extremeVisibility: _decodeVisibility(
        prefs.getString(_extremeVisibilityKey),
      ),
      isLoaded: true,
    );
  }

  static ContentVisibility _decodeVisibility(String? value) {
    if (value == null) {
      return ContentVisibility.blur;
    }
    return ContentVisibility.values.firstWhere(
      (option) => option.name == value,
      orElse: () => ContentVisibility.blur,
    );
  }

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    state = _cachedInitial = _fromPrefs(prefs);
  }

  Future<void> setAdultVisibility(ContentVisibility visibility) async {
    state = state.copyWith(adultVisibility: visibility);
    final prefs = await _prefsFuture;
    await prefs.setString(_adultVisibilityKey, visibility.name);
    _cachedInitial = _fromPrefs(prefs);
  }

  Future<void> setExtremeVisibility(ContentVisibility visibility) async {
    state = state.copyWith(extremeVisibility: visibility);
    final prefs = await _prefsFuture;
    await prefs.setString(_extremeVisibilityKey, visibility.name);
    _cachedInitial = _fromPrefs(prefs);
  }
}
