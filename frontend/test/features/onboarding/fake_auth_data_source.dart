import 'package:life_record/features/onboarding/data/auth_data_source.dart';

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
}
