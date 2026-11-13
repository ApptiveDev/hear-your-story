import 'app_user.dart';
import 'login_result.dart';

abstract class AuthRepository {
  /// 카카오 로그인에서 받은 가입용 token으로 가입하고 서비스 token과 사용자를 저장한다.
  Future<AppUser> signUp({required String name, required UserRole role});

  /// 서버에서 사용자(역할·페어링 상태)를 다시 받아 기기에 저장한다.
  ///
  /// 로그인이 끝났으면(401) [ApiException]을 그대로 던진다. 그 밖의 실패(인터넷 끊김,
  /// 서버 오류, 응답 형식 오류, 시간 초과)는 앱을 쓸 수 있게 [cached]를 돌려준다.
  Future<AppUser> restoreUser({required AppUser cached});

  /// 카카오로 본인 확인을 하고 기존 계정이면 서비스 token을 저장한다.
  ///
  /// 처음이면 가입용 token을 메모리에만 두고 화면이 역할·이름을 받아 [signUp]으로
  /// 가입을 마친다. 사용자가 카카오 창을 닫으면 `KakaoSignInCancelled`를 던진다.
  ///
  /// [onVerified]는 카카오 본인 확인이 끝나고 서버에 기록을 찾으러 가기 직전에 부른다.
  /// [chooseAccount]면 카카오 계정을 고르게 한다.
  Future<LoginResult> loginWithKakao({
    bool chooseAccount = false,
    void Function()? onVerified,
  });

  /// 서버의 refresh token을 폐기한 뒤 로컬 token·사용자를 지우고 카카오도 로그아웃한다.
  Future<void> logout();
}
