---
name: code-review
description: Review proposed changes in this repository for merge risk. Use when the user asks to review a PR, branch, commit, diff, staged or unstaged changes, or asks whether changes are ready to merge. Do not use for implementing fixes, general code explanations, or reviewing unchanged code.
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
