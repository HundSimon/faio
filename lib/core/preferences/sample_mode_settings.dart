import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/shared_preferences_provider.dart';

const _sampleModeKey = 'app.sampleMode';

class SampleModeNotifier extends StateNotifier<bool> {
  SampleModeNotifier(this._prefsFuture) : super(false) {
    _load();
  }

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    final prefs = await _prefsFuture;
    state = prefs.getBool(_sampleModeKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await _prefsFuture;
    await prefs.setBool(_sampleModeKey, enabled);
  }
}

final sampleModeProvider = StateNotifierProvider<SampleModeNotifier, bool>((
  ref,
) {
  return SampleModeNotifier(ref.watch(sharedPreferencesProvider));
}, name: 'sampleModeProvider');
