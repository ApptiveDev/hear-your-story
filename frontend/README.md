# Frontend — 들려줘요 (Flutter)

부모·자녀 1:1 질문 답변 앱의 Flutter 클라이언트입니다. MVP 대상 플랫폼은 **Android**입니다.

작업 전에 반드시 읽을 문서:

1. [`../AGENTS.md`](../AGENTS.md) — 프로젝트 공통 규칙
2. [`../docs/api-contract.md`](../docs/api-contract.md) — API 요청·응답·enum의 단일 기준
3. [`AGENTS.md`](AGENTS.md) — Flutter 구현 규칙, 화면별 담당, 일정

## 개발 환경

| 항목 | 버전 |
|---|---|
| Flutter | 3.47.5 (stable) |
| Android NDK | 28.2.13676358 |
| 패키지명 / Application ID | `life_record` / `com.apptive.life_record` |
| 앱 표시 이름 | 들려줘요 (`android/app/src/main/AndroidManifest.xml`의 `android:label`). 패키지명은 그대로 둔다 |

스캐폴드 시점 `flutter --version` 결과:

```text
Flutter 3.47.5 • channel stable
```

팀원은 같은 stable 버전을 사용합니다. 버전 차이로 문제가 생기면 FVM 도입을 논의합니다.

### 최초 1회 설정

1. Android Studio에 **Flutter** 플러그인을 설치합니다. (Dart 플러그인은 함께 설치됨)
2. **Settings → Languages & Frameworks → Android SDK → SDK Tools**에서
   **Show Package Details**를 체크하고 다음을 설치합니다.
   - NDK (Side by side) `28.2.13676358`
   - Android SDK Command-line Tools (latest)
3. `flutter doctor`로 Android toolchain까지 체크되는지 확인합니다.
4. Android Studio에서는 `4team` 루트가 아니라 **`frontend` 폴더를 프로젝트로 엽니다.**
   루트로 열면 Dart/Android 설정이 인식되지 않습니다.

## 실행

```bash
cd frontend
flutter pub get
flutter run
```

Android 에뮬레이터 또는 USB 디버깅이 켜진 실기기가 필요합니다. 실행 대상이
`Windows (desktop)`으로 잡혀 있으면 에뮬레이터로 바꿔 주세요.

### Mock / 실제 API 전환

기본값은 **Mock 사용**(`USE_MOCK=true`)입니다. 백엔드 없이 `assets/mocks/`의 JSON으로
화면을 개발합니다.

실제 백엔드에 연결할 때:

```bash
# Android 에뮬레이터 → 개발 PC의 localhost
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# 실기기 → 같은 네트워크에 있는 개발 PC의 LAN IP
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://192.168.x.x:8080/api/v1
```

- API 주소는 코드에 고정하지 않고 `--dart-define`으로 전달합니다. (`lib/core/config/app_config.dart`)
- 아직 백엔드가 없는 기능은 기본값이 `USE_MOCK`과 같아서 실제 서버에서는 화면에 나오지 않습니다.
  서버가 준비되면 `STORIES_MONTH_API=true`(달력), `ACCOUNT_DELETION_API=true`(탈퇴)로 켭니다.
- 마이페이지의 개인정보 처리방침 주소와 문의처는 `PRIVACY_POLICY_URL`, `SUPPORT_CONTACT`로
  넣습니다. 비어 있으면 "준비 중이에요."로 보입니다.
- `http://` 로컬 통신은 debug 빌드에서만 허용됩니다. (`android/app/src/debug/AndroidManifest.xml`)
- 운영·스테이징 URL과 API key는 커밋하지 않습니다.

## 폴더 구조

```text
lib/
├── main.dart                       # ProviderScope + App
├── app/
│   ├── app.dart                    # MaterialApp.router, 테마
│   └── router.dart                 # go_router 경로 (화면 담당 표시)
├── core/
│   ├── config/app_config.dart      # --dart-define 환경값
│   ├── network/
│   │   ├── dio_provider.dart       # Dio + Bearer 토큰 interceptor
│   │   └── api_exception.dart      # 에러 응답 → errorCode, 앱용 문구
│   ├── storage/token_storage.dart  # flutter_secure_storage 토큰 저장
│   ├── theme/app_theme.dart        # 큰 글씨·높은 대비·넓은 버튼
│   └── widgets/                    # PlaceholderPage, ErrorRetryView
└── features/
    └── onboarding/data/            # Mock ↔ API DataSource 교체 예시
```

새 기능은 `features/<기능명>/` 아래에 `data/`, `domain/`, `presentation/`으로 나눕니다.
화면 Widget에서 Dio를 직접 호출하지 않고 Repository/DataSource를 거칩니다.

### 라우트

| 경로 | 화면 | 담당 |
|---|---|---|
| `/onboarding` | 역할 선택·가입 | A 박강현 |
| `/pairing` | 페어링 | A 박강현 |
| `/today` | 오늘 질문 | A 박강현 |
| `/recording` | 부모 녹음 | B Yin Min Aye |
| `/parent-answer` | 부모의 자녀 답변 확인·TTS 듣기 | B Yin Min Aye |
| `/child-answer` | 자녀 답변 | C 정우영 |
| `/stories` | 지난 이야기 | C 정우영 |

### 카카오 로그인

가입과 로그인은 카카오 OpenID Connect를 사용합니다. 기존 사용자는 같은 카카오
계정으로 로그인하면 Pair와 지난 이야기를 복구합니다.

```bash
# Mock으로 화면 흐름 확인 (가짜 카카오 로그인)
flutter run

# 실제 카카오 로그인 (키는 카카오 개발자 콘솔에서 받고 커밋하지 않는다)
flutter run --dart-define=USE_MOCK=false \
  --dart-define=KAKAO_NATIVE_APP_KEY=네이티브_앱_키
```

| 값 | 기본 | 설명 |
|---|---|---|
| `KAKAO_NATIVE_APP_KEY` | 없음 | 카카오 네이티브 앱 키. manifest의 돌아올 주소(`kakao{키}://oauth`)에도 들어간다 |
| `KAKAO_FAKE_LOGIN` | `USE_MOCK` 값 | 카카오 SDK 대신 가짜 로그인 (앱 키 없이 확인할 때) |
| `MOCK_KAKAO` | `NEW` | Mock 로그인 결과: `NEW`, `RESTORED` |
| `MOCK_KAKAO_SIGN_IN` | `OK` | 가짜 카카오 로그인 결과: `OK`, `CANCELLED`, `FAILED` |
| `MOCK_ME` | `SAME` | Mock `GET /users/me`: `SAME`, `UNPAIRED`, `TOKEN_EXPIRED`, `NETWORK` |

실제 카카오 로그인에는 카카오 개발자 콘솔에서 Android 플랫폼(패키지명·키 해시) 등록과
OpenID Connect 활성화가 필요합니다. 키 해시는 개발 PC의 debug 키마다 다릅니다.

전체 팀 구성은 루트 [`README.md`](../README.md#팀)를 참고합니다.

## Mock 데이터

`assets/mocks/`에 API 계약 5장의 응답 예시를 그대로 옮겨 두었습니다.

| 파일 | 출처 |
|---|---|
| `user_parent.json` | 5.1 가입 응답 |
| `user_child.json` | 5.1 변형 (role=CHILD) |
| `pair_invitation.json` | 5.2 초대 코드 발급 |
| `pair_joined.json` | 5.3 초대 코드 참여 (연결 완료) |
| `today_waiting_for_both.json` | 5.4 변형 (둘 다 답하기 전) |
| `today_waiting_for_child.json` | 5.4 부모만 답한 상태 |
| `today_waiting_for_parent.json` | 5.4 변형 (자녀만 답한 상태, `partnerAnswer` 생략) |
| `today_revealed.json` | 5.4 공개 후 |
| `today_parent_revealed.json` | 5.4 변형 (부모 관점 공개 답변) |
| `recording_uploaded.json` | 5.5 업로드 접수 |
| `recording_processing.json` | 5.6 처리 중 |
| `recording_failed.json` | 5.6 실패 |
| `recording_ready.json` | 5.6 변형 (처리 완료) |
| `child_answer_submitted.json` | 5.7 자녀 답변 제출 |
| `answer_audio_ready.json` | 5.8 TTS 준비 완료 |
| `stories_first_page.json` | 5.9 지난 이야기 |
| `stories_empty.json` | 5.9 변형 (이야기 없음) |
| `stories_paged_1.json`, `stories_paged_2.json` | 5.9 변형 (다음 페이지가 있는 목록) |
| `stories_month_2026_11.json` | 5.9 월별 조회 초안 (2026년 11월, 다른 달은 `stories_empty.json`) |
| `auth_recovery_draft.json` | 5.14 기존 카카오 계정 로그인 (`AUTHENTICATED`) |
| `auth_kakao_new.json` | 5.14 처음 로그인 (`REGISTRATION_REQUIRED`) |
| `story_recording_deleted.json` | 5.12·5.13 초안 (부모 녹음 삭제·자녀 탈퇴로 `availability=DELETED`인 답, `MOCK_STORIES=deleted`) |

- 필드명과 enum 값은 계약 문서와 정확히 일치해야 합니다.
- 계약이 바뀌면 DTO와 Mock을 같은 PR에서 함께 수정합니다.

## PR 전 확인

```bash
dart format .
flutter analyze
flutter test
```

- 에뮬레이터에서 부모·자녀 흐름을 각각 확인합니다.
- loading / empty / success / error(재시도) 상태를 모두 확인합니다.
- 토큰, 개인정보, signed URL query를 로그에 남기지 않습니다.

## 자주 겪는 문제

| 증상 | 해결 |
|---|---|
| `Dart SDK is not configured` / `Dart support is not enabled` | `frontend` 폴더를 프로젝트로 열기. 계속되면 Android Studio를 닫고 `frontend/.idea` 삭제 후 다시 열기 |
| AndroidManifest에서 `usesCleartextTraffic ... not allowed here` | 위와 같은 IDE 설정 문제. 빌드에는 영향 없음 |
| 빌드 중 `sdkmanager` 오류 / `Package ndk not found` | SDK Tools에서 NDK `28.2.13676358` 직접 설치 |
| `No Windows desktop project configured` | 실행 기기를 Android 에뮬레이터로 변경 (Windows 지원은 추가하지 않음) |
| 실행 직후 `Lost connection to device` | 에뮬레이터 부팅 완료 후 재실행. 반복되면 16k가 아닌 일반 시스템 이미지로 에뮬레이터 생성 |
