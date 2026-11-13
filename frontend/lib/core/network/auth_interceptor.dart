import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'token_refresher.dart';

/// 요청에 access token을 붙이고, 401이면 토큰을 갱신해 한 번 다시 보낸다.
///
/// 갱신할 수 없으면 [onSessionExpired]를 불러 앱 최상단이 로그인 정보를 정리하게 한다.
/// [refreshEnabled]가 false면(기존 가입 방식) 갱신 없이 바로 [onSessionExpired]를 부른다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._storage,
    required this._refresher,
    required this._retry,
    required this._onSessionExpired,
    required this._refreshEnabled,
  });

  final TokenStorage _storage;
  final TokenRefresher _refresher;
  final Future<Response<dynamic>> Function(RequestOptions) _retry;
  final void Function() _onSessionExpired;
  final bool _refreshEnabled;

  static const _usedToken = 'auth.usedToken';
  static const _retried = 'auth.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    options.extra[_usedToken] = token;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401) return handler.next(err);
    if (!_refreshEnabled || options.extra[_retried] == true) {
      return _expire(err, handler);
    }

    final String? token;
    try {
      // 이 요청이 기다리는 사이 다른 요청이 이미 갱신했으면 그 토큰을 쓴다
      final current = await _storage.read();
      token = current != null && current != options.extra[_usedToken]
          ? current
          : await _refresher.refresh();
    } on DioException catch (error) {
      // 갱신 요청의 네트워크·서버 오류. 401로 넘기면 화면이 로그아웃시키므로
      // 갱신 요청의 오류를 원래 요청의 오류로 바꿔 넘긴다.
      return handler.next(error.copyWith(requestOptions: options));
    } on Object catch (error, stack) {
      return handler.next(
        DioException(requestOptions: options, error: error, stackTrace: stack),
      );
    }
    if (token == null) return _expire(err, handler);

    options.extra[_retried] = true;
    final data = options.data;
    // 한 번 보낸 FormData는 다시 보낼 수 없어서 복제한다 (녹음 업로드)
    if (data is FormData) options.data = data.clone();
    try {
      handler.resolve(await _retry(options));
    } on DioException catch (error) {
      // 다시 보낸 요청의 401은 그 요청의 onError가 이미 만료 처리했다
      handler.next(error);
    }
  }

  void _expire(DioException e, ErrorInterceptorHandler handler) {
    handler.next(e);
    // 토큰·사용자 정보 정리와 첫 화면 이동은 앱 최상단(App)이 한다
    _onSessionExpired();
  }
}
