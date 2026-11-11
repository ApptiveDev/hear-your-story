import 'app_user.dart';

/// 카카오 로그인 뒤 서버가 알려주는 계정 상태. 계약 5.14 초안.
enum RecoveryStatus {
  /// 기존 계정을 찾아 역할·연결을 되살렸다
  restored('RESTORED'),

  /// 처음 로그인했다. 역할과 이름을 정해 가입을 마쳐야 한다
  newUser('NEW'),

  /// 본인 확인은 됐지만 기존 기록을 찾지 못했다 (4단계에서 화면을 붙인다)
  recoveryFailed('RECOVERY_FAILED');

  const RecoveryStatus(this.apiValue);
  final String apiValue;

  static RecoveryStatus fromApi(String value) =>
      RecoveryStatus.values.firstWhere(
        (status) => status.apiValue == value,
        orElse: () => throw FormatException('알 수 없는 recoveryStatus: $value'),
      );
}

/// 카카오 로그인 결과. 화면은 이것으로 다음 단계를 정한다.
class LoginResult {
  const LoginResult({required this.user, required this.recoveryStatus});

  /// 가입을 마치기 전(NEW)에는 null
  final AppUser? user;
  final RecoveryStatus recoveryStatus;
}
