import 'package:life_record/features/onboarding/data/auth_data_source.dart';
import 'package:life_record/features/onboarding/data/kakao_sign_in.dart';

/// 서버 대신 응답을 돌려주고, 받은 요청을 기록한다.
class FakeAuthDataSource implements AuthDataSource {
  FakeAuthDataSource({
    this.pairingStatus = 'UNPAIRED',
    this.error,
    this.me,
    this.meError,
  });

  final String pairingStatus;
  final Object? error;
  final requests = <Map<String, String>>[];

  /// `GET /users/me` 응답. [meError]가 있으면 그것을 던진다.
  Map<String, dynamic>? me;
  Object? meError;

  /// 넣으면 `GET /users/me`가 이것이 끝날 때까지 응답하지 않는다.
  Future<void>? meGate;
  var meCalls = 0;

  /// `POST /auth/kakao` 응답. [kakaoError]가 있으면 그것을 던진다.
  Map<String, dynamic>? kakao;
  Object? kakaoError;
  final kakaoRequests = <Map<String, String>>[];

  @override
  Future<Map<String, dynamic>> signUp({
    required String name,
    required String role,
    required String deviceId,
  }) async {
    requests.add({'name': name, 'role': role, 'deviceId': deviceId});
    final e = error;
    if (e != null) throw e;
    return {
      'user': {
        'id': 'usr_test',
        'name': name,
        'role': role,
        'pairingStatus': pairingStatus,
      },
      'accessToken': 'token_for_$name',
      'tokenType': 'Bearer',
      'expiresAt': '2026-10-24T09:00:00+09:00',
    };
  }

  @override
  Future<Map<String, dynamic>> fetchMe() async {
    meCalls++;
    await meGate;
    final e = meError;
    if (e != null) throw e;
    return me ?? (throw StateError('me 응답을 정하지 않았다'));
  }

  @override
  Future<Map<String, dynamic>> loginWithKakao({
    required String idToken,
    required String deviceId,
  }) async {
    kakaoRequests.add({'idToken': idToken, 'deviceId': deviceId});
    final e = kakaoError;
    if (e != null) throw e;
    return kakao ?? (throw StateError('kakao 응답을 정하지 않았다'));
  }
}

/// 카카오 로그인 응답. 계약 5.14 뼈대 모양.
Map<String, dynamic> kakaoLoginJson({
  String status = 'RESTORED',
  String role = 'PARENT',
  String pairingStatus = 'PAIRED',
}) => {
  'user': status == 'NEW'
      ? null
      : {
          'id': 'usr_kakao',
          'name': '김영희',
          'role': role,
          'pairingStatus': pairingStatus,
        },
  'accessToken': 'kakao-access',
  'refreshToken': 'kakao-refresh',
  'expiresAt': '2026-11-04T16:00:00+09:00',
  'recoveryStatus': status,
};

/// 카카오 SDK 대신 정해 둔 결과를 돌려준다.
class FakeKakao implements KakaoSignIn {
  FakeKakao({this.error});

  Object? error;
  var signInCalls = 0;
  var signOutCalls = 0;

  @override
  Future<String> signIn() async {
    signInCalls++;
    final e = error;
    if (e != null) throw e;
    return 'id-token-1';
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}
