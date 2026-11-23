import 'package:flutter/material.dart';

/// Figma `들려줘요 디자인 v2`의 디자인 토큰.
///
/// 값은 `01 Foundations` 페이지의 변수(Variables)와 `02 Components`의 부품에서
/// 가져왔다. 프레임이 393×852라 Figma 1px = Flutter 1 논리 픽셀로 옮긴다.
/// 상수 이름은 Figma 변수 이름을 camelCase로 바꾼 것이다
/// (예: `text/strong` → `AppColors.textStrong`).
abstract final class AppColors {
  // 배경·면
  static const bgApp = Color(0xFFFFFDF8); // bg/app: 화면 배경
  static const bgUnder = Color(0xFFF9F7F2); // bg/under: 비활성 테두리 버튼 배경
  static const surfaceCard = Color(0xFFFCF2DC); // surface/card: 카드
  static const surfaceWhite = Color(0xFFFFFFFF); // surface/white: 입력칸·테두리 버튼

  // 글자
  static const textStrong = Color(0xFF3B2A1F); // text/strong: 제목·본문 강조
  static const textBody = Color(0xFF5B4636); // text/body: 본문
  static const textSub = Color(0xFF7A6451); // text/sub: 보조 설명·안내
  static const textBrand = Color(0xFF935B2D); // text/brand: 라벨·테두리 버튼 글자
  static const textOnPrimary = Color(0xFFFFFFFF); // text/on-primary: 주 버튼 위 글자
  static const textDisabled = Color(0xFF6B5644); // text/disabled: 비활성 버튼 글자

  // 버튼·선
  static const actionPrimary = Color(0xFFCD7938); // action/primary: 주 버튼
  static const actionPrimaryLight = Color(0xFFEAA05A); // action/primary-light
  static const actionPrimaryDark = Color(0xFF935B2D); // action/primary-dark
  static const borderSoft = Color(0xFFEDE4CB); // border/soft: 입력칸 테두리
  static const borderPrimary = Color(0xFFCD7938); // border/primary: 테두리 버튼
  static const borderDisabled = Color(0xFFB5AD9D); // border/disabled

  /// 오류 테두리·안내 (`Field/Text` State=Error). Figma 변수로는 아직 없다.
  static const error = Color(0xFFB83A26);

  /// 질문 책장 `Card/Stack` 가운데 카드. Figma 변수로는 아직 없다.
  static const cardStack = Color(0xFFF7DDB0);

  /// 공책 종이 `Margin line`. Figma 변수로는 아직 없다.
  static const noteMargin = Color(0xFFCD8F66);

  /// 카카오 로그인 버튼 (`kakao/bg`, `kakao/text`). 카카오 디자인 가이드 색이다.
  static const kakaoBg = Color(0xFFFEE500);
  static const kakaoText = Color(0xD9000000); // 검정 85%
}

abstract final class AppFonts {
  /// 앱의 모든 글. Figma의 `Noto Sans KR`, `AppleSDGothicNeo`는 디자인 파일의
  /// 안내대로 Pretendard로 바꿔 쓴다(AppleSDGothicNeo는 안드로이드에 넣을 수 없다).
  static const pretendard = 'Pretendard';
}

/// Figma 글자 스타일. Figma의 자간(%)은 글자 크기에 곱해 px로 옮겼다.
///
/// 글자색은 가장 많이 쓰는 색을 기본으로 넣었다. 버튼 글자는 테마가 색을 정하므로
/// 색을 넣지 않는다.
abstract final class AppText {
  /// Heading/XXL 40 Bold: 로그인 화면 앱 이름
  static const headingXXL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.5,
    color: AppColors.textBrand,
  );

  /// Heading/XL 30 Bold: 홈 인사
  static const headingXL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.textStrong,
  );

  /// Heading/L 26 SemiBold: 화면 제목, 오늘의 질문
  static const headingL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.26,
    color: AppColors.textStrong,
  );

  /// Heading/M 22 Bold: 묶음 제목 (예: 10월 기록)
  static const headingM = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: -0.22,
    color: AppColors.textStrong,
  );

  /// Body/L 20: 제목 아래 설명, 입력칸 글자
  static const bodyL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.1,
    color: AppColors.textBody,
  );

  /// Body/M 18: 짧은 안내
  static const bodyM = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.09,
    color: AppColors.textBody,
  );

  /// Body/S 16: 보조 안내
  static const bodyS = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSub,
  );

  /// Label/L 20: `#오늘의 질문`, 날짜
  static const labelL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.1,
    color: AppColors.textBrand,
  );

  /// Label/M 16 Bold: 탭 이름, 입력칸 이름
  static const labelM = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textStrong,
  );

  /// Caption 14: 시각, 글자 수
  static const caption = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSub,
  );

  /// Button/L 26 Bold: 큰 버튼
  static const buttonL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.13,
  );

  /// Button/M 18 Bold: 작은 버튼
  static const buttonM = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.09,
  );

  /// Number/XL 40 Bold: 초대 숫자, 녹음 시간, 업로드 %
  static const numberXL = TextStyle(
    fontFamily: AppFonts.pretendard,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.textStrong,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

abstract final class AppRadius {
  static const buttonL = 24.0; // Button Size=L
  static const buttonM = 20.0; // Button Size=M
  static const card = 32.0; // Card/Question 등 카드
  static const cardSmall = 24.0; // Card/Role, Chip/Role 같은 작은 카드
  static const codeCell = 16.0; // Input/Code 숫자 칸
  static const note = 12.0; // Note/Paper 쪽지
  static const field = 24.0; // Field/Text 입력칸, 초대 숫자 칸
  static const pill = 999.0; // 진행 막대처럼 양끝이 둥근 모양
}

abstract final class AppSizes {
  static const buttonL = 70.0; // Button Primary L
  static const buttonLOutlined = 74.0; // Button Outline L (테두리 2px 포함)
  static const buttonM = 47.0; // Button Primary M
  static const field = 72.0; // Field/Text 입력칸 높이
  static const iconL = 30.0; // 큰 버튼 아이콘, 마이크
  static const iconM = 24.0; // 작은 버튼 아이콘
  static const screenPadding = 24.0; // 393 프레임에서 좌우 여백
}

/// Figma 효과(Effect) 중 바깥 그림자.
///
/// v2 그림자는 흐림 없이 겹쳐 쌓은 입체감이 많다. Flutter는 목록 뒤쪽 그림자를
/// 위에 그리므로 Figma(CSS) 순서를 뒤집어 넣었다.
abstract final class AppShadows {
  /// Card/pop up: 카드 아래 종이가 겹친 듯한 단
  static const card = [
    BoxShadow(offset: Offset(0, 2), color: Color(0xB2FFFFFF)),
    BoxShadow(offset: Offset(0, 5), color: Color(0xFFE0CEB5)),
    BoxShadow(offset: Offset(0, 12), color: Color(0x24835E44)),
  ];

  /// Button: 주 버튼 기본 상태의 바깥 그림자
  static const button = [
    BoxShadow(offset: Offset(0, 4), color: Color(0x80B05F20)),
    BoxShadow(offset: Offset(0, 4), blurRadius: 19, color: Color(0x404B4743)),
  ];

  /// Button/Pressed: 눌렀을 때 바깥 그림자
  static const buttonPressed = [
    BoxShadow(offset: Offset(0, 1), color: Color(0x80B05F20)),
  ];

  /// Card/Stack: 겹친 카드가 아래 카드 위로 드리우는 그림자
  static const stack = [
    BoxShadow(offset: Offset(0, -4), blurRadius: 6, color: Color(0x2E593814)),
  ];

  /// Tab/Bar: 아래 탭 막대
  static const tabBar = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 16, color: Color(0x1F3A1E0A)),
    BoxShadow(offset: Offset(0, -2), blurRadius: 14, color: Color(0x1F3A1E0A)),
  ];
}

/// Figma 효과 중 안쪽 그림자(Inner shadow).
///
/// Flutter `BoxShadow`는 안쪽 그림자를 그리지 못한다. 값만 모아 두고, 버튼 위젯을
/// 만들 때 그라데이션이나 `CustomPainter`로 직접 그린다.
abstract final class AppInnerShadows {
  /// Button: 위쪽 밝은 빛 + 아래쪽 어두운 테두리
  static const button = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 5, color: Color(0x80EDB58A)),
    BoxShadow(offset: Offset(0, -4), blurRadius: 2, color: Color(0x47744017)),
  ];

  /// Button/Pressed
  static const buttonPressed = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 5, color: Color(0x80EDB58A)),
    BoxShadow(offset: Offset(0, -2), blurRadius: 2, color: Color(0x47744017)),
  ];
}
