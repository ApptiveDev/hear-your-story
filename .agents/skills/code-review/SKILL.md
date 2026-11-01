---
name: code-review
description: 이 저장소의 변경 사항을 병합 위험 관점에서 검토한다. PR, 브랜치, 커밋, diff, staged·unstaged 변경 리뷰나 병합 가능 여부 확인에 사용한다. 수정 구현, 일반 코드 설명, 변경되지 않은 코드 검토에는 사용하지 않는다.
---

# Code Review

Review without modifying files unless the user separately asks for fixes.

1. Determine the review target and comparison base. Include staged, unstaged, and
   untracked files when reviewing local work.
2. Read the root `AGENTS.md`, the closest scoped `AGENTS.md` for changed files, and
   `docs/api-contract.md` when an API boundary changed.
3. Inspect only issues introduced or exposed by the change. Prioritize:
   - correctness, regressions, concurrency, and failure recovery
   - authentication, authorization, secrets, privacy, and unsafe logging
   - API contract, DTO/model/Mock, enum, and error-format mismatches
   - missing tests for changed behavior
   - frontend loading, empty, retry, error, and reveal-state handling
   - backend transaction, database constraint, ownership, and external-call handling
4. Run focused read-only verification when it materially confirms a finding. Do not
   perform destructive actions or mutate external services.
5. Report only discrete, actionable findings the author would likely fix. Order them
   by severity and include the file, narrow location, failure scenario, impact, and
   suggested direction. Deduplicate related findings.
6. If no actionable issue remains, say so directly and mention any verification gap
   or residual risk.

Do not report formatter-managed style, personal preferences, pre-existing unrelated
issues, or speculative concerns without a concrete failure scenario. CI and AI review
do not replace human approval.
