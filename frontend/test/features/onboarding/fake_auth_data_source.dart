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

  /// 넣으면 `POST /auth/kakao`가 이것이 끝날 때까지 응답하지 않는다.
  Future<void>? kakaoGate;

  /// 응답할 때마다 꺼내 쓰는 차례별 응답. 비면 [kakao]를 쓴다.
  final kakaoQueue = <Map<String, dynamic>>[];

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
    await kakaoGate;
    final e = kakaoError;
    if (e != null) throw e;
    if (kakaoQueue.isNotEmpty) return kakaoQueue.removeAt(0);
    return kakao ?? (throw StateError('kakao 응답을 정하지 않았다'));
  }
}

/// 카카오 로그인 응답. 계약 5.14 뼈대 모양.
Map<String, dynamic> kakaoLoginJson({
  String status = 'RESTORED',
  String role = 'PARENT',
  String pairingStatus = 'PAIRED',
}) => {
  // 계약 5.14 뼈대: 기존 계정을 찾았을 때(RESTORED)만 사용자가 있다
  'user': status != 'RESTORED'
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

  /// signIn마다 계정을 고르게 했는지
  final chooseAccount = <bool>[];

  /// 넣으면 카카오 본인 확인이 이것이 끝날 때까지 끝나지 않는다.
  Future<void>? gate;

  @override
  Future<String> signIn({bool chooseAccount = false}) async {
    signInCalls++;
    this.chooseAccount.add(chooseAccount);
    await gate;
    final e = error;
    if (e != null) throw e;
    // 계정을 고르면 다른 사람으로 본다
    return chooseAccount ? 'id-token-2' : 'id-token-1';
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}
