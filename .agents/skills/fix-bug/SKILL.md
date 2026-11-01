---
name: fix-bug
description: 이 저장소에서 재현 가능한 버그를 진단하고 수정한다. 오동작, 회귀, 실패 동작의 수정을 요청할 때 사용한다. 신규 기능, 광범위한 리팩터링, 리뷰 전용 요청, 일반 CI 설정에는 사용하지 않는다.
---

# Fix Bug

Follow the applicable root and scoped `AGENTS.md`. Read
`docs/api-contract.md` only when the defect touches an API contract.

1. Restate the observed behavior, expected behavior, and affected area.
2. Reproduce the defect with the smallest relevant test or command. If it cannot be
   reproduced, gather evidence and report the gap instead of guessing.
3. Identify the root cause and the invariant that was violated.
4. When practical, add a regression test that fails before the fix. If a useful test
   is not practical, explain why.
5. Make the smallest change that fixes the root cause. Avoid unrelated refactors,
   contract changes, dependency upgrades, and test weakening.
6. Run the targeted test first, then the applicable area verification:
   - Backend: `cd backend && ./gradlew check --no-daemon`
   - Frontend: `cd frontend && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`
7. Review the final diff and report the cause, fix, tests run, and remaining risk.

If the user requests diagnosis only, stop after explaining the verified cause. Never
delete data, expose secrets, call real external services, or bypass tests to make the
result pass without explicit authorization.
