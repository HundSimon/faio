import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage.dart';
import 'pixiv_credential_storage.dart';
import 'pixiv_credentials.dart';

class PixivAuthNotifier extends StateNotifier<PixivCredentials?> {
  PixivAuthNotifier(this._storage) : super(null) {
    _restore();
  }

  final PixivCredentialStorage _storage;

  Future<void> _restore() async {
    try {
      final saved = await _storage.read();
      if (saved != null && saved.isValid) {
        state = saved;
      }
    } catch (_) {
      // Ignore restore failures; user can re-authenticate later.
    }
  }

  void setCredentials(PixivCredentials credentials) {
    state = credentials;
    unawaited(_storage.write(credentials));
  }

  void updateTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    String tokenType = 'Bearer',
    List<String> scope = const [],
  }) {
    final credentials = PixivCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
      scope: scope,
    );
    setCredentials(credentials);
  }

  void clear() {
    state = null;
    unawaited(_storage.clear());
  }
}

final pixivCredentialStorageProvider = Provider<PixivCredentialStorage>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return PixivCredentialStorage(storage);
}, name: 'pixivCredentialStorageProvider');

final pixivAuthProvider =
    StateNotifierProvider<PixivAuthNotifier, PixivCredentials?>((ref) {
      final storage = ref.watch(pixivCredentialStorageProvider);
      return PixivAuthNotifier(storage);
    }, name: 'pixivAuthProvider');
