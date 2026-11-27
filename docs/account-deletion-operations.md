# 웹 계정 삭제 운영 절차

담당: 제수지 / 문의: jesuji030502@naver.com.
구현과 공개 운영을 구분한다. 활성화·실환경 QA 전에는 스토어 삭제 경로로 제출하지 않는다.

## 삭제 흐름

1. 지원 사이트의 삭제 안내 → 백엔드 HTTPS `/account-deletion` 이동.
2. 가입했던 카카오 계정으로 웹 본인 확인. 앱 설치 불필요.
3. 서버가 검증한 `sub`에 연결된 기존 계정의 이름·역할과 삭제 범위 확인.
4. 동의 체크 후 확정. 로그인·페이지 조회·취소만으로는 삭제되지 않음.
5. 기존 AccountDeletionService가 접근 차단·가족 연결 해제·본인 답변 내용 제거.
6. 영속 큐가 R2 파일 삭제·카카오 연결 해제 수행. 실패 시 재시도.
7. 접수 화면은 완료 화면이 아님. 운영자가 아래 조회로 지연·실패 확인.

이메일은 문의 채널이다. 발신 주소·이름만으로 소유권을 인정하거나 삭제하지 않는다.
앱을 쓸 수 없으면 웹 본인 확인 경로를 안내한다. 카카오 자체에 접근하지 못하면 먼저
카카오 계정 복구를 안내한다. 비밀번호·토큰·신분증을 메일로 받지 않는다.
운영자 삭제 API·임의 JWT 발급·SQL 직접 삭제·TRUNCATE는 이 절차에 포함하지 않는다.

## 활성화: 운영자가 할 일

1. 앱과 **동일한 카카오 Developers 앱**을 선택한다. 카카오 로그인·OpenID Connect 활성화 확인.
2. Redirect URI에 `https://실제-백엔드-도메인/login/oauth2/code/kakao-deletion`을 정확히 등록.
3. 해당 앱의 REST API 키와 Client Secret 발급·활성화 상태 확인. 서버에만 주입한다.
4. Railway에 아래 변수 설정 후 배포한다.

```ini
WEB_DELETION_ENABLED=true
KAKAO_REST_API_KEY=실제값은_서버에만_입력
KAKAO_CLIENT_SECRET=실제값은_서버에만_입력
WEB_DELETION_REDIRECT_URI=https://실제-백엔드-도메인/login/oauth2/code/kakao-deletion
```

기존 `KAKAO_ADMIN_KEY`도 유효해야 연결 해제가 완료된다. REST 키·시크릿은 Flutter에 넣지 않는다.
staging·production의 콜백·변수·스토어 링크를 구분한다. 활성화 상태에서 변수 누락이나
HTTP/임의 콜백 경로는 서버 시작 단계에서 차단하므로 설정을 준비한 뒤 켠다.
세션은 메모리에 저장한다. 현재 단일 replica에서 운영하며 재시작 시 다시 본인 확인한다.
replica를 늘리기 전 공유 세션 저장소나 검증된 세션 고정 정책이 필요하다.

5. 사이트를 `--deletion-url=https://실제-백엔드-도메인/account-deletion`으로 생성한다.
   기본 생성은 연결 미설정 안내를 표시하며 운영 URL을 추측하지 않는다.
6. 아래 QA와 개인정보 처리방침의 미확정 사항을 마친 뒤 사이트 공개·스토어 등록한다.

## 출시 전 실환경 QA

- [ ] 모바일 브라우저·시크릿 창에서 앱 없이 안내 열기, 카카오 로그인.
- [ ] 같은 계정의 이름·역할 표시. 로그인만으로 가입·탈퇴하지 않음.
- [ ] 취소하면 앱 계정·페어·기록 유지.
- [ ] 테스트 부모·자녀 각각 확정: 기존 앱 토큰 차단, 본인 자료 삭제·상대 기록 보존.
- [ ] 10분 만료·새로고침·뒤로가기·중복 제출에서 다른 계정/새 가입 계정 삭제 없음.
- [ ] 요청 COMPLETED·남은 작업 없음, 대상 R2 객체 삭제 확인.
- [ ] 재가입 시 삭제된 본인 기록 복원 없음. 앱 기존 로그인·탈퇴 유지.
- [ ] 인증·프록시 로그에 토큰·code·state·sub·전체 콜백 query가 기록되지 않는지 확인.
  운영에서 Spring Security HTTP DEBUG/TRACE·요청 본문 로깅을 켜지 않음.

## 지연 확인: 읽기 전용

```sql
SELECT id, status, requested_at, completed_at
FROM account_deletion_requests ORDER BY requested_at DESC LIMIT 20;

SELECT deletion_request_id, task_type, status, attempts, last_failure_code, next_attempt_at
FROM account_deletion_tasks ORDER BY created_at DESC LIMIT 50;
```

운영 담당자는 운영일 매일 미완료 요청·재시도를 확인하고 키·권한 오류를 수정한 뒤 완료까지 추적한다.
완료 전에 모든 삭제가 끝났다고 회신하지 않는다. 자동 재시도만으로 최대 완료 기한이 보장되지는
않으므로 실제 대응 가능한 목표 기한·대체 담당자는 출시 전에 정한다.
메일 알림·테스트 수신도 확인한다. 문의 메일과 처리 기록의 보관 기간을 정하고 방침에 반영한다.
실제 사용자·계정 ID·요청 기록은 공개 Git/Issues/Pages에 남기지 않는다.

## 근거

- [카카오 로그인 REST API](https://developers.kakao.com/docs/latest/ko/kakaologin/rest-api)
- [Google Play 계정 삭제 요구사항](https://support.google.com/googleplay/android-developer/answer/13327111?hl=ko)

구현·QA가 스토어 심사 승인이나 법적 적합성을 보장하지는 않는다.
