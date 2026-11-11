import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import 'kakao_login_response.dart';
import 'user_storage.dart';

abstract class AuthDataSource {
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String role,
    required String deviceId,
  });

  /// 로그인한 사용자를 서버에서 다시 받는다. 계약 5.14 초안의 `GET /users/me`.
  ///
  /// 응답은 5.1의 `user` 객체와 같은 모양(`id`, `name`, `role`, `pairingStatus`)이라고
  /// 가정한다. 계약이 확정되면 맞춘다.
  Future<Map<String, dynamic>> fetchMe();

  /// 카카오 id token으로 로그인한다. 계약 5.14 초안에 없는 경로라 `POST /auth/kakao`
  /// `{idToken, deviceId}`로 가정한다. 응답은 [KakaoLoginResponse] 참고.
  Future<Map<String, dynamic>> loginWithKakao({
    required String idToken,
    required String deviceId,
  });
}

class MockAuthDataSource implements AuthDataSource {
  /// 카카오 로그인 결과를 바꿀 때: --dart-define=MOCK_KAKAO=RESTORED
  /// 지원 값: NEW(기본, 처음 로그인), RESTORED(기존 계정)
  static const _kakaoScenario = String.fromEnvironment(
    'MOCK_KAKAO',
    defaultValue: 'NEW',
  );

  /// 다른 상태를 볼 때: flutter run --dart-define=MOCK_ME=UNPAIRED
  /// 지원 값: SAME(기본, 저장된 사용자 그대로), UNPAIRED(상대가 연결을 끊음),
  /// TOKEN_EXPIRED(401), NETWORK
  MockAuthDataSource(this._userStorage);

  final UserStorage _userStorage;

  static const _meScenario = String.fromEnvironment(
    'MOCK_ME',
    defaultValue: 'SAME',
  );

  @override
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String role,
    required String deviceId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 로딩 확인용
    final file = role == 'PARENT' ? 'user_parent' : 'user_child';
    final raw = await rootBundle.loadString('assets/mocks/$file.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    // 서버처럼 입력한 이름을 돌려준다
    (json['user'] as Map<String, dynamic>)['name'] = name;
    return json;
  }

  @override
  Future<Map<String, dynamic>> fetchMe() async {
    await Future.delayed(const Duration(milliseconds: 300));
    switch (_meScenario) {
      case 'TOKEN_EXPIRED':
        throw ApiException(statusCode: 401, errorCode: _meScenario);
      case 'NETWORK':
        throw ApiException();
    }
    // 서버 대신 기기에 저장된 사용자를 돌려준다. 가입 전이면 서버도 401을 준다.
    final user = await _userStorage.read();
    if (user == null) {
      throw ApiException(statusCode: 401, errorCode: 'TOKEN_EXPIRED');
    }
    final json = user.toJson();
    if (_meScenario == 'UNPAIRED') json['pairingStatus'] = 'UNPAIRED';
    return json;
  }

  @override
  Future<Map<String, dynamic>> loginWithKakao({
    required String idToken,
    required String deviceId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final file = _kakaoScenario == 'RESTORED'
        ? 'auth_recovery_draft'
        : 'auth_kakao_new';
    final raw = await rootBundle.loadString('assets/mocks/$file.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

class ApiAuthDataSource implements AuthDataSource {
  ApiAuthDataSource(this._dio);
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String role,
    required String deviceId,
  }) async {
    try {
      final res = await _dio.post(
        '/users',
        data: {'name': name, 'role': role, 'deviceId': deviceId},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final res = await _dio.get<dynamic>('/users/me');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Map<String, dynamic>> loginWithKakao({
    required String idToken,
    required String deviceId,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/auth/kakao',
        data: {'idToken': idToken, 'deviceId': deviceId},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
