---
name: make-api
description: 이 저장소의 백엔드 API 엔드포인트 하나를 계약·권한·영속성·테스트·프론트 영향과 함께 구현하거나 변경한다. `/make-api`와 엔드포인트 또는 요구사항으로 명시적으로 호출한다. 프론트 전용 작업, 광범위한 구조 변경, 미확정 기획에는 사용하지 않는다.
argument-hint: "[endpoint 또는 요구사항]"
disable-model-invocation: true
---

# Make API

Implement one reviewable API change. Follow the root and `backend/AGENTS.md`.

1. Read `docs/api-contract.md` and inspect the nearest existing endpoint pattern.
   Identify the HTTP method, path, authentication, authorization, request, response,
   status codes, errors, persistence, and affected frontend model or Mock.
2. If behavior, ownership, state transition, or error semantics are undecided, stop and
   request that decision. Do not invent product policy. For a contract change, record
   the current and proposed JSON and follow the repository's `[API]` Issue process;
   do not create an external Issue unless the user authorizes it.
3. Define the smallest change set before editing. Keep responsibilities separated:
   - Controller: authenticated user, validation, and HTTP mapping
   - Service: authorization, ownership, state transition, and transaction boundary
   - Repository: persistence and query behavior
   - DTO: contract shape; never expose Entity directly
4. Add focused tests before or with implementation:
   - Controller: validation, authentication, authorization, status, and error JSON
   - Service: role, ownership, duplicate request, state transition, and failure path
   - Repository: constraint or query behavior when persistence changes
   Use H2 test configuration and Mock external OpenAI or R2 calls.
5. Implement the minimal endpoint. Validate untrusted input, enforce resource ownership,
   avoid sensitive logging, and review transaction, uniqueness, and concurrency risks.
   Do not weaken security or broaden public routes without an explicit requirement.
6. When the contract changes, update `docs/api-contract.md`, its change history, and the
   corresponding frontend model and Mock in the same change. Do not implement unrelated UI.
7. Run the narrowest relevant tests, then:

   ```bash
   cd backend && ./gradlew check --no-daemon
   ```

   If frontend files changed, also run:

   ```bash
   cd frontend
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```

8. Report the endpoint and contract change, authorization decision, files changed, tests
   run, frontend impact, and any unresolved product or migration decision.

Do not use real credentials, production data, destructive database operations, or real
external services while implementing or testing.
