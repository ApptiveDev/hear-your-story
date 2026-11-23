# 글꼴

디자인(Figma `들려줘요 디자인 v2`)의 글자 스타일에 맞춰 넣은 글꼴이다.
토큰은 `lib/core/theme/app_tokens.dart`에서 쓴다.

| 글꼴 | 파일 | 쓰는 곳 | 출처 | 라이선스 |
|---|---|---|---|---|
| Pretendard 1.3.9 | `Pretendard-Regular.otf`, `-Medium.otf`, `-SemiBold.otf`, `-Bold.otf` | 앱의 모든 글 | [orioncactus/pretendard](https://github.com/orioncactus/pretendard) (npm `pretendard@1.3.9`) | SIL OFL 1.1 (`OFL-Pretendard.txt`) |

- v2 디자인의 `Heading/L`(26 SemiBold)을 위해 `Pretendard-SemiBold.otf`(600)를 추가했다.
- 디자인에서 일부 글자 스타일에 지정된 `Noto Sans KR`, `AppleSDGothicNeo`는 디자인
  파일 안내대로 Pretendard로 통일했다. AppleSDGothicNeo는 안드로이드 앱에 넣을 수 없다.
- 1차 와이어프레임에서 쓰던 KoddiUD 온고딕은 v2에서 쓰지 않아 뺐다.

## 아이콘 글꼴

| 글꼴 | 파일 | 쓰는 곳 | 출처 | 라이선스 |
|---|---|---|---|---|
| Flaticon UIcons 3.3.1 (Solid/Regular Rounded) | `uicons-solid-rounded.ttf`, `uicons-regular-rounded.ttf` | `lib/core/theme/app_icons.dart` | npm `@flaticon/flaticon-uicons@3.3.1`의 woff2를 ttf로 바꾼 것 | Flaticon License. 무료로 쓰려면 앱 안에 "Uicons by Flaticon" 출처 표기가 필요하다 |

| AppIcons | `app-icons.ttf` | `lib/core/theme/app_icons.dart` | Figma `icon/*` 부품과 완료 체크의 벡터를 글꼴로 옮긴 것 | 디자인 파일의 벡터. 마이크·화살표는 Flaticon 계열일 수 있어 아래 출처 표기를 유지한다 |

- `app-icons.ttf`: U+E900부터 home, books, calendar, user, microphone, arrowLeft, arrowRight, check.
  틀(28·30·56) 전체를 1em으로 맞춰 `Icon`의 size가 Figma 틀 크기와 같다.
- Figma 디자인(`fi-sr-*`, `fi-rr-*`)이 이 아이콘을 쓴다.
- 출처 표기는 마이페이지 `아이콘 출처` 항목에 있다. 지우지 않는다.
- `const IconData`로만 쓰면 출시 빌드에서 쓰지 않는 글자는 자동으로 빠진다.
