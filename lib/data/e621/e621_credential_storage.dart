import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'e621_credentials.dart';

class E621CredentialStorage {
  E621CredentialStorage(this._storage);

  static const _usernameKey = 'e621_username';
  static const _apiKeyKey = 'e621_api_key';

  final FlutterSecureStorage _storage;

  Future<E621Credentials?> read() async {
    final username = await _storage.read(key: _usernameKey);
    final apiKey = await _storage.read(key: _apiKeyKey);

    if (username == null || username.isEmpty || apiKey == null || apiKey.isEmpty) {
      return null;
    }
    return E621Credentials(username: username, apiKey: apiKey);
  }

  Future<void> write(E621Credentials credentials) async {
    await _storage.write(key: _usernameKey, value: credentials.username);
    await _storage.write(key: _apiKeyKey, value: credentials.apiKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _apiKeyKey);
  }
}
