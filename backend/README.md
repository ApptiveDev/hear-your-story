# Backend — 가족 질문·음성 기록 서비스

Spring Boot 백엔드다. 구현 규칙은 [`AGENTS.md`](AGENTS.md), 요청·응답 계약은
[`../docs/api-contract.md`](../docs/api-contract.md)를 참고한다.

## 요구 사항

- JDK 17
- Docker / Docker Compose
- Gradle은 저장소의 Wrapper 사용

버전 확인:

```bash
java -version
./gradlew --version
docker compose version
```

## 로컬 실행

```bash
cp .env.example .env
docker compose up -d
set -a
source .env
set +a
./gradlew bootRun
```

Spring Boot는 `.env`를 자동으로 읽지 않는다. IntelliJ로 실행한다면 `.env`의
값을 Run Configuration의 Environment variables에 넣는다.

서버 기본 주소는 `http://localhost:8080`, Android 에뮬레이터에서 접근할 때는
`http://10.0.2.2:8080`이다.

## 환경변수

| 변수 | 설명 |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | PostgreSQL 연결 정보 |
| `APP_JWT_SECRET` | HS256 서명 키, 32바이트 이상 |
| `APP_ACCESS_TOKEN_EXPIRATION_MINUTES` | 서비스 access token 만료 시간, 기본 30분 |
| `APP_REGISTRATION_TOKEN_EXPIRATION_MINUTES` | 카카오 신규 가입용 token 만료 시간, 기본 10분 |
| `APP_REFRESH_TOKEN_EXPIRATION_DAYS` | refresh token 만료 시간, 기본 30일 |
| `KAKAO_NATIVE_APP_KEY` | 카카오 ID token의 `aud` 검증에 사용할 Native App Key |
| `OPENAI_API_KEY` | STT·LLM·TTS 호출 키 |
| `R2_ACCOUNT_ID` | Cloudflare 계정 ID |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | R2 S3 호환 자격증명 |
| `R2_BUCKET_NAME` | 비공개 원본 음성 bucket |
| `STORAGE_TYPE` | `local`(기본) 또는 `r2` |
| `AUDIO_PROCESSING_MODE` | `mock`(기본) 또는 `openai` |
| `PROCESSING_RECOVERY_*` | 중단된 STT/TTS 작업의 복구 활성화·지연·주기·배치 크기 |
| `OPENAI_TRANSCRIPTION_MODEL`, `OPENAI_SUMMARY_MODEL` | STT·이야기 정리 모델 |
| `OPENAI_TTS_MODEL`, `OPENAI_TTS_VOICE` | 자녀 답변 음성 합성 모델·목소리 |
| `JPA_SHOW_SQL` | 로컬 SQL 출력 여부, 기본 `false` |
| `JPA_DDL_AUTO` | 기본 `validate`; Flyway 적용 결과와 Entity 매핑이 같은지 검사 |

실제 `.env`, API key, 비밀번호는 커밋하지 않는다. 전체 형식은
[`.env.example`](.env.example)을 복사해 사용한다.

### 데이터베이스 마이그레이션

애플리케이션 시작 시 Flyway가 `src/main/resources/db/migration`의 SQL을 버전 순서대로
적용하고 Hibernate는 결과 스키마를 검증만 한다. 테이블이나 컬럼을 변경할 때는 이미
적용된 파일을 수정하지 말고 다음 버전의 `V{번호}__설명.sql`을 추가한다.

### 실제 음성 처리 활성화

기본 설정은 로컬 파일 저장과 Mock STT·LLM을 사용한다. R2와 OpenAI를 실제로
사용하려면 `.env`에서 다음 값을 설정한다.

```dotenv
STORAGE_TYPE=r2
AUDIO_PROCESSING_MODE=openai
OPENAI_API_KEY=...
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET_NAME=...
```

R2 bucket은 비공개로 유지한다. 앱에는 원본 object key 대신 15분 동안 유효한
GET Signed URL만 반환한다. 실제 모드에서도 업로드 API와 폴링 상태 계약은 Mock과
동일하다.

## 테스트

```bash
./gradlew test
```

## 포맷·린트 자동화

Java 코드 형식은 Spotless의 Eclipse formatter로 통일한다. 탭 너비는 4,
줄 길이 기준은 120자이며 설정은 `config/formatter/eclipse.xml`에서 관리한다.
Checkstyle은 wildcard·중복·미사용 import, 타입·메서드 이름, 빈 문장,
equals/hashCode 쌍을 검사한다. **들여쓰기·공백·줄바꿈·import 순서는 Spotless만
담당**하므로 Checkstyle에 중복 스타일 규칙을 추가하지 않는다.

```bash
./gradlew spotlessApply                 # Java 형식 자동 수정
./gradlew spotlessCheck                 # 형식 검사 (수정하지 않음)
./gradlew checkstyleMain checkstyleTest  # main/test 린트 검사
./gradlew check --no-daemon              # 포맷·린트·전체 테스트 (CI와 동일)
```

IntelliJ에서는 backend의 `.editorconfig`를 적용하고, 최종 형식은 Gradle 창의
`spotlessApply`로 맞춘다. IDE 자체 포맷터와 Gradle 포맷 결과가 다르면 Gradle
결과를 기준으로 한다. 도구 버전은 `build.gradle`에 고정한다.
린트 보고서는 `build/reports/checkstyle/`에서 확인한다.

## API 개발 순서

1. `GET /api/v1/health`
2. 가입·JWT, 페어링
3. 오늘 질문·Assignment
4. 자녀 답변·공개 상태
5. 녹음 업로드·폴링(Mock 처리)
6. R2·STT·LLM 실제 연동
7. TTS·지난 이야기

## Mock 질문 교체

MVP 날짜별 질문은 `src/main/resources/seed/mock-questions.json`에서 관리한다.
회의 후 질문이 확정되면 기존 `id`와 `scheduledDate`를 유지한 채 `text`,
`category`를 수정한다. 질문 안내 TTS가 준비되기 전까지 `audioUrl`은 `null`이며,
서버 재시작 시 JSON 내용이 DB에 반영된다.

프론트는 [`../docs/api-contract.md`](../docs/api-contract.md)의 JSON으로 먼저
개발한다. 백엔드가 완성될 때까지 기다릴 필요가 없다.

## 자주 겪는 문제

| 증상 | 확인할 것 |
|---|---|
| DB 연결 실패 | `docker compose ps`, `.env`의 DB 값, 5432 포트 충돌 |
| `password authentication failed for user "postgres"` | 5432를 다른 PostgreSQL이 쓰는지 `docker ps`로 확인하고, 해당 DB의 비밀번호와 `DB_PASSWORD`를 맞춘다. 기존 볼륨은 컨테이너 환경변수만 바꿔도 비밀번호가 바뀌지 않는다. |
| 환경변수가 비어 있음 | `.env`를 셸에 export했는지 또는 IDE에 등록했는지 확인 |
| Android에서 접속 실패 | 에뮬레이터는 `localhost` 대신 `10.0.2.2` 사용 |
| `401 Unauthorized` | Bearer token 만료·누락 및 Security 공개 경로 확인 |
| OpenAI `401` | API key와 프로젝트 사용 한도 확인 |

### 기존 PostgreSQL이 5432를 사용 중일 때

`docker compose ps`에는 아무것도 없는데 `docker ps`의 다른 컨테이너가 5432를
사용한다면 다음 중 하나만 선택한다.

1. 기존 DB를 계속 사용: 기존 DB 비밀번호를 `.env`의 `DB_PASSWORD`와 IntelliJ
   Run Configuration에 넣는다.
2. 이 프로젝트 DB를 사용: 기존 컨테이너를 먼저 중지하고 `docker compose up -d`를
   실행한다. 기존 컨테이너 삭제나 volume 삭제는 하지 않는다.

IntelliJ는 프로젝트의 `.env`를 자동으로 읽지 않는다. `.env`를 만들었더라도 Run
Configuration의 Environment variables에 넣지 않았다면 기본값으로 접속한다.
