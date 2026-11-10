import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'session_expired_signal.dart';
import 'token_refresher.dart';

/// 401일 때 토큰을 갱신할지. 카카오 로그인(refresh token)을 켤 때만 갱신한다.
final tokenRefreshEnabledProvider = Provider<bool>(
  (ref) => AppConfig.kakaoAuth,
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final options = BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  );
  final dio = Dio(options);

  final refresher = TokenRefresher(storage, (body) {
    // 인증 interceptor가 없는 Dio로 보낸다. 통신 어댑터는 같은 것을 쓴다(테스트용 교체 포함).
    final plain = Dio(options)..httpClientAdapter = dio.httpClientAdapter;
    return plain.post<dynamic>('/auth/refresh', data: body);
  });

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      refresher: refresher,
      retry: dio.fetch,
      onSessionExpired: () =>
          ref.read(sessionExpiredSignalProvider.notifier).emit(),
      refreshEnabled: ref.read(tokenRefreshEnabledProvider),
    ),
  );
  return dio;
});
