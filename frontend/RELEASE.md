# Android 테스트 배포와 출시 빌드

빌드 담당자는 앱 설치 파일과 소스 커밋, 환경, 버전을 함께 관리한다.
CI의 debug APK 검사는 컴파일 검증이다. 스토어 제출·실기기 QA 성공을 의미하지 않는다.

## 먼저 팀에서 받을 것

- 테스트 배포 방식(APK 공유 / 스토어 테스트 트랙)과 콘솔 접근 권한
- 스테이징 HTTPS API 주소와 서버 버전, 실제 R2·STT·LLM·TTS 사용 여부
- 기존 업로드 키 유무, 키 보관 담당자와 백업 위치, 패키지명 확정
- 스토어에서 이미 사용한 가장 큰 versionCode (다음 빌드 번호는 이보다 크게)
- 테스트용 부모·자녀 계정과 기기 2대

기존 키를 확인하기 전 새 키를 만들지 않는다. 키·비밀번호는 채팅/PR에 붙이지 않는다.
앱의 applicationId는 현재 `com.apptive.life_record`다. 스토어와 카카오 등록값을 맞춘다.

## 서명 설정

Git에서 제외된 `frontend/android/key.properties`를 로컬에 만들고 아래 항목을 채운다.
`storeFile`은 android 폴더 기준 상대 경로 또는 절대 경로이며 Windows에서는 `/`를 쓴다.

```properties
storeFile=D:/secure/team-upload.jks
storePassword=REPLACE_LOCALLY
keyAlias=REPLACE_LOCALLY
keyPassword=REPLACE_LOCALLY
```

release는 이 설정을 사용하며, 누락되어도 debug 키로 대체하지 않는다.
debug 실행은 계속 가능하다. 서명 파일과 비밀번호는 저장소에 추가하지 않는다.
실제 설치 앱의 서명에 맞는 카카오 키 해시를 담당자와 확인한다.

## 환경 설정

`frontend/`에서 예시를 복사한다. `*.local.json`은 Git에서 제외된다.

```powershell
Copy-Item config/staging.example.json config/staging.local.json
```

로컬 파일의 API 주소를 실제 스테이징 주소로 바꾼다. 앱의 환경값에는 서버 비밀키를 넣지 않는다.
운영은 별도 `config/production.local.json`을 만들고 `APP_ENV=production`과 운영 주소를 지정한다.
`APP_ENV`는 빌드 검증·기록용이며 서버를 자동으로 선택하지 않는다.

- `USE_MOCK=false`, `KAKAO_FAKE_LOGIN=false`는 반드시 명시한다.
- `STORIES_MONTH_API=true`: 대상 서버의 월별 조회 배포를 확인한 뒤 사용한다.
- 실제 빌드는 카카오 인증을 사용하므로 `KAKAO_NATIVE_APP_KEY`를 반드시 채운다.
  제거된 `KAKAO_AUTH`는 설정에 넣지 않는다. 남아 있으면 빌드를 거부한다.
  콘솔의 Android 패키지명·서명 키 해시·OpenID Connect 설정과 서버 배포도 확인한다.
- 회원 탈퇴 계약과 백엔드는 구현되었지만 실서버 프론트 연동은 별도 확인이 필요하다.
  `ACCOUNT_DELETION_API=false`로 시작하고 담당자의 연동 확인 후 테스트 빌드에서 켠다.
  이 값이 false인 빌드는 최종 출시 후보로 간주하지 않는다.
- `PRIVACY_POLICY_URL`, `SUPPORT_CONTACT`는 공개 가능한 확정 값을 사용한다.

## 검사와 빌드

```powershell
./scripts/build-release.ps1 -ConfigFile config/staging.local.json -BuildName 1.0.0 -BuildNumber 2 -ValidateOnly
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
# 검증한 변경을 커밋한 뒤 실행. 번호 2는 예시이며 실제 다음 번호로 바꾼다.
./scripts/build-release.ps1 -ConfigFile config/staging.local.json -BuildName 1.0.0 -BuildNumber 2 -Artifact apk
./scripts/build-release.ps1 -ConfigFile config/staging.local.json -BuildName 1.0.0 -BuildNumber 2 -Artifact appbundle
```

`ValidateOnly`는 JSON 설정만 확인한다. 서명 유효성, 서버 연결, 기능 준비 여부는 확인하지 않는다.
Windows에서 스크립트 실행 정책으로 차단되면 팀의 허용된 PowerShell 환경에서 실행한다.
설정 검사 자체의 회귀 검증은 `./scripts/test-build-config.ps1`로 실행하며 CI에도 포함된다.
스크립트는 미커밋 변경이 있으면 배포 빌드를 중단하고, 성공한 파일 옆에
`*.build-info.json`을 만든다. 버전·빌드 번호·커밋·환경·파일 해시와 QA 미실행 상태만 기록한다.
배포할 때 설치 파일과 이 기록을 함께 보관하고, 같은 버전의 수정본에는 새 빌드 번호를 쓴다.
APK/AAB·기록 파일은 build 폴더에 남으며 Git에 커밋하지 않는다.

마이페이지의 버전 표시는 현재 `AppConfig.appVersion`의 고정값이므로 BuildName을 바꾸면
표시도 함께 맞춰야 한다. 실제 패키지 버전 자동 표시는 별도 후속 작업이다.

## 배포 승인 전

- [ ] 설치 파일의 환경·버전·서명과 카카오 키 해시 확인
- [ ] [부모 QA](PARENT_QA.md)와 [통합 QA](../docs/release-qa.md) 실행
- [ ] 지원 연락처·처리방침 확인, 미구현 기능을 출시 완료로 표시하지 않음
- [ ] 버그와 재검증 결과 기록, 출시 차단 오류 해소
- [ ] 팀의 배포 승인 후 테스트 트랙 또는 합의된 채널에 업로드

키가 다른 debug 앱 위에 release APK가 설치되지 않을 수 있다. 기존 앱 삭제 전 테스트
기록 보존/복구 가능 여부를 확인한다. 자동으로 앱 데이터를 삭제하지 않는다.
