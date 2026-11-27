# 들려줘요 지원 웹 페이지 — 검토용

앱 `legal_documents.dart`의 개인정보 처리방침을 직접 가져와 정적 HTML로 생성한다.
정적 사이트에는 별도 로그인, 분석 SDK, 쿠키, 접수 DB가 없다.
실제 본인 확인·삭제는 별도의 백엔드 웹 경로에서 수행한다.
이메일 버튼은 메일 앱을 열 뿐이며 실제 발송·접수를 보장하지 않는다.
`dist/`는 생성 산출물이며 커밋하지 않는다.

## 생성·미리보기

저장소 루트에서:

```bash
dart run support-site/build.dart
python3 -m http.server 4173 --bind 127.0.0.1 --directory support-site/dist
```

웹 삭제를 설정·배포·QA한 뒤 링크를 연결할 때:

```bash
dart run support-site/build.dart --deletion-url=https://실제-백엔드-도메인/account-deletion
```

고정 HTTPS 주소만 허용한다. URL을 생략하면 미연결 안내가 표시된다.
URL 연결만으로 서버 기능이 활성화되지는 않는다.

브라우저에서 `http://127.0.0.1:4173`을 연다. 종료는 서버 터미널에서 Ctrl+C.

- `index.html`: 운영팀·문의·메뉴
- `privacy.html`: 앱 원문으로 생성한 개인정보 처리방침과 목차
- `deletion.html`: 앱 내부 탈퇴 경로·웹 본인 확인 연결·이메일 문의·삭제/보존 범위

## 공개 전 필수

- `docs/privacy-policy-release-checklist.md`와 `docs/account-deletion-operations.md`의 미확정 사항 완료.
- 문의 채널만 만든 것으로 웹 삭제 절차 구현 완료라고 판단하지 않는다.
- 앱과 웹 원문은 같은 Git revision으로 생성. 앱 처리방침 변경 시 다시 생성·배포.
- 업체 실제 국가와 삭제 기간을 확인하고 원문에 반영.
- `docs/account-deletion-operations.md`에 따라 카카오 콘솔·백엔드 변수를 설정하고 부모·자녀 웹 삭제를 실환경 검증.
- `build.dart`의 초안 배너와 noindex를 최종 검토 후 수정. noindex는 비공개·접근 제어가 아니다.
- 공개 주소를 모바일·시크릿 창에서 로그인 없이 열어 확인.

## GitHub Pages 배포 준비

현재 자동 공개 workflow는 없다. 미확정 문구가 main 병합만으로 공개되지 않게 했다.
팀이 공개를 승인한 뒤 저장소 Settings → Pages에서 GitHub Actions를 선택한다.
배포 workflow는 Dart로 위 생성 명령을 실행하고 `support-site/dist`만 Pages artifact로 업로드해 배포하도록 추가한다.
저장소가 공개인지·GitHub Pages 사용이 가능한 요금제인지와 Settings 권한을 확인한다.
조직 저장소의 권한이 없으면 소유자에게 설정을 요청한다. 백엔드/Railway 환경변수·DB는 연결하지 않는다.
기본 주소가 확정되면 개인정보 처리방침 URL과 삭제 요청 URL을 각각 스토어 콘솔에 등록한다.

공개된 정적 파일에는 실제 삭제 요청·계정 ID·처리 기록·비밀값을 절대 넣지 않는다.
