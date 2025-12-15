import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pixiv_credentials.dart';

class PixivCredentialStorage {
  PixivCredentialStorage(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  static const _credentialKey = 'pixiv_credentials';

  Future<PixivCredentials?> read() async {
    final raw = await _secureStorage.read(key: _credentialKey);
    return PixivCredentials.decode(raw);
  }

  Future<void> write(PixivCredentials credentials) {
    return _secureStorage.write(
      key: _credentialKey,
      value: credentials.encode(),
    );
  }

  Future<void> clear() {
    return _secureStorage.delete(key: _credentialKey);
  }
}
