# 개인정보 처리방침 출시 확인

확인일: 2026-11-27. 앱 본문은
`frontend/lib/features/account/domain/legal_documents.dart`에서 관리한다.
이 문서는 확인 근거와 미확정 운영 사실을 기록하며, 공개 처리방침을 대신하지 않는다.
PR #104는 아래 항목을 마칠 때까지 출시 승인용 최종본이 아니다.

## 반영한 사실

- 운영 주체: 들려줘요 운영팀, 대표·개인정보 보호책임자: 제수지.
- 공개 문의 이메일: jesuji030502@naver.com (사용자 확인).
- Railway 지역은 사용자 확인에 따라 싱가포르로 기재. 운영 서버와 DB 모두 일치하는지 최종 대조 필요.
- R2 위치 표기는 APAC이며 국가 보장 설정이 아님. 특정 국가로 바꾸어 추정하지 않는다.
- STT는 `/audio/transcriptions`, 정리는 `/responses`에 `store=false`, TTS는 `/audio/speech`.
- DB 답변 내용 삭제와 R2·카카오 비동기 삭제를 구분. 삭제 전 이미 발급된 URL은 만료 또는 파일 삭제까지 유효할 수 있음.
- 아직 구현되지 않은 사진의 수집 예고를 개인정보 수집 목록에서 제거.

## 출시 전 담당자가 확인할 항목

- [ ] Railway **운영** 서버와 Postgres 각각의 지역·계약 법인명·개인정보 연락처 확인.
  공식 DPA의 Railway Corporation / privacy@railway.com을 계정 계약과 대조.
- [ ] Cloudflare에 해당 R2 버킷의 개인정보 보관·처리 국가와 재위탁 범위 확인.
  APAC만으로 한국·싱가포르라고 단정하거나 전 세계 국가 목록을 실제 전송 국가로 복사하지 않음.
- [ ] OpenAI에 해당 조직·프로젝트·사용 모델/API의 처리 국가와 적용 법인·연락처 확인.
  Data retention 화면의 API call logging과 ZDR 승인을 혼동하지 않음.
- [ ] OpenAI Data controls의 Sharing이 실제로 어떤 상태인지 확인.
  학습용 데이터 공유를 선택했다면 기본 비학습 조건을 그대로 안내하지 않음.
- [ ] 업체별 국가·수신자와 연락처·항목·목적·시기·방법·보유기간을 앱 국외 이전 안내에 완성.
  계약 이행에 필요한 위탁·보관에 해당하는지 제28조의8의 적용 근거 검토.
  단순 방침 동의가 별도 국외 이전 동의를 자동 대체한다고 판단하지 않음.
- [ ] 백업 확인: 제공된 화면은 해당 Postgres의 사용자 생성 백업이 없다는 증거임.
  운영 환경, 별도 pg_dump·수동 파일, 업체 내부 재해복구 사본까지 없다는 증거는 아님.
  실제 운영 백업 유무·기간·파기 방식과 복원 시 삭제 재반영 절차를 확인해 본문에 반영.
- [ ] 파일 삭제 완료 목표와 지연 대응 담당·확인 주기 결정 후 실제로 실행.
  현 구현에는 완료 기한 보장이 없으므로 근거 없이 최대 7일·24시간 완전 삭제를 약속하지 않음.
- [ ] 만 14세 미만 이용 허용 여부 결정. 허용한다면 법정대리인 동의·확인·권리 행사 절차 필요.
  가족 페어링이나 카카오 로그인만으로 법정대리인 동의를 받았다고 간주하지 않음.
- [ ] 시행일(현재 2026-12-01)과 스토어 개발자 표시·앱 이름·운영자 정보 일치 확인.
- [ ] 로그인 없이 열리는 공개 HTTPS 개인정보 처리방침 URL 마련.
  Google Play에는 앱 내부 본문만으로 충분하지 않으며 접근 가능한 웹 URL도 등록.
- [ ] Google Play용 웹 계정 삭제 요청 페이지 마련: 앱 이름·운영자 이메일·본인 확인 절차·삭제 범위 설명.
  이메일 주소만 콘솔 URL 칸에 입력하지 않음. 확인 절차에서 카카오 비밀번호·토큰 요구 금지.
- [ ] 원스토어 수집·이용 고지·동의 화면, Play 데이터 보안 설문과 실제 앱 권한·SDK·처리방침 일치 확인.

## 공식 근거

- [Google Play 사용자 데이터](https://support.google.com/googleplay/android-developer/answer/10144311?hl=ko): 개인정보 처리방침 공개 URL, 앱 내 접근, 처리 주체·보안·보관·삭제 및 앱 안팎의 계정 삭제 경로.
- [원스토어 상품 검증 가이드라인](https://onestore-dev.gitbook.io/dev/docs/review/one-store-review-guideline): 개인정보 고지·동의, 처리방침 공개와 권리 보장.
- [개인정보 보호법](https://www.law.go.kr/lsInfoP.do?ancYnChk=0&lsId=011357): 제28조의8(국외 이전), 제30조(처리방침), 아동 개인정보 관련 요건.
- [Railway DPA](https://railway.com/legal/dpa), [지역](https://docs.railway.com/deployments/regions), [백업](https://docs.railway.com/volumes/backups).
- [R2 저장 위치](https://developers.cloudflare.com/r2/reference/data-location/): Location Hint는 보장 아님. [Cloudflare DPA](https://www.cloudflare.com/cloudflare-customer-dpa/).
- [OpenAI API 데이터 관리](https://developers.openai.com/api/docs/guides/your-data): STT의 로그·처리 상태 보관 None, 정리·TTS의 기본 악용 방지 로그 보관 및 예외. store=false와 ZDR는 다름.
- [OpenAI 지역 제한](https://developers.openai.com/api/docs/guides/data-residency), [재수탁자 목록](https://openai.com/policies/sub-processor-list/): 목록 전체가 해당 프로젝트의 실제 처리 국가라는 의미는 아님.

공식 정책 확인과 코드 검증은 스토어 승인 또는 법적 적합성의 확정 판정을 대신하지 않는다.
