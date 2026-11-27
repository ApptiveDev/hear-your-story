# 만 14세 이상 가입 확인 — 프론트 인수인계

- 브랜치: `feature/signup-age-gate` (최신 main에서 독립 분기)
- 계약: [API 계약 5.1](api-contract.md#51-카카오-가입-완료--post-users)
- 협의·완료 추적: [API Issue #108](https://github.com/ApptiveDev/hear-your-story/issues/108)
- 선택한 방식: 생년월일·나이를 받지 않고 **만 14세 이상입니다** 필수 체크.
- 백엔드 구현·검증을 먼저 준비한 Draft PR이다. 프론트 연동 전 병합·배포 금지.
  기존 앱은 확인값을 보내지 않으므로 새 백엔드에 신규 가입하면 거절된다.

## 브랜치 받기

로컬 변경은 먼저 커밋 또는 별도 보관한 뒤 실행한다.

```bash
git fetch origin
git switch --track origin/feature/signup-age-gate
```

이미 같은 로컬 브랜치가 있다면 `git switch feature/signup-age-gate` 후
`git pull --ff-only origin feature/signup-age-gate`를 사용한다.
기존 PR에 작업을 이어 push하면 된다. main에 직접 push하지 않는다.

## 프론트 작업 순서

1. **개인정보 수집 전 안내·확인**: 카카오 로그인 시작 전에 만 14세 이상 확인을 제공한다.
   역할과 무관하게 부모·자녀 모두 해당한다. 체크 전에는 카카오 SDK를 호출하지 않고
   연령 기준·가입 불가 안내를 보여준다. 이것은 자체 연령 확인이며 개인정보 수집·이용 동의를 대체하지 않는다.
2. 기본 미체크이며 사용자가 직접 선택하도록 한다. 실제 나이나 생년월일 입력은 추가하지 않는다.
3. 확인 상태를 `OnboardingPage` → `SignUpController.submit` → `AuthRepository.signUp` →
   `AuthRepositoryImpl` → `AuthDataSource.signUp` → `ApiAuthDataSource`까지 전달한다.
   `required bool` 등 명시적 인자로 받고 기본 `true`나 전송 직전 하드코딩을 넣지 않는다.
4. 계약 5.1의 확인값을 가입 요청에 포함한다. 체크가 풀렸거나 상태가 사라졌으면 가입 요청을 보내지 않는다.
5. 다시 로그인·계정 변경·로그아웃·앱 재시작 시 확인 상태가 어떻게 초기화되는지 확인한다.
   장기 저장된 전역 `true`를 새 계정에 자동 적용하지 않는다. 기존 계정 로그인 복구에는 새 가입 필드를 붙이지 않는다.
6. `MockAuthDataSource`도 미확인 가입을 거절하게 맞추고, test fake 구현들의 함수 인자도 동기화한다.
   응답 `AppUser`·성공 fixture는 그대로이며 입력 검증과 실패 Mock을 추가한다.
7. 계약의 해당 field error를 보면 “만 14세 이상인지 확인해 주세요” 안내와 체크 화면을 유지한다.
   서버 원문·stack trace를 사용자에게 그대로 표시하지 않는다. 가입용 토큰 만료 시 기존 재로그인 흐름을 따른다.
8. #104 개인정보 처리방침·약관의 만 14세 이상 문구와 실제 화면을 대조한다.
   본 브랜치에는 웹 탈퇴 PR #107이나 개인정보 처리방침 PR #104를 끌어오지 않았다.

관련 파일:

- `frontend/lib/features/onboarding/presentation/onboarding_page.dart`
- `frontend/lib/features/onboarding/presentation/sign_up_controller.dart`
- `frontend/lib/features/onboarding/domain/auth_repository.dart`
- `frontend/lib/features/onboarding/data/auth_repository_impl.dart`
- `frontend/lib/features/onboarding/data/auth_data_source.dart`
- `frontend/test/features/onboarding/`의 실제 요청·Mock·가입 화면·카카오 로그인 테스트

## 백엔드에서 완료한 범위

- 기존 가입 요청 DTO에 필수 확인값 검증. 거절 사유와 응답 예시는 API 계약 5.1 참고.
- 내부 서비스 직접 호출도 미확인 가입을 허용하지 않는 가드.
- 부모·자녀 모두 누락·null·false 거절, 잘못된 입력 거절, 사용자·토큰 생성 없음,
  동일 가입용 토큰으로 확인 후 성공, 기존 가입·탈퇴·로그인 회귀 검증.
- DB·환경변수·새 endpoint 추가 없음. 응답·기존 로그인·refresh 변경 없음.
- 실제 연령 증명·보호자 동의·기존 가입자 연령 재확인은 구현 범위가 아니다.

## 병합 전 체크리스트

- [ ] #108에서 프론트·백엔드 계약 확인 및 5.1 구현안 상태 갱신.
- [ ] 기본 미체크, 미체크 시 카카오 호출·신규 가입 없음, 체크 후 부모·자녀 가입 성공.
- [ ] UI 선택값이 실제 가입 body에 반영됨. 하드코딩 없이 false·누락 실패 Mock도 일치.
- [ ] 실패·재시도·계정 전환·로그아웃·재시작·기존 사용자 로그인 회귀 확인.
- [ ] 큰 글씨 1.3·2배에서 체크·안내·주요 버튼 사용 가능.
- [ ] backend 전체 check, frontend format·analyze·test 및 GitHub CI 통과.
- [ ] 스테이징 서버와 실제 기기에서 신규 부모·자녀 가입 검증.
- [ ] 앱·백엔드 배포 순서 확정. 기존 앱의 신규 가입 호환성 문제가 해결되기 전 단독 서버 배포 금지.

## 판단 근거

[개인정보 보호법 제22조의2](https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1020398521)는
만 14세 미만 아동의 개인정보 처리에 동의가 필요한 경우 법정대리인 동의와 확인을 요구한다.
팀은 보호자 동의 기능을 제공하지 않는 출시 범위를 선택했다. 단순 체크는 실제 연령 인증이나
법적 적합성·스토어 심사 통과를 보장하지 않으며, 대상 연령·고지·실제 운영도 함께 일치시켜야 한다.
