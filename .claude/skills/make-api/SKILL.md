---
name: make-api
description: 이 저장소에서 API 하나를 백엔드에 구현하거나 Flutter 프론트에 연동하고, 필요하면 양쪽을 함께 변경한다. `/make-api`와 작업 범위·엔드포인트 또는 요구사항으로 명시적으로 호출한다. API와 무관한 화면 작업, 광범위한 구조 변경, 미확정 기획에는 사용하지 않는다.
argument-hint: "[작업 범위와 endpoint 또는 요구사항]"
disable-model-invocation: true
---

# Make API

Implement one reviewable API-backed change. Follow the root `AGENTS.md` and the
`backend/AGENTS.md` or `frontend/AGENTS.md` that applies to edited files.

1. From the explicit request, choose the smallest scope:
   - backend: implement or change an endpoint
   - frontend: integrate an existing contract into Flutter models, data source,
     repository/provider, Mock, and affected UI states
   - full-stack: synchronize the contract, backend, and frontend
   Do not edit an unrequested layer merely because it exists.
2. Read `docs/api-contract.md` and inspect the nearest existing patterns in each affected
   layer. Identify the HTTP method, path, authentication, authorization, request,
   response, status codes, errors, persistence, and frontend states.
3. If behavior, ownership, state transition, or error semantics are undecided, stop and
   request that decision. Do not invent product policy. For a contract change, record
   the current and proposed JSON and follow the repository's `[API]` Issue process;
   do not create an external Issue unless the user authorizes it.
4. Define the smallest change set before editing. For backend work, keep responsibilities
   separated:
   - Controller: authenticated user, validation, and HTTP mapping
   - Service: authorization, ownership, state transition, and transaction boundary
   - Repository: persistence and query behavior
   - DTO: contract shape; never expose Entity directly
   For frontend work, keep Dio behind the DataSource and Repository, keep DTO fields and
   enums identical to the contract, and use server-provided visibility fields instead of
   recalculating policy in the app.
5. Add focused tests before or with implementation. Select only the affected layer:
   - Controller: validation, authentication, authorization, status, and error JSON
   - Service: role, ownership, duplicate request, state transition, and failure path
   - Repository: constraint or query behavior when persistence changes
   - Flutter: DTO mapping, Repository/provider behavior, and loading, empty, success,
     retry, and error states that the change affects
   Use H2 for backend tests, Mock external services, and keep frontend API and Mock data
   sources interchangeable.
6. Implement the minimal requested scope. Validate untrusted input, enforce ownership,
   map API errors to user-facing states, avoid sensitive logging, and do not weaken
   security or expose undecided behavior. Do not implement unrelated UI.
7. When the contract changes, update `docs/api-contract.md`, its change history, backend
   DTO and tests, and frontend model and Mock in the same change. When the contract does
   not change, do not rewrite it merely to restate existing behavior.
8. Run the narrowest relevant tests, then run the full check for every changed layer.
   For backend changes:

   ```bash
   cd backend && ./gradlew check --no-daemon
   ```

   For frontend changes:

   ```bash
   cd frontend
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```

9. Report the selected scope, endpoint and contract impact, authorization and UI-state
   decisions, files changed, tests run, and any unresolved product or migration decision.

Do not use real credentials, production data, destructive database operations, or real
external services while implementing or testing.
