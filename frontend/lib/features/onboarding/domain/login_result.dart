import 'app_user.dart';

enum AuthStatus {
  authenticated('AUTHENTICATED'),
  registrationRequired('REGISTRATION_REQUIRED');

  const AuthStatus(this.apiValue);
  final String apiValue;

  static AuthStatus fromApi(String value) => AuthStatus.values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('알 수 없는 authStatus: $value'),
  );
}

/// 카카오 로그인 결과. 화면은 이것으로 다음 단계를 정한다.
class LoginResult {
  const LoginResult({required this.user, required this.authStatus});

  /// 가입을 마치기 전에는 null
  final AppUser? user;
  final AuthStatus authStatus;

  bool get registrationRequired =>
      authStatus == AuthStatus.registrationRequired;
}
