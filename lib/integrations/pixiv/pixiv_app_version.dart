import 'package:flutter_riverpod/flutter_riverpod.dart';

class PixivAppVersionNotifier extends StateNotifier<String> {
  PixivAppVersionNotifier() : super(_defaultVersion);

  static const String _defaultVersion = '5.0.234';

  void update(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (state == trimmed) {
      return;
    }
    state = trimmed;
  }

  void reset() {
    state = _defaultVersion;
  }
}
