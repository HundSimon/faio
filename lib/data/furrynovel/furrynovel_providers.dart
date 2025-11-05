import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'furrynovel_service.dart';

final furryNovelDioProvider = Provider<Dio>((ref) {
  final options = BaseOptions(
    baseUrl: 'https://api.furrynovel.ink',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    responseType: ResponseType.json,
    headers: const {
      'Referer': 'https://furrynovel.ink/',
      'Accept': 'application/json',
    },
  );
  return Dio(options);
}, name: 'furryNovelDioProvider');

final furryNovelServiceProvider = Provider<FurryNovelService>((ref) {
  final dio = ref.watch(furryNovelDioProvider);
  return FurryNovelService(dio: dio);
}, name: 'furryNovelServiceProvider');
