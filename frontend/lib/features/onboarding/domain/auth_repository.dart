import 'app_user.dart';

abstract class AuthRepository {
  /// 가입하고 access token과 사용자 정보를 기기에 저장한다.
  /// 같은 기기·역할로 다시 가입하면 서버가 기존 사용자를 돌려준다.
  Future<AppUser> signUp({required String name, required UserRole role});

  /// 서버에서 사용자(역할·페어링 상태)를 다시 받아 기기에 저장한다. 계약 5.14 초안.
  ///
  /// 로그인이 끝났으면(401) [ApiException]을 그대로 던진다. 그 밖의 실패(인터넷 끊김,
  /// 서버 오류, 응답 형식 오류, 시간 초과)는 앱을 쓸 수 있게 [cached]를 돌려준다.
  Future<AppUser> restoreUser({required AppUser cached});
}
