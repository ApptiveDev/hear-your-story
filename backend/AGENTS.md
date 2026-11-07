# backend/AGENTS.md — Spring Boot 규칙

작업 전 루트 [`../AGENTS.md`](../AGENTS.md)와 API 계약
[`../docs/api-contract.md`](../docs/api-contract.md)을 읽는다. 실행 환경과 환경변수는
[`README.md`](README.md)를 참고하고 이 문서에 중복 작성하지 않는다.

## 기술 기준

- Java 17, Spring Boot 3.5.x, Gradle Wrapper
- Spring Web, Validation, Data JPA, Security
- PostgreSQL 16, 테스트는 PostgreSQL 호환 모드의 H2
- 업무 날짜는 `Asia/Seoul`, DB timestamp는 UTC 의미를 보존한다.

## Commands

`backend/`에서 저장소의 Gradle Wrapper를 사용한다.

```bash
./gradlew bootRun                         # 로컬 서버 실행
./gradlew test                            # 전체 테스트
./gradlew spotlessApply                   # Java 형식 자동 수정
./gradlew spotlessCheck                   # Java 형식 검사
./gradlew checkstyleMain checkstyleTest    # Java 린트 검사
./gradlew test --tests "패키지.클래스명"   # 특정 테스트
./gradlew check --no-daemon               # PR 전 전체 검증·CI 기준
docker compose up -d                      # 로컬 PostgreSQL 실행
```

작업 완료 전에는 최소 `./gradlew check --no-daemon`을 실행한다. 실행하지 못하면
이유와 미검증 범위를 보고한다.

Java 들여쓰기·공백·줄바꿈·import 순서는 Spotless가 전담한다. Checkstyle에
중복 스타일 규칙을 추가하지 않는다. 설정과 IntelliJ 사용법은 `README.md`의
포맷·린트 자동화 절을 따른다.

## 구현 원칙

- Controller는 인증 사용자·입력 검증·HTTP 변환만 담당한다.
- Service는 소유권·권한·상태 전이 등 업무 규칙을 담당한다.
- Repository는 영속성만 담당하고 Entity를 API 응답으로 직접 반환하지 않는다.
- 요청 DTO에는 Bean Validation을 적용하고 예외는 `@RestControllerAdvice`에서 API
  계약의 공통 에러 형식으로 변환한다.
- API 필드·enum·상태·에러를 변경하면 계약 문서, DTO, 테스트, 프론트 영향까지
  같은 PR에서 확인한다.
- 외부 OpenAI·R2 연동은 인터페이스 경계를 유지하고 단위 테스트에서 실제 외부
  서비스를 호출하지 않는다.
- Spring Bean의 생성자가 `final` 의존성 대입만 담당하면
  `@RequiredArgsConstructor`를 사용한다. `@Value`·`@Qualifier` 같은 파라미터
  어노테이션이나 초기화·검증 로직이 필요하면 명시적 생성자를 유지한다.
- Entity의 기존 공개 API가 모든 필드의 단순 getter라면 `@Getter`를 사용한다.
  계산·변환 getter와 의도적으로 숨긴 필드는 명시적으로 유지하며 Entity에
  `@Data`나 클래스 단위 `@Setter`를 사용하지 않는다.

## 데이터베이스

- 로컬 PostgreSQL 설정은 [`.env.example`](.env.example)과
  [`docker-compose.yml`](docker-compose.yml)을 기준으로 한다.
- 테스트는 `application-test.yaml`의 H2를 사용하며 운영 데이터나 외부 서비스에
  연결하지 않는다.
- 테이블·컬럼·제약조건 변경은 운영 영향과 migration 방법을 먼저 확인한다.
- 스키마 변경은 `src/main/resources/db/migration`에 새 Flyway 버전 파일로 추가하고
  이미 적용된 migration 파일은 수정하지 않는다. Hibernate는 `validate`로 유지한다.
- 데이터·volume 삭제, schema 초기화 등 복구가 어려운 작업은 명시적 승인 없이
  실행하지 않는다.
- 중복 제출과 상태 전이는 애플리케이션 검사만 믿지 말고 transaction·DB 제약과
  동시성 영향을 함께 검토한다.
- signed URL은 저장하지 않고 object key만 저장하며 URL은 조회 시 짧게 발급한다.

## 보안 및 개인정보

- DB, JWT, OpenAI, R2 자격증명은 환경변수로만 주입하고 코드·테스트·로그에 실제
  값을 남기지 않는다. Spring Boot는 `.env`를 자동으로 읽지 않는다.
- JWT 원문을 DB에 저장하지 않고 서명 secret은 32바이트 이상을 사용한다.
- 공개 API를 추가하거나 Security 예외 경로를 넓힐 때는 API 계약과 인증 필요
  여부를 확인한다.
- ID를 전달받았다는 이유만으로 신뢰하지 말고 현재 사용자의 리소스 소유권과
  역할을 Service에서 검증한다.
- 토큰, 개인정보, STT 원문, 음성 object key, signed URL query를 로그에 남기지
  않는다.
- 업로드 파일은 계약에 정의된 형식·크기·길이를 검증하고 비공개 저장소에 둔다.

## 테스트 및 완료 기준

- Service: 역할·소유권·중복 처리·상태 전이·실패 복구를 검증한다.
- Controller: validation과 401·403·404·409 및 공통 에러 JSON을 검증한다.
- Repository: 중복 방지 제약과 조회 조건을 검증한다.
- 외부 연동: 성공·실패·timeout을 Mock으로 검증하고 실패가 핵심 데이터 보존을
  깨뜨리지 않는지 확인한다.
- 버그 수정은 가능한 경우 실패 테스트를 먼저 추가한 뒤 최소 범위로 수정한다.
