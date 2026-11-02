# frontend/AGENTS.md — Flutter 구현 규칙

작업 전에 루트 [`../AGENTS.md`](../AGENTS.md)와 API 계약
[`../docs/api-contract.md`](../docs/api-contract.md)을 읽는다. endpoint, JSON 필드,
enum, 에러 코드는 API 계약을 단일 진실 공급원으로 사용하며 이 문서에 중복 정의하지
않는다.

## 1. 기술 기준

- Flutter stable, Dart
- 상태관리: `flutter_riverpod`
- 라우팅: `go_router`
- 네트워크: `dio`
- 토큰 저장: `flutter_secure_storage`
- 녹음: `record` — m4a/AAC-LC, 최대 60초
- 재생: `just_audio`
- 모델은 MVP 동안 수동 DTO로 시작한다. 팀이 이미 code generation에 익숙하지 않다면
  Freezed·Retrofit을 새로 도입하지 않는다.

최초 스캐폴드 담당자는 PR 본문과 `frontend/README.md`에 `flutter --version` 결과를
남긴다. 팀원은 같은 stable 버전을 사용하고, 버전 차이로 문제가 생기면 FVM을
도입한다.

## 2. 최초 스캐폴드

한 사람만 최신 `main`에서 실행한다.

```bash
git switch main
git pull --ff-only origin main
git switch -c chore/frontend-scaffold
cd frontend
flutter create --platforms=android --org com.apptive --project-name PROJECT_NAME .
```

- `PROJECT_NAME`과 Android application ID는 실행 전에 팀에서 확정한다.
- 기존 `AGENTS.md`를 유지하고, 자동 생성된 README는 프로젝트 실행법으로 수정한다.
- Android만 MVP 대상으로 삼는다.
- 스캐폴드 PR이 병합된 뒤 A/B/C가 최신 기준 브랜치에서 각 기능 브랜치를 만든다.

## 3. 권장 폴더 구조

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── config/              # --dart-define 환경값
│   ├── network/             # Dio, 인증 interceptor, API 예외
│   ├── storage/             # access token 저장
│   ├── theme/               # 색상, 글꼴, 크기
│   └── widgets/             # 큰 버튼, 카드, 공통 상태 화면
└── features/
    ├── onboarding/
    ├── pairing/
    ├── today/
    ├── recording/
    ├── child_answer/
    └── stories/
```

각 feature는 필요한 범위에서 다음처럼 나눈다.

```text
feature_name/
├── data/                    # DTO, API·Mock data source, repository 구현
├── domain/                  # 화면에서 사용할 모델, repository interface
└── presentation/            # page, widget, Riverpod provider
```

화면 Widget에서 Dio를 직접 호출하지 않는다. `Repository` 뒤에서 Mock과 실제 API를
교체할 수 있게 한다.

## 4. 환경 설정

API 주소는 코드에 고정하지 않고 `--dart-define`으로 전달한다.

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

- Android 에뮬레이터: `http://10.0.2.2:8080/api/v1`
- Android 실기기: 같은 네트워크에 있는 개발 PC의 LAN IP
- 운영·스테이징 URL과 API key를 Git에 커밋하지 않는다.
- `POST /users` 응답의 access token은 `flutter_secure_storage`에 저장한다.
- Dio interceptor가 `Authorization: Bearer {accessToken}`을 첨부한다.

## 5. Mock 우선 개발

백엔드를 기다리지 않고 [`../docs/api-contract.md`](../docs/api-contract.md)의 JSON으로
다음 fixture를 먼저 만든다.

```text
assets/mocks/
├── user_parent.json
├── user_child.json
├── today_waiting_for_parent.json
├── today_waiting_for_child.json
├── today_revealed.json
├── recording_processing.json
├── recording_failed.json
└── stories_first_page.json
```

- DTO 필드명과 enum은 계약 문서와 정확히 일치시킨다.
- Mock/실제 API 전환은 DataSource 주입으로 처리한다.
- 화면별로 loading, empty, success, retryable error 상태를 모두 확인한다.
- 상대 답변 공개 여부를 앱에서 계산하지 않는다. `revealStatus`와
  `canViewPartnerAnswer`만 사용한다.
- `SKIPPED`는 예약 enum이지만 정책 확정 전까지 건너뛰기 버튼을 노출하지 않는다.

## 6. 화면과 동작

| 화면 | 주요 동작 |
|---|---|
| 역할 선택·가입 | 이름, `PARENT/CHILD`, deviceId로 가입하고 token 저장 |
| 페어링 | 자녀 초대 코드 생성, 부모 초대 코드 입력 |
| 오늘 | `GET /today` 결과에 따른 질문·제출·공개 상태 표시 |
| 부모 녹음 | 질문 음성 재생, 1~60초 녹음, m4a 업로드 |
| 처리 상태 | 3초→5초 간격 폴링, `READY/FAILED`에서 종료 |
| 자녀 답변 | 공개 전까지 텍스트 작성·수정 |
| 답변 공개 | 원본 육성 우선 재생, 정리 텍스트는 보조 자막 |
| 부모의 자녀 답변 확인 | 텍스트 표시, 준비된 TTS 재생 |
| 지난 이야기 | cursor 페이지네이션, signed URL 만료 시 재조회 |

앱이 백그라운드로 가면 녹음 상태 폴링을 중단하고 복귀 시 다시 조회한다. 총 60초
동안 완료되지 않으면 무한 로딩 대신 "처리 중" 상태를 표시한다.

## 7. 시니어 UX

- 부모 화면은 큰 글씨, 높은 대비, 넓은 터치 영역, 한 화면 한 가지 주요 행동을
  원칙으로 한다.
- 부모 화면의 모든 기능은 홈에서 **3번 누르기 안에** 끝나야 한다. 지금 기준은
  답하기(홈 → 목소리로 답하기 → 말하기 시작 → 그만 말하고 보내기)와 자녀 답
  듣기(홈 → 목소리로 듣기 → 듣기)다. 단계를 늘리는 변경은 먼저 공유한다.
  (근거: `docs/competitor-analysis.md` 인사이트 11)
- 녹음 시작·정지 상태를 색상에만 의존하지 않고 텍스트와 아이콘으로 함께 표시한다.
- 녹음 종료 후 자동 업로드하되 업로드 중 앱을 닫지 않도록 명확히 안내한다.
- 기술 오류 문구나 stack trace를 노출하지 않고 이해하기 쉬운 안내와 재시도 버튼을
  제공한다.
- 스트릭의 끊김이나 미응답을 죄책감·재촉으로 표현하지 않는다.
- 자녀 화면의 차단 범위와 상대 답변 공개 정책은 회의 전까지 임의로 구현하지 않는다.

## 8. 프론트 3명 역할

작업량이 3등분되도록 **화면을 보는 사람 기준**으로 나눈다. 앱 진입과 연결은 A,
부모가 보는 화면은 B, 자녀가 보는 화면과 기록은 C가 맡는다. 공통 파일을 여러 명이
동시에 수정하지 않도록 최초 뼈대 책임자를 명확히 한다.

| 담당 | 이름 | 범위 | 경로 |
|---|---|---|---|
| A | 박강현 | 가입·페어링·홈 | `/onboarding`, `/pairing`, `/today` |
| B | Yin Min Aye | 부모 화면 | `/recording`, 부모의 자녀 답변 확인 |
| C | 정우영 | 자녀 화면·보관함 | `/child-answer`, 답변 공개, `/stories` |

### A (박강현) — 가입·페어링·홈

- deviceId 생성·보관, 역할 선택과 가입
- 초대 코드 생성(자녀)·입력(부모), 자녀의 연결 대기 화면
- router redirect: 토큰·페어링 여부로 첫 화면 결정, 401이면 가입 화면으로 이동
- 오늘 질문 홈: `revealStatus` 분기와 B·C 화면으로 이동

### B (Yin Min Aye) — 부모 화면

- 질문 안내 음성 재생
- 마이크 권한, 녹음 시작·정지·60초 제한
- multipart 업로드와 재녹음
- 처리 상태 폴링·실패·재시도 UI
- 공통 오디오 재생 위젯(`lib/core/widgets/`) — C도 사용한다
- 부모의 자녀 답변 확인: 텍스트 표시, TTS 상태 조회(`GET /answers/{answerId}/audio`)와 재생

### C (정우영) — 공통 기반·자녀 화면·보관함

- Day 1: 스캐폴드, router, theme, Dio, secure storage, Mock DataSource 뼈대 (완료)
- 자녀 텍스트 답변 작성·수정
- `revealStatus` 대기 화면
- 자녀의 부모 답변 확인: 원본 음성 우선 재생, 정리 텍스트는 보조 자막(B의 오디오 위젯 사용)
- 지난 이야기 목록·페이지네이션(공개 답변 화면 구성 재사용)

### 담당 사이에서 먼저 합의할 것

- A → B·C: 오늘 홈에서 넘겨줄 값(assignmentId, 질문 정보). 9/25 회의에서 정한다.
- B → C: 오디오 재생 위젯의 사용법. B가 9/26까지 먼저 공유한다.
- C의 공통 기반 PR이 병합된 이후 공통 컴포넌트 변경은 담당자끼리 먼저 공유한다.

## 9. 일정

| 날짜 | 공통 목표 |
|---|---|
| 9/24 | 스캐폴드, 패키지, router/theme/network/Mock 뼈대, 화면 브랜치 분리 |
| 9/25 | 가입·페어링·오늘 Mock 화면, 녹음 로컬 동작, 자녀 답변 Mock 화면 |
| 9/26 | 가입·페어링 실제 API, 녹음 업로드 Mock, 상태별 UI |
| 9/27 | `GET /today`, 답변 PUT, 녹음 업로드·폴링 실제 API 연동 |
| 9/28 | 공개 답변 재생·자막·TTS 상태, 지난 이야기 Mock |
| 9/29 | 지난 이야기 실제 API, 전체 정상 흐름 통합 |
| 9/30 | 실패·재시도·권한·백그라운드 복귀 테스트 |
| 10/1 | 접근성 QA, 실기기 통합, 데모 데이터 준비 |
| 10/2 | 최종 빌드와 데모 리허설 |

## 10. 네트워크·에러 규칙

- `401`: token 제거 후 가입 화면으로 이동하되 사용자가 이해할 안내를 표시한다.
- `403`: 권한 없는 화면으로 진입하지 못하게 하고 홈으로 복귀한다.
- `409`: `errorCode`에 따라 이미 페어링됨, 사용된 코드, 공개 후 수정 불가를 구분한다.
- `413/422`: 녹음 크기·길이 안내 후 다시 녹음하게 한다.
- `429/5xx`: 일정 시간 후 재시도할 수 있게 한다.
- 서버 `message`를 그대로 노출하기보다 앱용 문구로 매핑하고 `traceId`는 문의용으로
  보관할 수 있다.

API 계약이 실제 응답과 다르면 프론트에서 임시 우회 필드를 만들지 않는다.
`[API]` GitHub Issue를 만들고 계약 문서, 백엔드 DTO, 프론트 DTO·Mock을 같은 변경
단위로 맞춘다.

## 11. 완료 기준

- `dart format .`
- `flutter analyze`
- 핵심 provider/repository unit test 또는 widget test
- 부모·자녀 정상 흐름을 Android 에뮬레이터에서 각각 확인
- API 변경 시 DTO와 Mock fixture를 함께 갱신
- 실제 token, 개인정보, signed URL query를 로그에 남기지 않음

## 12. 에이전트 작업 절차

사람과 AI 코딩 에이전트가 같은 순서로 작업한다.

1. 작업 전 `git pull --ff-only origin main`으로 최신화하고 `feature/<기능명>` 브랜치를 만든다.
2. 화면이 쓰는 API를 [`../docs/api-contract.md`](../docs/api-contract.md)에서 찾고,
   필요한 Mock이 `assets/mocks/`에 있는지 확인한다. 없으면 계약 예시 JSON을 그대로
   옮겨 추가한다.
3. `features/<기능명>/data → domain → presentation` 순서로 만든다. 새 DataSource는
   `features/onboarding/data/auth_data_source.dart`의 Mock/API 교체 패턴을 따른다.
4. 담당 화면은 `lib/app/router.dart`에서 자기 경로의 `builder`만 교체한다.
5. 작업 디렉터리 `frontend/`에서 아래를 모두 통과시킨 뒤 PR을 연다.

```bash
dart format .
flutter analyze
flutter test
```

### 공통 파일

다음 파일은 여러 담당자가 함께 쓴다. 수정이 필요하면 PR 전에 팀에 먼저 공유하고,
PR 본문에 영향 받는 화면을 적는다.

| 파일 | 이유 |
|---|---|
| `pubspec.yaml` | 패키지 추가는 모든 팀원의 `pub get`에 영향 |
| `lib/app/router.dart` | 경로 추가·redirect는 전체 화면 흐름에 영향 |
| `lib/core/**` | Dio, 토큰 저장, 테마, 공통 위젯 |
| `assets/mocks/*.json` | 계약 예시와 1:1로 맞춰야 함 |

### 계약과 현재 구현의 차이 (2026-09-24 기준)

화면이 계약과 다르게 동작하면 아래를 먼저 확인한다. 해결되면 이 목록에서 지운다.

- `GET /today`는 아직 답변 제출 API가 없어서 항상 `WAITING_FOR_BOTH`와
  `NOT_SUBMITTED`를 반환한다. 이 상태의 Mock(`today_waiting_for_both.json`)이 없다.
- 질문 `audioUrl`은 질문 안내 TTS가 준비될 때까지 `null`이다. 재생 버튼은 `null`이면
  숨긴다.
- 백엔드에는 `INVITE_CODE_NOT_FOUND`(404), `INVITE_CODE_EXPIRED`(409)가 있지만 계약
  에러 표에는 없다.
- 로그인 사용자 정보를 다시 조회하는 API(`GET /users/me`)가 없다. 앱 재실행 후 역할과
  페어링 여부는 가입 응답을 저장해 두거나 `GET /today`의 `409 PAIR_NOT_FOUND`로 판단한다.
- 백엔드 질문 seed는 2026-09-24 ~ 2026-10-02 9일치다. 그 이후 날짜는
  `404 TODAY_ASSIGNMENT_NOT_FOUND`가 난다.
