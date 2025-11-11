import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a lazily created [SharedPreferences] instance that can be reused
/// across features without forcing eager initialisation.
final sharedPreferencesProvider =
    Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
  name: 'sharedPreferencesProvider',
);
