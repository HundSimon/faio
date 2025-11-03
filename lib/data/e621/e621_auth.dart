import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class E621Credentials extends Equatable {
  const E621Credentials({
    required this.username,
    required this.apiKey,
  });

  final String username;
  final String apiKey;

  bool get isComplete => username.isNotEmpty && apiKey.isNotEmpty;

  @override
  List<Object?> get props => [username, apiKey];

  E621Credentials copyWith({
    String? username,
    String? apiKey,
  }) {
    return E621Credentials(
      username: username ?? this.username,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

class E621AuthNotifier extends StateNotifier<E621Credentials?> {
  E621AuthNotifier() : super(null);

  void update({
    required String username,
    required String apiKey,
  }) {
    final trimmedUser = username.trim();
    final trimmedKey = apiKey.trim();
    if (trimmedUser.isEmpty || trimmedKey.isEmpty) {
      state = null;
    } else {
      state = E621Credentials(username: trimmedUser, apiKey: trimmedKey);
    }
  }

  void clear() {
    state = null;
  }
}

/// Holds the current e621 authentication credentials in memory.
final e621AuthProvider =
    StateNotifierProvider<E621AuthNotifier, E621Credentials?>((ref) {
  return E621AuthNotifier();
}, name: 'e621AuthProvider');
