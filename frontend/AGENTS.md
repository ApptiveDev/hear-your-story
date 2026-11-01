# frontend/AGENTS.md — Flutter 규칙

작업 전 루트 [`../AGENTS.md`](../AGENTS.md)와 API 계약
[`../docs/api-contract.md`](../docs/api-contract.md)을 읽는다. 실행 방법·폴더 구조·Mock
목록은 [`README.md`](README.md)를 보고 이 문서에 중복 작성하지 않는다.

## 기술 및 구조

- Flutter 3.47.5 stable, Android 전용. 버전은 CI(`.github/workflows/frontend-ci.yml`)와 맞춘다.
- `flutter_riverpod` 상태관리, `go_router` 라우팅, `dio` 네트워크, `flutter_secure_storage`
  토큰, `record` 녹음(m4a/AAC-LC, 최대 60초), `just_audio` 재생. 모델은 수동 DTO를 쓴다.
- 기능은 `lib/features/<기능>/data → domain → presentation`으로 나눈다. 화면 Widget에서
  Dio를 직접 호출하지 않고 DataSource·Repository를 거친다.
- 색·글꼴·크기는 `lib/core/theme/app_tokens.dart`(Figma 토큰)와 `AppTheme`만 쓰고 화면에
  색상값이나 글자 크기를 새로 하드코딩하지 않는다.
- 공통 파일(`pubspec.yaml`, `lib/app/router.dart`, `lib/core/**`, `assets/mocks/`)을 바꾸면
  PR 본문에 영향받는 화면을 적는다.

## Commands

`frontend/`에서 실행한다. PR 전에는 아래 format 검사·analyze·test를 모두 통과해야 하며
CI도 같은 명령을 실행한다.

```bash
flutter pub get                                      # 의존성 설치
dart format .                                        # 형식 자동 정리
dart format --output=none --set-exit-if-changed .    # 형식 위반 검사 (CI)
flutter analyze                                      # 린터·정적 분석
flutter test                                         # Unit·Widget 테스트
```

## API 계약 및 Mock

- API 필드·enum·에러 형식은 `docs/api-contract.md`가 기준이다. 실제 응답과 다르면 임시
  필드나 우회 로직을 만들지 않고 `[API]` Issue로 알린다.
- API를 바꾸면 DTO·도메인 모델·`assets/mocks/` fixture·관련 테스트를 같은 PR에서 고친다.
- Mock과 실제 API는 DataSource 주입과 `--dart-define`(`USE_MOCK`, `MOCK_*`)으로 바꾼다.
- 공개 여부를 앱에서 계산하지 않는다. 서버의 `revealStatus`와 `canViewPartnerAnswer`만
  사용한다. 확정되지 않은 공개 정책(건너뛰기 `SKIPPED` 등)은 임의로 구현하지 않는다.
- 서명 URL은 만료 시 화면 provider를 갱신하지 말고 새 URL만 다시 받아 재생한다
  (`AudioPlaybackCard`의 `onRefresh`).

## 화면 상태와 에러 처리

주요 화면은 loading·empty·success·retry·error와 권한·공개 대기 상태를 모두 처리한다.
무한 로딩 대신 안내를 보여주고, 서버 `message`나 stack trace를 그대로 노출하지 않는다.

| 응답 | 처리 |
|---|---|
| `401` | `handleSessionExpired`로 토큰·사용자 정보를 지우고 안내와 함께 가입 화면으로 |
| `403` | 권한 없는 화면 진입을 막고 홈으로 |
| `409` | `errorCode`별 안내 (이미 연결됨, 사용·만료된 숫자, 공개 후 수정 불가 등) |
| `413`·`422` | 녹음 크기·길이 조건 안내 후 다시 녹음 |
| `429`·`5xx`·네트워크 | 재시도 버튼. provider 재시도는 `retryTransientOnly` 사용 |

## 시니어 UX

- 부모 화면은 큰 글씨·높은 대비·넓은 터치 영역, 한 화면에 주요 행동 하나다.
- 부모 화면의 모든 기능은 홈에서 3번 누르기 안에 끝난다. 단계를 늘리면 먼저 공유한다.
- 상태를 색에만 의존하지 않고 글과 아이콘을 함께 쓴다. 미응답을 재촉·죄책감으로
  표현하지 않는다.

## 보안

- access token은 `flutter_secure_storage`에만 저장한다.
- API 주소·환경값은 `--dart-define`으로 전달하고 운영·스테이징 URL, API key를 커밋하지 않는다.
- 토큰, 개인정보, 답변 원문, 서명 URL query를 로그(`print`, `debugPrint`)에 남기지 않는다.

## 테스트 및 완료 기준

- Provider·Repository 로직은 Unit Test, 주요 화면 상태는 Widget Test로 검증한다.
- 정상 화면만이 아니라 loading·empty·retry·error와 401·409 같은 실패 경로도 검증한다.
- 버그 수정은 가능하면 실패하는 테스트를 먼저 추가한 뒤 최소 범위로 고친다.
- 화면 테스트는 폰 크기(`test/helpers/phone_size.dart`)로 그리고, 새 화면은
  `test/features/large_text_test.dart`의 글씨 1.3·2배 검사에 추가한다.
- 화면 변경은 에뮬레이터나 웹(Mock)에서 직접 확인하고, 하지 못했으면 PR에 적는다.

## Frontend Code Review Rules

`@codex review`와 사람 리뷰는 프론트 PR에서 다음을 우선 확인한다.

- 공개 여부를 클라이언트에서 재계산하지 않고 `revealStatus`·`canViewPartnerAnswer`를 쓰는가
- API 모델·Mock fixture가 `docs/api-contract.md`와 일치하는가
- loading·empty·retry·error·401 처리가 빠지지 않았는가
- 토큰·개인정보·서명 URL query가 로그나 화면에 노출되지 않는가
- Widget에서 API를 직접 호출하거나 DataSource·Repository 구조를 우회하지 않는가
- 디자인 토큰 대신 색·크기를 하드코딩하지 않았는가
- 변경된 동작에 필요한 Unit·Widget 테스트가 있는가
