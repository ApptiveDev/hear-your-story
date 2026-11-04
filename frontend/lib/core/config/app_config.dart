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
}
