import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhttp/rhttp.dart';

import 'furrynovel_service.dart';

final furryNovelClientProvider = Provider<RhttpClient>((ref) {
  final client = RhttpClient.createSync(
    settings: const ClientSettings(
      timeoutSettings: TimeoutSettings(
        connectTimeout: Duration(seconds: 15),
        timeout: Duration(seconds: 15),
      ),
    ),
  );
  ref.onDispose(client.dispose);
  return client;
}, name: 'furryNovelClientProvider');

final furryNovelServiceProvider = Provider<FurryNovelService>((ref) {
  final client = ref.watch(furryNovelClientProvider);
  return FurryNovelService(client: client);
}, name: 'furryNovelServiceProvider');
