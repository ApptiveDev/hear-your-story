class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  // 백엔드 준비 전에는 true로 Mock 사용
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  // 월별 조회(GET /stories?month=)는 아직 초안이라 서버가 month를 무시한다.
  // 백엔드가 준비되기 전에는 실제 서버로 부르지 않고 Mock에서만 달력을 연다.
  static const storiesMonthApi = bool.fromEnvironment(
    'STORIES_MONTH_API',
    defaultValue: useMock,
  );

  // 회원 탈퇴(DELETE /users/me)는 아직 초안이라 서버에 endpoint가 없다.
  // 백엔드가 준비되기 전에는 실제 서버로 부르지 않고 Mock에서만 탈퇴 메뉴를 연다.
  static const accountDeletionApi = bool.fromEnvironment(
    'ACCOUNT_DELETION_API',
    defaultValue: useMock,
  );

  // 마이페이지에 보여주는 값. 주소·연락처가 정해지면 --dart-define으로 넣는다.
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const supportContact = String.fromEnvironment('SUPPORT_CONTACT');

  // pubspec.yaml의 version과 같게 맞춘다.
  static const appVersion = '1.0.0';
}
