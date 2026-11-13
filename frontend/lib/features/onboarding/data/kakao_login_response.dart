import '../domain/app_user.dart';
import '../domain/login_result.dart';

/// `POST /auth/kakao` 응답 (API 계약 5.14).
class KakaoLoginResponse {
  const KakaoLoginResponse({
    required this.authStatus,
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.registrationToken,
  });

  final AuthStatus authStatus;
  final AppUser? user;
  final String? accessToken;
  final String? refreshToken;
  final String? registrationToken;

  factory KakaoLoginResponse.fromJson(Map<String, dynamic> json) {
    final status = AuthStatus.fromApi(json['authStatus'] as String);
    final user = json['user'] as Map<String, dynamic>?;
    final response = KakaoLoginResponse(
      authStatus: status,
      user: user == null ? null : AppUser.fromJson(user),
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      registrationToken: json['registrationToken'] as String?,
    );
    if (status == AuthStatus.authenticated) {
      if (response.user == null ||
          response.accessToken == null ||
          response.refreshToken == null ||
          response.registrationToken != null) {
        throw const FormatException('AUTHENTICATED 응답 필드가 올바르지 않다');
      }
    } else if (response.user != null ||
        response.accessToken != null ||
        response.refreshToken != null ||
        response.registrationToken == null) {
      throw const FormatException('REGISTRATION_REQUIRED 응답 필드가 올바르지 않다');
    }
    return response;
  }

  LoginResult toResult() => LoginResult(user: user, authStatus: authStatus);
}
