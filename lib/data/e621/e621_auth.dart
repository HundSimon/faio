import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage.dart';
import 'e621_credentials.dart';
import 'e621_credential_storage.dart';

class E621AuthNotifier extends StateNotifier<E621Credentials?> {
  E621AuthNotifier(this._storage) : super(null) {
    _restore();
  }

  final E621CredentialStorage _storage;

  Future<void> _restore() async {
    try {
      final saved = await _storage.read();
      if (saved != null) {
        state = saved;
      }
    } catch (_) {
      // ignore restore errors; remain unauthenticated
    }
  }

  void update({
    required String username,
    required String apiKey,
  }) {
    final trimmedUser = username.trim();
    final trimmedKey = apiKey.trim();
    if (trimmedUser.isEmpty || trimmedKey.isEmpty) {
      clear();
      return;
    }

    final credentials = E621Credentials(username: trimmedUser, apiKey: trimmedKey);
    state = credentials;
    unawaited(_storage.write(credentials));
  }

  void clear() {
    state = null;
    unawaited(_storage.clear());
  }
}

final e621CredentialStorageProvider = Provider<E621CredentialStorage>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return E621CredentialStorage(secureStorage);
}, name: 'e621CredentialStorageProvider');

/// Holds the current e621 authentication credentials in memory.
final e621AuthProvider =
    StateNotifierProvider<E621AuthNotifier, E621Credentials?>((ref) {
  final storage = ref.watch(e621CredentialStorageProvider);
  return E621AuthNotifier(storage);
}, name: 'e621AuthProvider');
