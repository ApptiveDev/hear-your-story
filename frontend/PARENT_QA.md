# 부모 화면 검증 가이드

API 기준: [계약 5.5–5.8](../docs/api-contract.md). 담당: B.
검증 결과(일시·기기·서버 버전, 성공/실패)는 이 문서가 아니라 PR 본문에 기록한다.
배포 빌드는 [RELEASE.md](RELEASE.md), 결과 양식은 [통합 QA](../docs/release-qa.md)를 따른다.

## 자동 검증

```powershell
cd frontend
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

- `test/features/parent_session_test.dart`: 업로드·처리 조회·답변 조회·TTS 조회의
  인증 복구 실패 후 세션 정리와 화면 이동을 검증한다. 403은 세션을 유지하고 홈으로
  이동한다. 실제 토큰 갱신과 재로그인은 아래 기기 검증으로 확인한다.
- `test/core/audio_playback_card_test.dart`: 만료 URL 갱신, 실패 후 재시도,
  중복 요청 방지, 갱신 시간 제한, 백그라운드 정지, 비활성화/화면 종료,
  오래된 비동기 결과 무시, asset 재생 경로를 검증한다.
- 오디오 위젯 테스트는 가짜 플레이어를 사용한다. 실제 코덱·스피커·마이크 검증은
  아래 기기 검증으로 별도 수행한다.

## 백엔드 없이 기기에서 확인

```powershell
flutter run --dart-define=PART_B_DEMO=recording
flutter run --dart-define=PART_B_DEMO=answer
flutter run --dart-define=PART_B_DEMO=answer --dart-define=MOCK_PARENT_ANSWER=processing
flutter run --dart-define=PART_B_DEMO=answer --dart-define=MOCK_PARENT_ANSWER=failed
```

명령은 하나씩 실행한다. 연결된 기기가 여러 대이면 `flutter devices`로 ID를 확인해
`-d <device-id>`를 붙인다.
Mock 녹음도 마이크는 실제로 사용하지만 업로드/처리는 가짜 응답이다.
Mock TTS는 실제 자녀 답변 대신 1초 테스트 소리를 재생한다.

에뮬레이터에서는 화면 전환·버튼 상태·큰 글씨를 먼저 확인한다. 실제 마이크·스피커의
녹음/재생 품질과 전화 수신 중단은 Android 실기기에서 별도로 확인한다.
실기기가 없는 검증자는 아래 항목과 빌드 정보를 실행자에게 전달하고 결과를 취합한다.
실행 환경별 결과는 [통합 QA](../docs/release-qa.md)의 구분과 상태 기준을 따른다.

- [ ] 마이크 권한 거부 시 안내와 재시도, 허용 후 녹음 시작.
- [ ] 수동 정지·일시정지 후 정지·60초 자동 종료 모두 미리 듣기로 이동하고, 보내기 전에는 업로드하지 않음.
- [ ] 미리 듣기에서 방금 녹음한 파일 재생. 듣지 않고도 보내기 가능.
- [ ] 재생 중 보내기를 누르면 재생이 멈추고 업로드 진행/처리 상태 표시. 연타해도 한 번만 전송.
- [ ] 미리 듣기에서 다시 녹음 취소 시 기존 파일 유지, 확인 시 이전 음성 제거 후 새 녹음만 재생·전송.
- [ ] 여러 번 잠깐 멈추고 이어 말한 뒤 파일 하나로 끊김 없이 재생.
- [ ] 일시정지 시간은 녹음 길이·60초 제한에서 제외. 멈춘 채 자동 전송되지 않음.
- [ ] 처음부터 다시 말하기 취소 시 녹음 유지, 확인 시 이전 음성 제거·0초부터 시작.
- [ ] 멈춤·이어가기 빠른 반복, 전화 수신, 화면 종료 후 타이머·마이크 상태 확인.
- [ ] 글씨 1.3배·2배에서도 녹음·멈춤·미리 듣기·보내기·다시 말하기 버튼에 접근 가능.
- [ ] 녹음 도중 백그라운드로 이동하면 자동 전송하지 않고 보낼지 선택 가능.
- [ ] 처리 중/실패 시에도 자녀 글이 남아 있음.
- [ ] 테스트 소리 듣기, 일시 정지, 앱을 배경으로 보낼 때 정지.

## 실제 API 연동

실행 중인 테스트 서버, 부모·자녀 테스트 기기(또는 별도 에뮬레이터),
페어링된 계정, 오늘 질문 배정이 필요하다. TTS API는 구현되어 있으므로 대상 서버의
배포와 R2/STT/LLM/TTS 실제 연동 설정을 확인한다.
서버 자격 증명은 백엔드에서 관리하며 앱이나 테스트 파일에 넣지 않는다.

```powershell
# Android 에뮬레이터 → 개발 PC의 서버
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# 실기기 → 같은 네트워크에 있는 개발 PC의 LAN IP
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://192.168.x.x:8080/api/v1
```

`10.0.2.2`는 에뮬레이터에서만 개발 PC를 가리킨다. 주소만 바꾸지 말고 반드시
`USE_MOCK=false`를 함께 지정한다. `PART_B_DEMO`는 실제 API 모드에 적용되지 않는다.
테스트용으로 본인 동의하에 녹음하며, 실제 테스트 계정 생성/업로드는 서버 담당자와
사용할 환경을 맞춘 뒤 수행한다.

| 시나리오 | 기대 결과 |
|---|---|
| 부모 녹음 제출 | 정지·미리 듣기까지 업로드 없음. 보내기 시 PUT multipart `audioFile`, 202 후 recordingId로 상태 조회 |
| 처리 완료 | READY에서 폴링 종료 |
| AI 처리 실패 | 원본 제출 유지, 실패 안내. 재녹음은 공개 전만 가능 |
| 업로드 실패 후 재전송 | 동일 파일의 Idempotency-Key 유지 |
| 60초 이상 처리 지연 | 무한 로딩 대신 처리 중 안내와 수동 재조회 |
| 자녀 답변 제출 후 공개 | 부모에게 글 표시, TTS 조회 시작 |
| TTS PROCESSING → READY | 준비 안내 후 재생 버튼, 실제 음성 확인 |
| TTS FAILED / 네트워크 실패 | 글 유지, 오류/재시도 안내 |
| Signed URL 만료 | 새 URL 조회 후 재생. 실제 주소가 달라지는 응답으로 확인 |
| 월별 달력 | 대상 서버 월별 API 배포 확인 후 STORIES_MONTH_API=true로 날짜·빈 달·음성 재생 확인 |
| 401 / 403 | 401은 토큰 갱신 후 재시도, 갱신 실패 시 재로그인. 403은 홈 이동. 제어된 테스트 응답으로 확인 |

카카오 인증 API는 확정되었다. 대상 서버·앱 키·서명 키 해시가 준비되지 않았다면
실제 인증 검증은 BLOCKED로 기록한다.

자동 테스트나 APK 빌드 성공만으로 위 실제 API 항목을 완료 처리하지 않는다.
결과를 기록할 때 토큰·서명 URL·답변 내용을 첨부하지 않는다.
