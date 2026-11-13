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

  // 카카오 개발자 콘솔의 네이티브 앱 키. 저장소에 넣지 않고 빌드할 때 넘긴다.
  // flutter build apk --dart-define=KAKAO_NATIVE_APP_KEY=...
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );

  // 카카오 SDK 대신 가짜 로그인을 쓴다. Mock 모드와, 앱 키 없이 에뮬레이터에서
  // 확인할 때 쓴다. 실제 출시 빌드에서는 켜지 않는다.
  static const kakaoFakeLogin = bool.fromEnvironment(
    'KAKAO_FAKE_LOGIN',
    defaultValue: useMock,
  );
}
