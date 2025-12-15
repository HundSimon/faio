import 'package:equatable/equatable.dart';

class E621Credentials extends Equatable {
  const E621Credentials({required this.username, required this.apiKey});

  final String username;
  final String apiKey;

  bool get isComplete => username.isNotEmpty && apiKey.isNotEmpty;

  @override
  List<Object?> get props => [username, apiKey];

  E621Credentials copyWith({String? username, String? apiKey}) {
    return E621Credentials(
      username: username ?? this.username,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
