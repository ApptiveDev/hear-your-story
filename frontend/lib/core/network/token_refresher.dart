import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// refresh token으로 access token을 다시 받는다. (계약 5.14 `POST /auth/refresh`)
///
/// 여러 요청이 동시에 401을 받아도 갱신 요청은 한 번만 보낸다. refresh token을
/// 서버가 교체하는 경우 같은 토큰을 두 번 쓰면 둘 다 무효가 될 수 있기 때문이다.
class TokenRefresher {
  TokenRefresher(this._storage, this._send);

  final TokenStorage _storage;

  /// `/auth/refresh` 요청. 무한 반복을 막으려고 인증 interceptor가 없는 Dio로 보낸다.
  final Future<Response<dynamic>> Function(Map<String, dynamic> body) _send;
  Future<String?>? _running;

  /// 새 access token. 다시 로그인해야 하면 null을 돌려준다.
  ///
  /// 네트워크·서버 오류는 그대로 던진다. 이때 로그인 정보를 지우면 잠깐 인터넷이
  /// 끊긴 것만으로 로그아웃되기 때문이다.
  Future<String?> refresh() =>
      _running ??= _refresh().whenComplete(() => _running = null);

  Future<String?> _refresh() async {
    final refreshToken = await _storage.readRefresh();
    if (refreshToken == null) return null;

    final Response<dynamic> response;
    try {
      response = await _send({'refreshToken': refreshToken});
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 만료·폐기된 refresh token
      if (status == 400 || status == 401 || status == 403) return null;
      rethrow;
    }

    final data = response.data as Map<String, dynamic>;
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String;

    // 기다리는 사이 로그아웃(또는 다른 계정 로그인)했으면 되살리지 않는다
    if (await _storage.readRefresh() != refreshToken) return null;
    await _storage.saveTokens(access: access, refresh: refresh);
    return access;
  }
}
