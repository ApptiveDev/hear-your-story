# [API] 부모 녹음·자녀 답변 개별 삭제

[API Issue #93](https://github.com/ApptiveDev/hear-your-story/issues/93)에 등록했다.
프론트 담당자의 계약 확인과 실제 서버·기기 연동 QA는 PR에서 확인한다.

## 영향 endpoint

- DELETE /api/v1/recordings/{recordingId}
- DELETE /api/v1/answers/{answerId}
- GET /api/v1/stories (목록·월별)
- GET /api/v1/today
- PUT /api/v1/assignments/{assignmentId}/parent-recording
- PUT /api/v1/assignments/{assignmentId}/child-answer
- GET /api/v1/recordings/{recordingId}
- GET /api/v1/answers/{answerId}/audio

## 현재 → 구현 후

- 삭제 endpoint 없음 → 작성자 본인만 삭제, 성공 204 (응답 body 없음).
- 없는/삭제된 녹음은 404 RECORDING_NOT_FOUND, 답변은 404 ANSWER_NOT_FOUND.
- 다른 작성자의 리소스는 403 RESOURCE_ACCESS_DENIED, 미인증은 401.
- 과거 Pair의 본인 답도 삭제 가능. 질문·상대 답·제출 및 공개 이력 유지.
- 지난 이야기 parentAnswer/childAnswer는 기존 nullable DELETED 계약 사용.
- 원본 음성·STT·요약 또는 텍스트·TTS를 DB에서 즉시 비우고 파일은 영속 큐에서 삭제.
- 삭제 후 기존 STT/TTS 버전은 무효화. 파일 실패·서버 재시작 시 재시도.
- 삭제한 날 재작성은 차단하는 것으로 사용자 확인 완료 (409 ANSWER_LOCKED).

## 오늘 질문 응답 JSON

현재 myAnswer/partnerAnswer 예시:

```json
{"type":"TEXT","answerId":"ans_example","text":"내 답변","ttsStatus":"READY"}
```

삭제된 답변의 제안 JSON:

```json
{"type":"DELETED","availability":"DELETED","message":"삭제된 답이에요."}
```

부모 녹음 안내는 `부모님이 이 음성 기록을 삭제했어요.`로 표시한다.
공개 전 partnerAnswer는 계속 숨긴다. SUBMITTED 이력은 유지한다.

## 연동 확인

- 프론트 기존 DELETE 요청·204 처리는 유지.
- 오늘 질문 DeletedAnswer 모델·Mock·화면, 부모 답변 확인 파싱을 함께 보완.
- 삭제 성공 시 오늘 질문 캐시도 갱신. 삭제된 답은 수정·재녹음·TTS 요청 차단.
- 영향 화면: 홈, 부모 답변 확인, 지난 이야기·달력 상세.
- 프론트 담당자 계약 확인 및 실제 서버·기기 연동 QA는 PR에서 별도 확인 필요.
