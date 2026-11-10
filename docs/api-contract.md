# API 계약 v0.1 — 2026-11-04 출시 준비

이 문서는 Flutter와 Spring Boot 사이의 **단일 API 계약(source of truth)**이다.
프론트는 이 문서의 예시 JSON으로 Mock을 만들고, 백엔드는 동일한 필드와 상태값을
구현한다. `확정`으로 표시된 계약만 현재 구현 기준으로 사용한다. `초안`은 이후
개발을 위한 요구사항이며, 프론트와 백엔드 구현·테스트·Mock이 함께 준비되기 전에는
실제 endpoint를 호출하거나 현재 응답 모델에 적용하지 않는다.

- Base URL: `/api/v1`
- 인증: `Authorization: Bearer {accessToken}`
- Content-Type: 기본 `application/json`, 녹음·사진 업로드는
  `multipart/form-data`
- 출시 준비 범위: 월별 지난 이야기, 사진 첨부, 녹음·계정 삭제

## 1. 공개 정책과 미확정 계약

현재 공개 정책은 `MUTUAL_SUBMISSION`이다. 부모와 자녀가 모두 답하면
`REVEALED`가 되고, 한쪽이라도 답하지 않았다면 상대방 답변을 공개하지 않는다.
클라이언트가 이를 다시 계산하지 않도록 모든 조회 응답에 서버가 계산한
`revealStatus`와 `canViewPartnerAnswer`를 내려준다.

프론트는 다음 상태를 모두 표시한다.

- `WAITING_FOR_PARENT`: 부모 답변 대기
- `WAITING_FOR_CHILD`: 자녀 답변 대기
- `WAITING_FOR_BOTH`: 양쪽 답변 대기
- `REVEALED`: 상대 답변 공개

공개된 답변은 수정할 수 없고 `409 ANSWER_LOCKED`를 반환한다. `SKIPPED`는 예약
enum이지만 현재 화면에는 건너뛰기 동작을 노출하지 않는다. 프론트는 항상 서버의
`revealStatus`와 `canViewPartnerAnswer`만 신뢰한다.

### 1.1 출시 준비 기능 — 개발 초안

다음 기능은 요구사항만 합의한 **미구현 초안**이다. 현재 서버와 앱이 지원하는
계약으로 간주하지 않는다.

| 기능 | 현재 동작 | 구현 PR에서 함께 변경할 항목 |
|---|---|---|
| `PUT /assignments/{assignmentId}/my-photo` | 미구현 | 백엔드 저장·권한·DTO·테스트, 프론트 모델·업로드·Mock·테스트 |
| `DELETE /assignments/{assignmentId}/my-photo` | 미구현 | 백엔드 삭제·권한·테스트, 프론트 삭제 흐름·Mock·테스트 |
| `DELETE /recordings/{recordingId}`와 삭제된 답변 응답 | 삭제 endpoint와 `availability=DELETED` 응답이 미구현이며, 현재 프론트는 `recordingId`와 `processingStatus`를 필수 문자열로 파싱한다. | 백엔드 삭제·nullable DTO·테스트, 프론트 nullable 모델·재생 차단·Mock·파싱 테스트 |
| `DELETE /users/me` | 미구현 | 백엔드 비활성화·삭제 작업·테스트, 프론트 세션 정리·Mock·테스트 |

이 기능에만 쓰이는 `availability`, `myPhoto`, `partnerPhoto`, `parentPhoto`,
`childPhoto`, `AnswerAvailability`와 사진·삭제 관련 `errorCode`도 모두 초안이다.
확정 endpoint의 예시 JSON에 표시되어 있더라도 현재 응답에는 포함되지 않는다.

각 기능은 루트 `AGENTS.md`의 API 계약 변경 절차에 따라 `[API]` Issue에 현재·제안
JSON을 기록하고 프론트·백엔드 담당자가 확인한 뒤, 구현과 같은 PR에서 해당 항목을
`확정`으로 바꾼다. 그전에는 월별 조회를 호출하거나 `DELETED` 응답을 내려서는 안 된다.

### 1.2 재로그인·기록 복구 — 초안

재로그인과 계정 복구는 추가 회의 전까지 **초안**이다. 프론트는 5.14의 상태와
예시 JSON으로 화면·Mock을 만들 수 있지만 실제 endpoint를 호출하거나 기존 가입
흐름을 교체하지 않는다. 다음 항목을 확정한 뒤 이 표시를 `확정`으로 바꾼다.

1. 본인 확인 수단과 인증 제공자
2. 기존 `deviceId` 계정을 새 인증 수단에 연결하는 방법
3. access token·refresh token 수명과 폐기 방법
4. 기기 변경 후 기존 Pair·지난 이야기 복구 범위
5. 중복 계정 병합과 만 14세 미만 사용자의 동의 절차

## 2. 공통 규칙

### 2.1 ID와 시간

- 모든 ID는 JSON `string`이다. `usr_`, `pair_`, `asg_` 등의 접두사는 예시일
  뿐이므로 클라이언트가 ID 내부 구조를 해석하지 않는다.
- 날짜는 `YYYY-MM-DD`, 시각은 UTC offset이 포함된 ISO-8601 문자열이다.
- 일일 질문 배정·날짜 경계의 기준 시간대는 `Asia/Seoul`이다.

```json
{
  "id": "asg_01J8M6WQ0G5D6S8KZC8V2J2X5P",
  "assignedDate": "2026-09-24",
  "createdAt": "2026-09-24T09:30:00+09:00"
}
```

### 2.2 필드와 HTTP 상태

- 필드 이름은 `camelCase`를 사용한다.
- 값이 아직 없지만 의미 있는 필드는 `null`로 내려준다.
- 권한 때문에 공개할 수 없는 상대방 데이터는 필드 자체를 생략한다.
- 생성 `201`, 비동기 처리 시작 `202`, 정상 조회·수정 `200`, body 없는 성공
  `204`를 사용한다.
- 프론트는 화면 분기를 HTTP 문구가 아니라 `errorCode`와 상태 enum으로 처리한다.

### 2.3 공통 에러 응답

```json
{
  "timestamp": "2026-09-24T10:15:30+09:00",
  "status": 400,
  "errorCode": "INVALID_AUDIO_FORMAT",
  "message": "m4a(AAC) 형식의 녹음 파일만 업로드할 수 있습니다.",
  "path": "/api/v1/assignments/asg_123/parent-recording",
  "traceId": "01J8M7N6XH7VMM5T0J7D4A6W9K",
  "fieldErrors": [
    { "field": "audioFile", "reason": "unsupported_content_type" }
  ]
}
```

`fieldErrors`가 없으면 빈 배열 `[]`을 내려준다.

| HTTP | 대표 `errorCode` | 의미 |
|---|---|---|
| 400 | `VALIDATION_ERROR`, `INVALID_AUDIO_FORMAT`, `INVALID_IMAGE_FORMAT` | 요청값 오류 |
| 401 | `UNAUTHORIZED`, `TOKEN_EXPIRED` | 토큰 없음·만료 |
| 403 | `ROLE_NOT_ALLOWED`, `PAIR_ACCESS_DENIED`, `RESOURCE_ACCESS_DENIED` | 역할·소유권 오류 |
| 404 | `USER_NOT_FOUND`, `ASSIGNMENT_NOT_FOUND`, `RECORDING_NOT_FOUND`, `PHOTO_NOT_FOUND`, `INVITE_CODE_NOT_FOUND`, `TODAY_ASSIGNMENT_NOT_FOUND` | 리소스 없음 |
| 409 | `ALREADY_PAIRED`, `PAIR_NOT_FOUND`, `INVITE_CODE_USED`, `INVITE_CODE_EXPIRED`, `ANSWER_LOCKED`, `ACCOUNT_DELETION_IN_PROGRESS` | 현재 상태와 충돌 |
| 413 | `AUDIO_FILE_TOO_LARGE`, `IMAGE_FILE_TOO_LARGE` | 파일 크기 초과 |
| 422 | `AUDIO_DURATION_OUT_OF_RANGE`, `IMAGE_DIMENSION_OUT_OF_RANGE` | 파일 제약 조건 오류 |
| 429 | `RATE_LIMITED` | 요청 빈도 제한 |
| 500 | `INTERNAL_ERROR` | 서버 내부 오류 |
| 502 | `AI_PROVIDER_ERROR`, `STORAGE_ERROR` | 외부 연동 오류 |

### 2.4 인증과 권한

- 현재 확정 계약에서는 `POST /users`만 인증 없이 호출한다.
- 서버가 HS256 JWT access token을 발급한다. payload에는 `sub`(userId),
  `role`, `iat`, `exp`만 넣는다.
- 현재 access token 만료 기간은 30일이다. refresh token과 본인 확인 방식은
  5.14의 초안이 확정되기 전까지 구현 기준이 아니다.
- 토큰 원문은 DB에 저장하지 않는다.
- `pairId`는 가능한 한 토큰의 현재 사용자로부터 서버가 찾는다. 요청자가 해당
  Pair/Assignment의 구성원인지 모든 API에서 검사한다.

### 2.5 수정·재시도·중복 요청

- 자녀 답변은 공개 전까지 같은 `PUT` 요청으로 수정할 수 있다.
- 부모 녹음은 공개 전까지 같은 `PUT` 요청으로 재녹음할 수 있다. 새 녹음이
  정상 업로드된 뒤 이전 파일을 대체한다.
- 공개 이후 수정 요청은 `409 ANSWER_LOCKED`를 반환한다. 이 정책은 회의 결과에
  따라 변경될 수 있다.
- `PUT` 엔드포인트는 동일 요청을 다시 보내도 최종 상태가 하나만 남도록 한다.
- 녹음 업로드에는 `Idempotency-Key` 헤더를 권장한다. 같은 키의 재요청은 새
  Recording을 만들지 않고 최초 응답을 반환한다.

### 2.6 녹음 파일

- 파일 확장자·코덱: `.m4a`, AAC-LC
- 허용 MIME: `audio/mp4`, `audio/m4a`, `audio/aac`
- 권장 길이: 30~60초, MVP 허용 길이: 1~60초
- 최대 크기: 10 MiB
- 업로드 필드명: `audioFile`
- 원본은 비공개 R2 bucket에 저장한다. DB에는 공개 URL이 아닌 object key를
  저장하고, 조회 시 만료 시간이 짧은 signed URL을 반환한다.

다음 일시정지 요구사항은 프론트 개발 초안이다.

- 일시정지·이어 녹음은 Flutter 앱 내부 동작이다. 여러 번 일시정지하더라도 앱은
  재생 가능한 `.m4a` 파일 **하나**를 만들고 기존 업로드 API를 한 번 호출한다.
- 60초 제한은 일시정지한 시간을 제외한 실제 녹음 시간의 합으로 계산한다.
- 녹음 조각을 서버에 따로 업로드하거나 서버에서 합치는 방식은 이 계약 범위가
  아니다.

### 2.7 녹음 처리와 폴링

`processingStatus` 값:

```text
UPLOADED -> STT_PROCESSING -> STT_DONE -> LLM_PROCESSING -> READY
                                                        \-> FAILED
              각 단계의 복구 불가능한 오류 -----------> FAILED
```

- 프론트는 최초 30초 동안 3초, 이후 5초 간격으로 조회한다.
- `READY` 또는 `FAILED`이면 폴링을 종료한다.
- 총 60초가 지나면 폴링을 멈추고 "처리 중" 화면을 보여준다. 사용자가 다시
  진입하면 상태를 재조회한다.
- 앱이 백그라운드로 가면 폴링을 중지하고 복귀할 때 재조회한다.

AI 처리는 제출 여부와 분리한다. R2 업로드가 성공하면 부모는 `SUBMITTED`이며,
STT/LLM이 실패해도 원본 음성은 보존한다. 공개 정책상 상대에게 공개 가능한
상태라면 원본 음성을 재생할 수 있고, `sttText`/`summaryText`는 `null`,
`processingNotice`에는 실패 안내를 내려준다. **AI 실패 때문에 가족 답변 전체를
영구 차단하지 않는다.**

### 2.8 페이지네이션

- `cursor`는 서버가 만든 불투명한 Base64URL 문자열이다.
- 클라이언트는 cursor를 해석하거나 직접 생성하지 않는다.
- 기본 `limit=20`, 최대 `50`이다.

```json
{
  "items": [],
  "nextCursor": "MjAyNi0wOS0wMVQwMDowMDowMFo6c3RvcnlfMTIz",
  "hasNext": true
}
```

### 2.9 사진 파일 — 초안, 미구현

- 부모와 자녀는 각 assignment에 본인이 올린 사진을 최대 1장 보관한다.
- 허용 MIME: `image/jpeg`, `image/png`, `image/webp`
- 최대 크기: 10 MiB, 한 변 최대 4096px
- 업로드 필드명: `photoFile`
- 원본과 썸네일은 비공개 R2 bucket에 저장하고 DB에는 object key만 저장한다.
- 조회 응답의 `url`, `thumbnailUrl`은 만료 시간이 짧은 signed URL이다. 만료되면
  원래 조회 API를 다시 호출한다.
- 공개 전에는 상대방 사진 필드를 생략하고, `REVEALED` 이후 또는 지난 이야기에서만
  서로의 사진을 반환한다.
- 커버 플로우는 `thumbnailUrl`을 사용하는 프론트 UI이며 별도 API가 아니다.

## 3. 상태 enum

| 이름 | 값 |
|---|---|
| `Role` | `PARENT`, `CHILD` |
| `SubmissionStatus` | `NOT_SUBMITTED`, `SUBMITTED`, `SKIPPED` |
| `ProcessingStatus` | `UPLOADED`, `STT_PROCESSING`, `STT_DONE`, `LLM_PROCESSING`, `READY`, `FAILED` |
| `TtsStatus` | `NOT_REQUESTED`, `PROCESSING`, `READY`, `FAILED` |
| `RevealStatus` | `WAITING_FOR_PARENT`, `WAITING_FOR_CHILD`, `WAITING_FOR_BOTH`, `REVEALED` |
| `AnswerAvailability` (초안) | `AVAILABLE`, `DELETED` |

`SKIPPED`는 공개 정책 회의에 대비해 enum에 예약하지만, 확정 전에는 클라이언트가
건너뛰기 버튼을 노출하지 않는다.

## 4. 확정 API 목록

| # | 메서드·경로 | 역할 | 용도 |
|---|---|---|---|
| 0 | `GET /health` | 공개 | 서버 상태 확인 |
| 1 | `POST /users` | 공개 | 간편 가입 및 access token 발급 |
| 2 | `POST /pairs/invitations` | 자녀 | 초대 코드 발급 |
| 3 | `POST /pairs/join` | 부모 | 초대 코드로 1:1 연결 |
| 4 | `GET /today` | 공통 | 오늘 질문·제출·공개 상태 통합 조회 |
| 5 | `PUT /assignments/{assignmentId}/parent-recording` | 부모 | 녹음 신규 제출·교체 |
| 6 | `GET /recordings/{recordingId}` | 부모 | STT/LLM 처리 상태 폴링 |
| 7 | `PUT /assignments/{assignmentId}/child-answer` | 자녀 | 텍스트 답변 신규 제출·수정 |
| 8 | `GET /answers/{answerId}/audio` | 부모 | 자녀 답변 TTS 상태·재생 URL 조회 |
| 9 | `GET /stories?cursor=&limit=` | 공통 | 공개된 지난 이야기 목록 |
| 10 | `GET /stories?month=YYYY-MM` | 공통 | 공개된 지난 이야기 월별 목록 |

`GET /questions/today`와 `GET /today?pairId=`는 제거한다. 오늘 화면은 `GET
/today` 하나로 통합하고 Pair는 인증 사용자로부터 서버가 결정한다.

추가 개발 예정 endpoint는 확정 목록에 포함하지 않는다. 요구사항과 현재 구현의
차이는 1.1과 각 `초안` 상세 절을 따른다.

## 5. API 상세와 Mock JSON

### 5.0 서버 상태 — `GET /health`

인증 없이 호출한다.

응답 `200 OK`:

```json
{
  "status": "UP",
  "timestamp": "2026-09-24T09:00:00+09:00"
}
```

### 5.1 가입 — `POST /users`

요청:

```json
{
  "name": "김영희",
  "role": "PARENT",
  "deviceId": "9a243caf-26e2-4d72-bf4c-6d643ee49cf9"
}
```

응답 `201 Created`:

```json
{
  "user": {
    "id": "usr_01J8M8A9G39WJMB5KVX46DP3FQ",
    "name": "김영희",
    "role": "PARENT",
    "pairingStatus": "UNPAIRED"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiJ9.example.signature",
  "tokenType": "Bearer",
  "expiresAt": "2026-10-24T09:00:00+09:00"
}
```

같은 `deviceId + role`의 재호출은 새 사용자를 중복 생성하지 않고 기존 사용자와
새 access token을 `200 OK`로 반환한다. MVP의 기기 변경·계정 복구는 지원하지
않으며 출시 전에 전화번호 인증 등으로 교체한다.

### 5.2 초대 코드 발급 — `POST /pairs/invitations`

자녀 토큰이 필요하다. body는 없다.

응답 `201 Created`:

```json
{
  "invitationId": "inv_01J8M8HE0DE9EAP9FDMRFFGBS7",
  "inviteCode": "482913",
  "expiresAt": "2026-09-25T09:10:00+09:00"
}
```

- 숫자 6자리, 유효기간 24시간, 1회용이다.
- 미사용 코드가 있으면 새 코드를 계속 만들지 않고 기존 코드를 반환해도 된다.

### 5.3 초대 코드 참여 — `POST /pairs/join`

부모 토큰이 필요하다.

요청:

```json
{
  "inviteCode": "482913"
}
```

응답 `201 Created`:

```json
{
  "pair": {
    "id": "pair_01J8M8P8WTTDQMK99PQK7TGJE8",
    "parent": {
      "id": "usr_parent_123",
      "name": "김영희"
    },
    "child": {
      "id": "usr_child_456",
      "name": "김민지"
    },
    "pairedAt": "2026-09-24T09:15:00+09:00"
  }
}
```

실패:

| HTTP | `errorCode` | 상황 |
|---|---|---|
| 404 | `INVITE_CODE_NOT_FOUND` | 없는 숫자 |
| 409 | `INVITE_CODE_USED` | 이미 다른 부모가 쓴 숫자 |
| 409 | `INVITE_CODE_EXPIRED` | 유효 시간이 지난 숫자 |
| 409 | `ALREADY_PAIRED` | 부모 또는 숫자를 만든 자녀가 이미 연결됨 |

### 5.4 오늘 상태 — `GET /today`

부모·자녀 공통 API다. `pairId` query parameter를 받지 않는다.

응답 `200 OK` — 아직 부모만 답한 예시:

```json
{
  "assignment": {
    "id": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
    "assignedDate": "2026-09-24",
    "question": {
      "id": "qst_045",
      "text": "어릴 때 가장 좋아했던 놀이는 무엇이었나요?",
      "category": "CHILDHOOD",
      "audioUrl": "https://cdn.example.com/questions/qst_045.mp3"
    }
  },
  "viewerRole": "PARENT",
  "parentSubmissionStatus": "SUBMITTED",
  "childSubmissionStatus": "NOT_SUBMITTED",
  "revealStatus": "WAITING_FOR_CHILD",
  "canViewPartnerAnswer": false,
  "myAnswer": {
    "type": "VOICE",
    "availability": "AVAILABLE",
    "recordingId": "rec_01J8M96KKXMV5XMXY6KGJ05Q6D",
    "processingStatus": "LLM_PROCESSING",
    "originalAudioUrl": "https://signed.example.com/rec_123.m4a?expires=...",
    "originalAudioExpiresAt": "2026-09-24T10:20:00+09:00",
    "sttText": "어릴 때는 동네에서 고무줄 놀이를...",
    "summaryText": null,
    "processingNotice": null
  },
  "myPhoto": null
}
```

상대 답변을 볼 수 없을 때는 `partnerAnswer` 필드를 **생략**한다. 공개 후에는
다음처럼 포함한다.

```json
{
  "assignment": {
    "id": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
    "assignedDate": "2026-09-24",
    "question": {
      "id": "qst_045",
      "text": "어릴 때 가장 좋아했던 놀이는 무엇이었나요?",
      "category": "CHILDHOOD",
      "audioUrl": "https://cdn.example.com/questions/qst_045.mp3"
    }
  },
  "viewerRole": "CHILD",
  "parentSubmissionStatus": "SUBMITTED",
  "childSubmissionStatus": "SUBMITTED",
  "revealStatus": "REVEALED",
  "canViewPartnerAnswer": true,
  "myAnswer": {
    "type": "TEXT",
    "availability": "AVAILABLE",
    "answerId": "ans_01J8M9DDP02MTHJY44YKN3ZE73",
    "text": "저는 놀이터에서 숨바꼭질하던 시간이 기억나요.",
    "ttsStatus": "READY"
  },
  "partnerAnswer": {
    "type": "VOICE",
    "availability": "AVAILABLE",
    "recordingId": "rec_01J8M96KKXMV5XMXY6KGJ05Q6D",
    "processingStatus": "READY",
    "originalAudioUrl": "https://signed.example.com/rec_123.m4a?expires=...",
    "originalAudioExpiresAt": "2026-09-24T10:20:00+09:00",
    "sttText": "어릴 때는 동네에서 고무줄 놀이를 했지.",
    "summaryText": "어린 시절 동네 친구들과 고무줄 놀이를 즐겼어요.",
    "processingNotice": null
  },
  "myPhoto": {
    "photoId": "photo_child_01J8MB2KVDBM2YEN9K2H6P7B0T",
    "url": "https://signed.example.com/photos/child-original.jpg?expires=...",
    "thumbnailUrl": "https://signed.example.com/photos/child-thumb.webp?expires=...",
    "expiresAt": "2026-09-24T10:20:00+09:00"
  },
  "partnerPhoto": {
    "photoId": "photo_parent_01J8MB1AC0F5K7J4B1S2ZQ8W3R",
    "url": "https://signed.example.com/photos/parent-original.jpg?expires=...",
    "thumbnailUrl": "https://signed.example.com/photos/parent-thumb.webp?expires=...",
    "expiresAt": "2026-09-24T10:20:00+09:00"
  }
}
```

`myPhoto`는 없으면 `null`이다. 상대 사진은 공개 전에는 필드 자체를 생략하고,
`canViewPartnerAnswer=true`일 때만 `partnerPhoto`를 `null` 또는 사진 객체로 반환한다.

페어링 전에는 `409 PAIR_NOT_FOUND`, 오늘 질문이 아직 배정되지 않았다면
`404 TODAY_ASSIGNMENT_NOT_FOUND`를 반환한다.

### 5.5 부모 녹음 제출·교체

`PUT /assignments/{assignmentId}/parent-recording`

헤더:

```text
Content-Type: multipart/form-data
Idempotency-Key: 5e8ea171-903f-49e9-b5c0-b39f96eb31e8
```

form-data:

```text
audioFile: answer.m4a
```

응답 `202 Accepted`:

```json
{
  "recordingId": "rec_01J8M96KKXMV5XMXY6KGJ05Q6D",
  "assignmentId": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
  "submissionStatus": "SUBMITTED",
  "processingStatus": "UPLOADED",
  "submittedAt": "2026-09-24T09:35:00+09:00",
  "pollingUrl": "/api/v1/recordings/rec_01J8M96KKXMV5XMXY6KGJ05Q6D"
}
```

공개 전 재녹음은 새 파일로 교체하고 같은 assignment에는 활성 Recording 하나만
유지한다. 기존 파일 삭제는 새 파일 저장 성공 뒤 수행한다.

### 5.6 녹음 처리 상태 — `GET /recordings/{recordingId}`

처리 중 응답 `200 OK`:

```json
{
  "recordingId": "rec_01J8M96KKXMV5XMXY6KGJ05Q6D",
  "assignmentId": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
  "processingStatus": "LLM_PROCESSING",
  "sttText": "어릴 때는 동네에서 고무줄 놀이를...",
  "summaryText": null,
  "failedStage": null,
  "failureCode": null,
  "processingNotice": null,
  "updatedAt": "2026-09-24T09:35:15+09:00"
}
```

실패 응답도 조회 자체는 `200 OK`이며 상태로 표현한다.

```json
{
  "recordingId": "rec_01J8M96KKXMV5XMXY6KGJ05Q6D",
  "assignmentId": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
  "processingStatus": "FAILED",
  "sttText": null,
  "summaryText": null,
  "failedStage": "STT",
  "failureCode": "AI_PROVIDER_TIMEOUT",
  "processingNotice": "음성 정리는 실패했지만 원본 녹음은 안전하게 저장되었습니다.",
  "updatedAt": "2026-09-24T09:36:00+09:00"
}
```

사용자 재시도는 MVP에서 동일 assignment에 녹음을 다시 `PUT`하는 방식으로
처리한다. 별도 AI-only retry API는 출시 이후 범위다.

### 5.7 자녀 답변 제출·수정

`PUT /assignments/{assignmentId}/child-answer`

요청:

```json
{
  "text": "저는 놀이터에서 숨바꼭질하던 시간이 기억나요."
}
```

- 앞뒤 공백 제거 후 1~1000자
- 공개 전 동일 API 호출은 기존 답변을 수정한다.
- TTS는 저장 후 비동기로 생성하고 실패해도 텍스트 답변 제출은 유지한다.

응답 `200 OK`(신규 생성 시에도 PUT이므로 동일):

```json
{
  "answerId": "ans_01J8M9DDP02MTHJY44YKN3ZE73",
  "assignmentId": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
  "text": "저는 놀이터에서 숨바꼭질하던 시간이 기억나요.",
  "submissionStatus": "SUBMITTED",
  "ttsStatus": "PROCESSING",
  "submittedAt": "2026-09-24T09:40:00+09:00",
  "updatedAt": "2026-09-24T09:40:00+09:00"
}
```

### 5.8 자녀 답변 TTS — `GET /answers/{answerId}/audio`

GET 요청에서는 TTS를 새로 생성하지 않는다. 자녀 답변 제출 시 생성 작업을
시작하고 이 API는 상태와 결과만 조회한다.

응답 `200 OK`:

```json
{
  "answerId": "ans_01J8M9DDP02MTHJY44YKN3ZE73",
  "ttsStatus": "READY",
  "audioUrl": "https://signed.example.com/tts/ans_123.mp3?expires=...",
  "audioExpiresAt": "2026-09-24T10:45:00+09:00",
  "processingNotice": null
}
```

생성 중에는 `audioUrl`, `audioExpiresAt`이 `null`이다. 실패해도 텍스트는 계속
노출하고 `ttsStatus=FAILED`와 안내 문구를 반환한다.

### 5.9 지난 이야기 — `GET /stories?cursor=&limit=20`

공개된 assignment만 반환한다. 최신순이다.

응답 `200 OK`:

```json
{
  "items": [
    {
      "storyId": "story_01J8MA2SAGKK4FR2PWT67W4TN4",
      "assignmentId": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
      "assignedDate": "2026-09-24",
      "question": {
        "id": "qst_045",
        "text": "어릴 때 가장 좋아했던 놀이는 무엇이었나요?",
        "category": "CHILDHOOD"
      },
      "parentAnswer": {
        "availability": "AVAILABLE",
        "recordingId": "rec_01J8M96KKXMV5XMXY6KGJ05Q6D",
        "processingStatus": "READY",
        "originalAudioUrl": "https://signed.example.com/rec_123.m4a?expires=...",
        "originalAudioExpiresAt": "2026-09-24T10:50:00+09:00",
        "sttText": "어릴 때는 동네에서 고무줄 놀이를 했지.",
        "summaryText": "어린 시절 동네 친구들과 고무줄 놀이를 즐겼어요.",
        "processingNotice": null
      },
      "parentPhoto": {
        "photoId": "photo_parent_01J8MB1AC0F5K7J4B1S2ZQ8W3R",
        "url": "https://signed.example.com/photos/parent-original.jpg?expires=...",
        "thumbnailUrl": "https://signed.example.com/photos/parent-thumb.webp?expires=...",
        "expiresAt": "2026-09-24T10:50:00+09:00"
      },
      "childAnswer": {
        "availability": "AVAILABLE",
        "answerId": "ans_01J8M9DDP02MTHJY44YKN3ZE73",
        "text": "저는 놀이터에서 숨바꼭질하던 시간이 기억나요.",
        "ttsStatus": "READY"
      },
      "childPhoto": null,
      "revealedAt": "2026-09-24T09:41:00+09:00"
    }
  ],
  "nextCursor": null,
  "hasNext": false
}
```

사진이 없는 역할의 사진 필드는 `null`이다. 사진 조회 권한은 이야기 공개 권한과
같다. signed URL이 만료되면 프론트는 저장된 URL을 재사용하지 않고 이 API를 다시
호출한다.

#### 월별 조회 모드 — `GET /stories?month=2026-11`

- `month` 형식은 `YYYY-MM`이고 기준 시간대는 `Asia/Seoul`이다.
- `month`와 `cursor`·`limit`은 함께 보내지 않는다. 함께 보내면
  `400 VALIDATION_ERROR`를 반환한다.
- 해당 월의 공개된 이야기를 `assignedDate` 오름차순으로 모두 반환한다.
- 응답 구조는 위 목록 응답과 같고 월별 모드에서는 `nextCursor=null`,
  `hasNext=false`다.
- 이야기가 없는 달은 `200 OK`와 빈 `items`를 반환한다.
- 캘린더는 `assignedDate`로 날짜를 표시하고, 날짜 선택 시 같은 item을 상세 카드에
  전달한다. 프론트가 공개 여부를 다시 계산하지 않는다.

### 5.10 본인 사진 첨부·교체 — `PUT /assignments/{assignmentId}/my-photo` — 초안, 미구현

부모·자녀 공통 API다. 인증 사용자 역할로 사진 소유자를 결정하며 role이나 userId를
body로 받지 않는다. 같은 assignment에 다시 호출하면 기존 사진을 교체한다.

```text
Content-Type: multipart/form-data
photoFile: family-photo.jpg
```

응답 `200 OK`:

```json
{
  "photoId": "photo_parent_01J8MB1AC0F5K7J4B1S2ZQ8W3R",
  "assignmentId": "asg_01J8M90G3M9BT7PRD6X4CN9C0E",
  "ownerRole": "PARENT",
  "url": "https://signed.example.com/photos/parent-original.jpg?expires=...",
  "thumbnailUrl": "https://signed.example.com/photos/parent-thumb.webp?expires=...",
  "expiresAt": "2026-11-04T15:15:00+09:00",
  "updatedAt": "2026-11-04T15:00:00+09:00"
}
```

- 본인의 assignment가 아니면 `403 RESOURCE_ACCESS_DENIED`다.
- 형식·크기·해상도 제한은 2.9를 따른다.
- 새 파일과 썸네일 저장이 모두 성공한 뒤 기존 파일을 삭제한다.
- 사진 업로드 실패는 기존 음성·텍스트 답변 제출 상태를 변경하지 않는다.

### 5.11 본인 사진 삭제 — `DELETE /assignments/{assignmentId}/my-photo` — 초안, 미구현

인증 사용자가 해당 assignment에 올린 사진과 썸네일을 삭제하고 `204 No Content`를
반환한다. 사진이 없으면 `404 PHOTO_NOT_FOUND`, 다른 사람 리소스면
`403 RESOURCE_ACCESS_DENIED`다. 음성·텍스트 답변과 이야기 자체는 유지한다.

### 5.12 부모 녹음 삭제 — `DELETE /recordings/{recordingId}` — 초안, 미구현

현재 백엔드에는 이 삭제 endpoint가 없고, 현재 프론트 DTO의 `recordingId`와
`processingStatus`는 non-nullable 문자열이다. 아래 nullable 응답은 양쪽 구현과
파싱 테스트가 함께 반영되기 전에는 서버가 반환하지 않는다.

녹음을 제출한 부모만 호출할 수 있다. 성공하면 원본 음성, STT 원문, LLM 정리본과
관련 저장소 객체를 삭제하고 `204 No Content`를 반환한다. 질문, 자녀 답변과 사진은
유지한다.

삭제된 녹음이 포함된 지난 이야기는 `parentAnswer`를 다음처럼 반환한다.

```json
{
  "availability": "DELETED",
  "recordingId": null,
  "processingStatus": null,
  "originalAudioUrl": null,
  "originalAudioExpiresAt": null,
  "sttText": null,
  "summaryText": null,
  "processingNotice": "부모님이 이 음성 기록을 삭제했어요."
}
```

프론트는 삭제된 음성의 재생·재발급을 시도하지 않고 안내 문구만 표시한다. 다른
부모의 녹음 또는 본인 Pair 밖의 녹음은 `403 RESOURCE_ACCESS_DENIED`다.

### 5.13 회원 탈퇴 — `DELETE /users/me` — 초안, 미구현

성공하면 인증 사용자의 계정과 본인이 올린 음성·텍스트·사진의 삭제 작업을 시작하고
`202 Accepted`를 반환한다. Pair는 즉시 비활성화하며 상대방이 올린 원본 데이터는
삭제하지 않는다.

```json
{
  "deletionRequestId": "del_01J8MBP6A4Q0RX8C8YB6M4T2YP",
  "status": "PROCESSING",
  "requestedAt": "2026-11-04T15:00:00+09:00"
}
```

- 프론트는 성공 응답을 받은 즉시 local access token과 저장된 사용자 정보를 지우고
  탈퇴 완료 화면으로 이동한다.
- 상대방 화면에는 탈퇴한 사용자의 답변을 `DELETED` 상태로 표시하고 재생·다운로드
  버튼을 노출하지 않는다.
- 삭제된 부모·자녀 답변 객체는 `availability=DELETED`를 반환하고 식별자, 음성 URL,
  텍스트와 AI 결과는 `null`로 반환한다. 질문과 상대방이 작성한 답변은 유지한다.
- 백업을 포함한 실제 삭제 완료 기한은 개인정보 처리방침에서 관리한다. API 응답은
  완료 시각을 보장하지 않는다.
- 이미 탈퇴 처리 중인 사용자의 재요청은 `409 ACCOUNT_DELETION_IN_PROGRESS`다.

### 5.14 재로그인·기록 복구 — 초안, 구현 금지

아래 이름과 JSON은 프론트 Mock 및 회의용 뼈대다. 본인 확인 수단과 토큰 정책이
확정되기 전에는 백엔드 endpoint나 실제 외부 인증 호출을 구현하지 않는다.

예상 흐름:

```text
SIGNED_OUT -> VERIFYING -> RESTORING -> AUTHENTICATED
                         \-> RECOVERY_FAILED
```

후보 endpoint:

| 메서드·경로 | 용도 | 상태 |
|---|---|---|
| `POST /auth/verifications` | 본인 확인 요청 | 초안 |
| `POST /auth/verifications/{verificationId}/confirm` | 인증 코드 확인과 로그인 | 초안 |
| `POST /auth/refresh` | access token 재발급 | 초안 |
| `GET /users/me` | 로그인 사용자·Pair 복구 | 초안 |

프론트 Mock용 로그인 성공 응답 뼈대:

```json
{
  "user": {
    "id": "usr_01J8M8A9G39WJMB5KVX46DP3FQ",
    "name": "김영희",
    "role": "PARENT",
    "pairingStatus": "PAIRED"
  },
  "accessToken": "draft-access-token",
  "refreshToken": "draft-refresh-token",
  "expiresAt": "2026-11-04T16:00:00+09:00",
  "recoveryStatus": "RESTORED"
}
```

초안 단계의 프론트는 화면 전환과 `VERIFYING`, `RESTORING`, `RECOVERY_FAILED` 상태만
Mock으로 구현한다. 현재 `401` 처리와 `POST /users` 가입 동작은 회의 결과가 계약에
반영될 때까지 유지한다.

## 6. 프론트 Mock 파일 권장 구조

```text
frontend/
└── assets/
    └── mocks/
        ├── user_parent.json
        ├── user_child.json
        ├── today_waiting_for_parent.json
        ├── today_waiting_for_child.json
        ├── today_revealed.json
        ├── recording_processing.json
        ├── recording_failed.json
        ├── stories_first_page.json
        ├── stories_month_2026_11.json
        ├── story_recording_deleted.json
        ├── photo_uploaded.json
        └── auth_recovery_draft.json
```

프론트는 화면에서 HTTP client를 직접 호출하지 않고 Repository/DataSource 계층을
통해 Mock과 실제 API를 교체한다. Android 에뮬레이터의 로컬 API 주소는
`http://10.0.2.2:8080/api/v1`, 실기기는 같은 네트워크에 있는 개발 PC의 LAN IP를
사용한다.

## 7. 별도 확정 또는 출시 이후 범위

- 확정되지 않은 재로그인·계정 복구 방식
- FCM·웹소켓 처리 완료 알림
- AI-only 재처리 API와 운영자 콘솔
- Presigned URL을 이용한 앱→R2 직접 업로드
- 여러 부모·자녀를 묶는 가족 그룹
- 댓글·좋아요·공개 소셜 피드
- 질문 관리자 화면과 실시간 질문 TTS 생성

## 8. 변경 이력

| 날짜 | 버전 | 변경 내용 |
|---|---|---|
| 2026-09-24 | v0 | MVP API 분리, 공통 규칙·전체 요청/응답·Mock 계약 확정 |
| 2026-09-28 | v0 | 공통 오류 표와 `POST /pairs/join` 실패 응답에 `INVITE_CODE_NOT_FOUND`, `INVITE_CODE_EXPIRED`, `PAIR_NOT_FOUND`, `TODAY_ASSIGNMENT_NOT_FOUND` 추가 (백엔드 구현과 맞춤) |
| 2026-11-04 | v0.1 | 월별 지난 이야기, 사진 첨부·삭제, 녹음 삭제, 회원 탈퇴, 재로그인·기록 복구 요구사항을 미구현 초안으로 추가 |
| 2026-11-07 | v0.2 | 월별 지난 이야기 조회 계약 확정 및 백엔드 구현 반영 |
