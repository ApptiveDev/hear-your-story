import '../domain/app_user.dart';
import '../domain/login_result.dart';

/// `POST /users` 응답 (API 계약 5.1)
class SignUpResponse {
  const SignUpResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AppUser user;
  final String accessToken;
  final String refreshToken;

  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    if (AuthStatus.fromApi(json['authStatus'] as String) !=
        AuthStatus.authenticated) {
      throw const FormatException('가입 응답은 AUTHENTICATED여야 한다');
    }
    return SignUpResponse(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}
