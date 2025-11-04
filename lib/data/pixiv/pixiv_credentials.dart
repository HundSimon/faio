import 'dart:convert';

/// Represents the Pixiv OAuth credential bundle.
class PixivCredentials {
  const PixivCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
    this.scope = const [],
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final List<String> scope;

  bool get isAccessTokenExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  bool get isValid =>
      accessToken.trim().isNotEmpty && refreshToken.trim().isNotEmpty;

  PixivCredentials copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? tokenType,
    List<String>? scope,
  }) {
    return PixivCredentials(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenType: tokenType ?? this.tokenType,
      scope: scope ?? this.scope,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
      'tokenType': tokenType,
      'scope': scope,
    };
  }

  static PixivCredentials? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (expiresAt == null) {
      return null;
    }
    final scopeValue = json['scope'];
    final scope = switch (scopeValue) {
      List list => list.whereType<String>().toList(),
      String text when text.isNotEmpty => text.split(' '),
      _ => <String>[],
    };
    return PixivCredentials(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: expiresAt,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      scope: scope,
    );
  }

  static PixivCredentials? decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(encoded);
      if (map is Map<String, dynamic>) {
        return PixivCredentials.fromJson(map);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String encode() => jsonEncode(toJson());
}
