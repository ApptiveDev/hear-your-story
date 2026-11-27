# [API] 앱 밖 계정 삭제를 위한 카카오 웹 본인 확인 경로

[API Issue #105](https://github.com/ApptiveDev/hear-your-story/issues/105)에 등록한 구현안이다.
담당자 확인·실환경 QA 전이므로 확정 계약이나 출시 완료로 간주하지 않는다.

## 현재·제안

- 현재: `DELETE /api/v1/users/me`는 본인 앱 access token 필요. 브라우저 삭제 경로 없음.
- 이메일 주소·이름만으로는 카카오 계정 소유권을 확인할 수 없음.
- 제안: API 계약 5.17의 브라우저 경로 추가. 서버 OIDC → 기존 계정 확인 → CSRF 폼 명시적 확정
  → 기존 AccountDeletionService 재사용. 별도 운영자 삭제 API·임의 JWT 발급 없음.
- 현재·제안 JSON 변경 없음. 새 경로는 HTML이며 기존 모바일 JSON·Flutter 모델·Mock 변경 없음.

## 영향·검증

- 서버 OAuth2 Client, 별도 보안 체인·10분 세션·기본 비활성화 설정.
- 공개 사이트에서 설정된 고정 HTTPS 웹 삭제 URL 연결.
- DB migration 없음. 기존 부모·자녀 삭제 범위·R2/카카오 영속 큐 재사용.
- 자동 검증: state·nonce·서명·issuer·audience, 위조 폼·만료·계정 구분·삭제·취소·재사용.
- 실환경: 같은 카카오 앱, HTTPS 콜백·쿠키·부모/자녀 테스트 계정 전체 QA 필요.

## 병합 전 확인

- [x] API Issue #105 등록.
- [ ] 백엔드·프론트 담당자 확인.
- [ ] 기존 Flutter 영향 없음과 브라우저 계약 확인.
- [ ] 카카오 콘솔·서버 설정 및 스테이징 QA.
