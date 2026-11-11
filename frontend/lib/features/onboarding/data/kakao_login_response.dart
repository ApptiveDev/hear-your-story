import '../domain/app_user.dart';
import '../domain/login_result.dart';

/// `POST /auth/kakao` 응답. 계약 5.14의 로그인 성공 응답 뼈대에 `user: null`(NEW)을
/// 더한 모양으로 가정한다.
class KakaoLoginResponse {
  const KakaoLoginResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.recoveryStatus,
  });

  /// 가입을 마치기 전(NEW)에는 null
  final AppUser? user;
  final String accessToken;
  final String refreshToken;
  final RecoveryStatus recoveryStatus;

  factory KakaoLoginResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final response = KakaoLoginResponse(
      user: user == null ? null : AppUser.fromJson(user),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      recoveryStatus: RecoveryStatus.fromApi(json['recoveryStatus'] as String),
    );
    if (response.recoveryStatus == RecoveryStatus.restored && user == null) {
      throw const FormatException('RESTORED인데 user가 없다');
    }
    return response;
  }

  LoginResult toResult() =>
      LoginResult(user: user, recoveryStatus: recoveryStatus);
}
