---
name: make-api
description: Implement or change one backend API endpoint in this repository with its contract, authorization, persistence, tests, and frontend impact synchronized.
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
