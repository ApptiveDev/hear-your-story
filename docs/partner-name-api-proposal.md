# [API] 사용자 응답에 연결된 상대 이름 추가 — 담당자 확인 대기

외부 Issue는 아직 생성하지 않았다. 이 문서를 Issue 본문 초안으로 사용한다.
백엔드 구현을 검토 가능하게 준비한 단계이며, 프론트 담당자 확인과 모델·Mock 동기화,
`api-contract.md` 및 변경 이력 반영을 같은 PR에서 마친 뒤 병합한다.

## 영향 범위

- `GET /users/me`, `PATCH /users/me`의 사용자 응답
- `POST /auth/kakao`의 기존 계정 `user`, `POST /users`의 가입 완료 `user`
- 요청, 인증, HTTP 상태와 기존 오류 코드는 변경하지 않는다.

현재 JSON:

```json
{"id":"usr_example","name":"영희","role":"PARENT","pairingStatus":"PAIRED"}
```

제안 JSON:

```json
{"id":"usr_example","name":"영희","role":"PARENT","pairingStatus":"PAIRED","partnerName":"민수"}
```

- 현재 활성 Pair의 상대가 서비스에 등록한 이름만 반환한다. 카카오 프로필 이름이 아니다.
- 연결 전·상대 탈퇴·연결 해제 상태는 `UNPAIRED`, `partnerName: null`이다.
- 과거 Pair나 다른 사용자의 상대 이름은 반환하지 않는다.
- 상대 이름 변경은 다음 서버 조회부터 반영된다. DB 스키마 변경은 없다.
- 가입 미완료 `REGISTRATION_REQUIRED` 응답에는 원래처럼 `user`가 없다.

## 프론트 전달사항

1. `AppUser` 파싱·저장·copyWith에 nullable `partnerName`을 추가한다. 이전 저장 데이터는 누락 시 null로 읽는다.
2. API Mock과 관련 테스트를 동기화한다.
3. 마이페이지 진입/복귀 및 페어링 완료 시 `GET /users/me`로 최신 사용자 정보를 받고 provider를 갱신한다.
   기존 페어링 로직은 연결 상태만 로컬에 저장하므로 invalidate만으로 상대 이름이 생기지 않는다.
4. 마이페이지는 `민수님과 연결되어 있어요`처럼 표시한다. 구버전 서버·오프라인에서
   상대 이름이 없으면 기존 역할 기반 문구를 사용한다. 미연결은 기존 문구를 유지한다.
5. 부모·자녀 각각 연결 직후, 이름 변경 후, 상대 탈퇴 후, 재페어링 후를 재검증한다.

## 확인 항목

- [ ] 프론트·백엔드 담당자 계약 확인
- [ ] [API] Issue 등록 및 연결
- [ ] 계약 문서·변경 이력·프론트 모델·Mock·테스트 동기화
- [ ] 두 기기 마이페이지 표시·갱신 QA
